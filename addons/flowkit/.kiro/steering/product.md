# FlowKit - Product Overview

FlowKit is a Godot 4 editor plugin that provides visual event-based programming similar to Clickteam Fusion and Construct 3.

## Purpose

Enable game developers to create game logic using a visual event sheet system without writing GDScript code directly. Events, conditions, and actions are configured through a GUI and executed at runtime.

## Core Concepts

- **Event Sheets**: Per-scene configuration files (`.tres`) containing event blocks
- **Events**: Triggers that start logic execution (e.g., `on_process`, `on_ready`, `on_key_pressed`)
- **Conditions**: Boolean checks that gate action execution (e.g., `compare_variable`)
- **Actions**: Operations performed when events trigger and conditions pass (e.g., `move_and_slide`, `set_velocity_x`)
- **Behaviors**: Reusable logic bundles attached to nodes (e.g., `top_down_movement`)

## Target Users

Game developers who prefer visual scripting over code, or want rapid prototyping capabilities in Godot.
