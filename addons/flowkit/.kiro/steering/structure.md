# FlowKit - Project Structure

```
addons/flowkit/
├── flowkit.gd              # Main EditorPlugin entry point
├── registry.gd             # Provider registry (loads and manages all providers)
├── generator.gd            # Auto-generates providers from scene node types
├── plugin.cfg              # Plugin metadata
│
├── actions/                # Action providers (organized by node type)
│   ├── CharacterBody2D/    # Actions for CharacterBody2D nodes
│   ├── Node/               # Generic node actions
│   └── System/             # Global system actions
│
├── conditions/             # Condition providers (same structure as actions)
│   ├── CharacterBody2D/
│   ├── Node/
│   └── System/
│
├── events/                 # Event providers
│   ├── Node/               # Node lifecycle events
│   └── System/             # Input and system events
│
├── behaviors/              # Behavior providers (reusable logic bundles)
│   └── CharacterBody2D/
│
├── resources/              # Resource class definitions
│   ├── fk_action.gd        # Base class for actions
│   ├── fk_condition.gd     # Base class for conditions
│   ├── fk_event.gd         # Base class for events
│   ├── fk_behavior.gd      # Base class for behaviors
│   ├── event_sheet.gd      # Event sheet container
│   ├── event_block.gd      # Single event with conditions/actions
│   ├── event_action.gd     # Action instance data
│   └── event_condition.gd  # Condition instance data
│
├── runtime/                # Runtime execution
│   ├── flowkit_engine.gd   # Main runtime loop (autoload)
│   ├── flowkit_system.gd   # Global state/variables (autoload)
│   └── expression_evaluator.gd  # Runtime expression parsing
│
├── ui/                     # Editor UI
│   ├── editor.gd/.tscn     # Main editor panel
│   ├── workspace/          # Event row and item components
│   ├── modals/             # Selection dialogs
│   └── inspector/          # Custom inspector integration
│
├── saved/                  # Persisted data
│   └── event_sheet/        # Per-scene event sheets (.tres)
│
├── demos/                  # Example scenes
└── assets/                 # Plugin icons
```

## Provider Organization

Providers are organized by the node type they support:
- `actions/CharacterBody2D/` → actions for CharacterBody2D nodes
- `conditions/System/` → conditions for the global System object
- `events/Node/` → events applicable to any Node

## Naming Conventions

- Provider IDs: lowercase with underscores (e.g., `move_and_slide`, `on_process`)
- Generated files: prefixed with `gen_` (e.g., `gen_set_position.gd`)
- Resource classes: prefixed with `FK` (e.g., `FKAction`, `FKEventSheet`)
