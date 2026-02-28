# FlowKit Development Guide

FlowKit is a Godot 4 editor plugin for visual event-driven programming, inspired by Clickteam Fusion/Construct event sheets.

## Architecture Overview

**Plugin Structure**: FlowKit is a dual-mode system with editor-time visual authoring and runtime execution:

- **Editor side** (`flowkit.gd`, `ui/`): Godot `@tool` plugin that adds a bottom panel for visual event editing
- **Runtime side** (`runtime/flowkit_engine.gd`, `runtime/flowkit_system.gd`): Autoloaded singletons that execute event sheets during gameplay
- **Registry system** (`registry.gd`): Auto-discovers and instantiates provider scripts at plugin load
- **Branch system** (`branches/`): Extensible branch providers (if, repeat, etc.) that control action execution flow
- **Generator system** (`generator.gd`): Automatically generates actions, conditions, and events from scene node types and their properties/methods/signals

**Event Sheet Model**: Scene-specific `.tres` resources saved to `saved/event_sheet/{scene_name}.tres`:

```
FKEventSheet
  └─ events: Array[FKEventBlock]
      ├─ event_id: String (e.g., "on_process")
      ├─ target_node: NodePath (node to poll event from)
      ├─ conditions: Array[FKEventCondition] (all must pass)
      └─ actions: Array[FKEventAction] (executed sequentially)
```

**Provider Pattern**: All events/conditions/actions/branches extend base classes (`FKEvent`, `FKCondition`, `FKAction`, `FKBranch`) implementing:

- `get_id()`: Unique identifier string
- `get_name()`: Display name for UI
- `get_supported_types()`: Array of compatible node class names (e.g., `["CharacterBody2D"]`) — not used by branches
- `get_inputs()`: Array of `{"name": String, "type": String}` dictionaries for parameters
- Execution method: `poll(node)`, `check(node, inputs)`, `execute(node, inputs)`, or `should_execute()`/`get_execution_count()`

**Branch Provider Pattern** (`FKBranch` base class in `resources/fk_branch.gd`):

Branches control conditional/repeated execution of actions within an event block. They are extensible providers stored in `branches/`. Each branch implements:

- `get_id()` → `String`: Unique identifier (e.g., `"if_branch"`, `"repeat"`)
- `get_name()` → `String`: Display name (e.g., `"If"`, `"Repeat"`)
- `get_description()` → `String`: Tooltip description
- `get_input_type()` → `String`: Either `"condition"` (uses FKCondition providers) or `"evaluation"` (uses expression inputs directly)
- `get_inputs()` → `Array[Dictionary]`: Input definitions for evaluation-type branches (e.g., `[{"name": "times", "type": "int"}]`)
- `get_type()` → `String`: Either `"single"` (standalone, no chaining) or `"chain"` (allows else-if/else blocks after it)
- `get_color()` → `Color`: Accent color for the branch in the editor UI (type label, icon). Override to customise per-provider.
- `should_execute(condition_result: bool, inputs: Dictionary, block_id: String)` → `bool`: For condition-type branches, decides execution based on condition result
- `get_execution_count(inputs: Dictionary, block_id: String)` → `int`: For evaluation-type branches, returns how many times to execute (0 = skip)

Branch data is stored on `FKEventAction` resources via `branch_id: String` and `branch_inputs: Dictionary`. Legacy `branch_type` values ("if"/"elseif"/"else") are resolved to `"if_branch"` via `registry.resolve_branch_id()` for backward compatibility.

## Critical Workflows

**Creating New Providers**:

1. Add `.gd` file to `actions/{NodeType}/`, `conditions/{NodeType}/`, `events/{NodeType}/`, or `branches/`
2. Extend `FKAction`, `FKCondition`, `FKEvent`, or `FKBranch`
3. Implement required methods (see base classes in `resources/` directory)
4. Registry auto-discovers on plugin reload (no manual registration needed)
5. **Alternative**: Use `generator.gd` to auto-generate providers from scene nodes - it introspects node properties, methods, and signals to create boilerplate providers

**Creating New Branch Providers**:

1. Add `.gd` file to `branches/` directory
2. Extend `FKBranch` (from `resources/fk_branch.gd`)
3. Implement required methods:
   - `get_id()`, `get_name()`, `get_description()`
   - `get_input_type()`: Return `"condition"` to use FKCondition providers, or `"evaluation"` to use direct expression inputs
   - For condition-type: Implement `should_execute(condition_result, inputs, block_id)`
   - For evaluation-type: Implement `get_inputs()` and `get_execution_count(inputs, block_id)`
   - `get_type()`: Return `"chain"` to allow else-if/else chaining, or `"single"` for standalone
   - `get_color()`: Return a `Color` for the branch accent in the editor UI
4. Registry auto-discovers on plugin reload
5. Built-in examples: `branches/if_branch.gd` (condition-type, chainable), `branches/repeat.gd` (evaluation-type, not chainable)

**Event Sheet Execution** (runtime):

- FlowKit engine detects scene changes via `get_tree().current_scene`
- Loads matching `.tres` from `saved/event_sheet/{scene_name}.tres`
- Each `_process()` frame:
  1. Polls event triggers (`registry.poll_event()`)
  2. Evaluates conditions (`registry.check_condition()`)
  3. Executes actions if all conditions pass (`registry.execute_action()`)
  4. Branch execution uses provider-based logic:
     - Resolves `branch_id` via `registry.resolve_branch_id()` (handles legacy data)
     - Condition-type branches: Evaluates attached FKCondition, passes result to `provider.should_execute()`
     - Evaluation-type branches: Evaluates `branch_inputs` expressions, calls `provider.get_execution_count()` to determine repetitions
     - Chainable branches (if/elseif/else) track a `branch_hit` flag to implement exclusive execution

**Editor UI Flow** (adding actions):

1. User clicks "Add Action" → `select_node_modal` shows scene tree
2. Select target node → `select_action_modal` filters actions by `get_supported_types()`
3. Select action → `expression_modal` for input parameters (if needed)
4. Save to `.tres` → UI refreshes with new action node

**Modal Dialog Chain** (detailed workflow):

```
Add Action Flow:
  _on_row_add_action()
  ↓ (stores pending_target_row, pending_block_type = "action")
  _start_add_workflow()
  ↓
  select_node_modal.popup_centered()
  ↓ emits node_selected(node_path, node_class)
  _on_node_selected()
  ↓ (stores pending_node_path)
  select_action_modal.popup_centered()
  ↓ emits action_selected(node_path, action_id, inputs)
  _on_action_selected()
  ↓ (if inputs.size() > 0)
  expression_modal.popup_centered()
  ↓ emits expressions_confirmed(node_path, action_id, expressions)
  _on_expressions_confirmed()
  ↓ calls _finalize_action_creation() or _update_action_inputs()

Add Condition Flow:
  _on_row_add_condition()
  ↓ (stores pending_target_row, pending_block_type = "condition")
  _start_add_workflow()
  ↓ follows same signal chain pattern
  _finalize_condition_creation() or _update_condition_inputs()
```

Each modal step stores context in `pending_*` variables (e.g., `pending_node_path`, `pending_target_row`, `pending_branch_id`) to maintain state across the workflow. Editing workflows reuse the same modals but set `pending_block_type` to `action_edit` / `condition_edit` flags.

```
Add Branch Flow (condition-type, e.g., If):
  _on_row_add_branch(signal_row, branch_id, bound_row)
  ↓ (stores pending_branch_id, pending_block_type = "branch")
  _start_add_workflow()
  ↓ follows same node → condition → expression chain
  _finalize_branch_creation()

Add Branch Flow (evaluation-type, e.g., Repeat):
  _on_row_add_branch(signal_row, branch_id, bound_row)
  ↓ (stores pending_branch_id, pending_block_type = "branch_evaluation")
  _start_branch_workflow()
  ↓ opens expression_modal directly (no node selection)
  _finalize_branch_evaluation_creation()
```

## Project Conventions

**Resource Naming**: Event sheets MUST match scene filename: `world.tscn` → `world.tres`

**Node Path Resolution**: All `target_node` paths are relative to scene root (`get_tree().current_scene`). Use `get_node_or_null()` to handle missing references.

**Typed Arrays**: Use strict typing for resource arrays:

```gdscript
@export var events: Array[FKEventBlock] = []  # Not Array
```

**Provider Discovery**: Registry uses recursive directory scanning. Organize providers by node type (e.g., `actions/CharacterBody2D/`) for clarity, but structure doesn't affect registration. Branch providers go in `branches/` directory (flat, no subdirectories needed).

**Editor Interface Pattern**: Custom modals receive `EditorInterface` via `set_editor_interface()` to access scene tree and node icons. See `ui/modals/select_action_modal.gd`.

**State Management**: Editor UI uses pending variables (e.g., `pending_node_path`) to track multi-step workflows across modal dialogs.

## Code Style and Naming Conventions

**Variable Naming**:

- **Snake case** for all variables: `event_index`, `action_providers`, `selected_node_path`
- **Resource members** prefixed by purpose: `pending_action_*` (workflow state), `selected_*` (current selection)
- **Node references** suffixed with type: `label`, `context_menu`, `item_list` (not `labelNode`)

**Function Naming**:

- **Private helpers**: Prefix with `_` (e.g., `_load_folder`, `_scan_directory_recursive`, `_update_label`)
- **Signal handlers**: Use pattern `_on_{emitter}_{signal_name}` (e.g., `_on_context_menu_id_pressed`)
- **Public API methods**: No prefix (e.g., `set_action_data`, `populate_inputs`)
- **Provider interface**: Use `get_*` pattern (e.g., `get_id()`, `get_name()`, `get_supported_types()`)

**Signal Naming**:

- Use past tense for events: `node_selected`, `action_selected`, `expressions_confirmed`
- Use `_requested` suffix for UI actions: `insert_action_requested`, `delete_condition_requested`

**Type Hints**:

- Always specify return types: `func get_id() -> String:`
- Use typed variables where possible: `var dir: DirAccess = DirAccess.open(path)`
- Prefer Godot class names over `Variant`: `var instance: Variant` (when dynamic), `var node: Node` (when known)

**Scene Tree Access**:

- Use `get_node_or_null()` for optional nodes: `var label = get_node_or_null("Panel/MarginContainer/HBoxContainer/Label")`
- Defer node access in `_ready()` when needed: `call_deferred("_setup_context_menu")`
- Use `@onready` for guaranteed child nodes: `@onready var menubar := $ScrollContainer/MarginContainer/VBoxContainer/MenuBar`

## Key Integration Points

**Runtime Autoloads**: Two singletons added in `_enter_tree()`:

```gdscript
add_autoload_singleton("FlowKitSystem", "res://addons/flowkit/runtime/flowkit_system.gd")
add_autoload_singleton("FlowKit", "res://addons/flowkit/runtime/flowkit_engine.gd")
```

- `FlowKitSystem`: System-level utilities and global state management
- `FlowKit`: Main execution engine for event sheet processing

**Scene Detection**: Engine uses deferred `_check_current_scene()` + `_process()` polling to handle scene changes robustly (works even if scene loads before engine ready).

**UI-Resource Sync**: Editor saves via `ResourceSaver.save()`, then calls `_display_sheet()` to rebuild UI from saved resource (single source of truth).

## Common Pitfalls

- **Forgetting `@tool`**: Editor scripts must have `@tool` directive
- **Node path timing**: Use `get_node_or_null()` since nodes may not exist if sheets reference deleted objects
- **Array assignment**: Godot requires creating NEW typed arrays when modifying resources (can't append to existing)
- **Modal workflow**: Multi-step dialogs need pending state variables to pass data between steps

## File References

- Provider examples: `actions/Node/print_message.gd`, `events/Node/on_process.gd`
- Branch examples: `branches/if_branch.gd` (condition-type), `branches/repeat.gd` (evaluation-type)
- Branch base class: `resources/fk_branch.gd`
- Resource schemas: `resources/event_sheet.gd`, `resources/event_block.gd`, `resources/event_action.gd` (includes `branch_id`, `branch_inputs`)
- Editor workflow: `ui/main_editor.gd` (\_on_row_add_action → \_start_add_workflow, \_on_row_add_branch → \_start_branch_workflow)
- Runtime loop: `runtime/flowkit_engine.gd` (\_run_sheet, \_check_branch_should_execute)
- Generator system: `generator.gd` (auto-generates providers from node introspection)
- Expression evaluator: `runtime/expression_evaluator.gd` (evaluates GDScript expressions in action/condition inputs)
- Signal forwarding chain: `branch_item_ui.gd` → `event_row_ui.gd` → `group_ui.gd` → `main_editor.gd`
