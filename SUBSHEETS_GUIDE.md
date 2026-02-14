# Subsheets Feature - User Guide

## Overview
Subsheets are local, reusable visual-scripting functions within an Event Sheet. They allow you to group logic and reuse it in multiple places without code duplication.

## Creating a Subsheet

1. Open the FlowKit editor panel (bottom panel in Godot)
2. Make sure you have a scene loaded with an event sheet
3. Click the 🔧 "Manage Subsheets" button in the top bar
4. Click "Add Subsheet" in the modal
5. Enter a name for your subsheet (e.g., "Move Player", "Run Transition")
6. Click "Create"

## Editing Subsheet Actions

1. In the Manage Subsheets modal, find your subsheet
2. Click "Edit Actions" next to the subsheet name
3. Use "Add Action" to add actions to the subsheet (same workflow as adding actions to events)
4. Actions will execute sequentially when the subsheet is called
5. Click "Close" when done

## Calling a Subsheet

1. In any event, add an action
2. Select "System" as the target node
3. Select "Call Subsheet" as the action
4. Enter the subsheet ID in the input field (you can find this in the Manage Subsheets modal)
5. The subsheet's actions will execute when this action runs

## Managing Subsheets

In the Manage Subsheets modal, you can:
- **Edit Actions**: Open the subsheet editor to add/remove/reorder actions
- **Rename**: Change the subsheet's display name
- **Delete**: Remove the subsheet (careful: this cannot be undone!)

## Notes

- Subsheets are saved as part of the Event Sheet resource
- They are not global - each scene has its own subsheets
- Subsheet actions run in the same context as the calling event
- Actions in subsheets can target any node in the scene

## Example Use Cases

1. **Player Movement**: Create a subsheet with movement logic, call it from multiple events
2. **Transition Sequences**: Group fade in/out actions into a subsheet
3. **Combat Routines**: Reuse attack sequences across different enemy events
4. **UI Updates**: Update multiple UI elements with a single subsheet call
