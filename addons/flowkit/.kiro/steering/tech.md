# FlowKit - Technical Stack

## Engine & Language

- **Engine**: Godot 4.x
- **Language**: GDScript
- **Plugin Type**: EditorPlugin with runtime autoloads

## Architecture

- `@tool` scripts for editor functionality
- Runtime autoloads: `FlowKitSystem` (global state) and `FlowKit` (engine)
- Resource-based data model using `.tres` files
- Provider pattern for extensible events, conditions, actions, and behaviors

## Key Dependencies

- Godot's `EditorPlugin` API
- `Expression` class for runtime expression evaluation
- `Resource` and `ResourceLoader` for data persistence

## File Conventions

- Provider scripts extend base classes: `FKEvent`, `FKCondition`, `FKAction`, `FKBehavior`
- Event sheets saved to `saved/event_sheet/<scene_name>.tres`
- Generated providers prefixed with `gen_`

## Commands

No external build system. The plugin runs directly in Godot Editor.

- **Enable Plugin**: Project Settings → Plugins → Enable "FlowKit"
- **Generate Providers**: Use the "Generate" button in FlowKit editor to auto-create providers from scene node types
- **Reload Registry**: Restart Godot Editor after adding new providers
