# Subsheets Implementation Summary

## Overview
This implementation adds support for local "Subsheets" to FlowKit - reusable visual-scripting functions within an Event Sheet. This allows users to group logic and reuse it in multiple places without code duplication.

## Changes Made

### 1. Core Resource Classes

#### FKSubsheet Resource (`addons/flowkit/resources/fk_subsheet.gd`)
- New resource class representing a reusable subsheet
- Properties:
  - `subsheet_id`: Unique identifier (auto-generated)
  - `name`: Display name for the subsheet
  - `actions`: Array of FKEventAction that execute when called
- Methods for ID generation and validation

#### FKEventSheet Updates (`addons/flowkit/resources/event_sheet.gd`)
- Added `subsheets: Array[FKSubsheet]` property
- Added helper methods:
  - `add_subsheet()`: Add a new subsheet
  - `remove_subsheet()`: Remove by ID
  - `get_subsheet()`: Get by ID
  - `get_subsheet_by_name()`: Get by name

### 2. Runtime Execution

#### Call Subsheet Action (`addons/flowkit/actions/System/call_subsheet.gd`)
- New action provider for calling subsheets
- Supports "System" node type
- Input: `subsheet_id` (String)
- Properly handles multi-frame execution with exec_completed signal

#### Engine Integration (`addons/flowkit/runtime/flowkit_engine.gd`)
- Added `execute_subsheet()` method
- Finds the subsheet in active sheets
- Executes subsheet actions in sequence
- Actions run in the same context as calling event (scene root)

### 3. Editor UI

#### Manage Subsheets Button
- Added 🔧 button to editor top bar (`addons/flowkit/ui/editor.tscn`)
- Positioned alongside "Add Comment" and "Add Group" buttons

#### Subsheet Manager Modal (`addons/flowkit/ui/modals/subsheet_manager.*`)
- Lists all subsheets in the current event sheet
- Features:
  - Add new subsheet with custom name
  - Rename existing subsheets
  - Delete subsheets (with confirmation)
  - Edit subsheet actions (opens Subsheet Editor)

#### Subsheet Editor Modal (`addons/flowkit/ui/modals/subsheet_editor.*`)
- Full action management interface for subsheets
- Features:
  - Add actions (same workflow as event actions)
  - Edit action inputs
  - Delete actions
  - Reorder actions (move up/down)
- Uses existing modals (select node, select action, expression editor)

#### Editor Integration (`addons/flowkit/ui/editor.gd`)
- Connected modal signals
- Added handler functions:
  - `_on_manage_subsheets_pressed()`
  - `_on_subsheet_added()`
  - `_on_subsheet_edited()`
  - `_on_subsheet_deleted()`
  - `_on_edit_subsheet_actions()`
  - `_on_subsheet_actions_updated()`
- Updated `_generate_sheet_from_blocks()` to preserve subsheets when saving

### 4. Documentation

#### User Guide (`SUBSHEETS_GUIDE.md`)
- Complete guide for creating and using subsheets
- Example use cases
- Step-by-step instructions

## Key Design Decisions

1. **Local, not Global**: Subsheets are part of the event sheet, not separate assets
   - Simplifies management
   - Keeps related logic together
   - Follows the "local function" mental model

2. **ID-based References**: Subsheets use auto-generated IDs
   - Ensures uniqueness
   - Allows safe renaming
   - Future: Could add dropdown selector

3. **Reuse Existing UI**: Subsheet editor uses existing modals
   - Consistent user experience
   - Minimal new code
   - Leverages tested components

4. **Preservation on Save**: Subsheets persist when saving event sheets
   - Loads existing sheet before building from blocks
   - Preserves subsheets array
   - No data loss during normal editing

## Testing Recommendations

### Manual Testing Checklist
1. Create a new subsheet in the editor
2. Add actions to the subsheet
3. Call the subsheet from an event
4. Verify actions execute in correct order
5. Rename a subsheet
6. Delete a subsheet
7. Save and reload the event sheet
8. Verify subsheets persist across sessions

### Edge Cases
- Creating subsheet with empty name (should default to "New Subsheet")
- Calling non-existent subsheet (should log error)
- Subsheet with multi-frame actions (should properly await)
- Empty subsheet (no actions) - should complete immediately

## Future Enhancements

1. **Parameters**: Add input parameters to subsheets
2. **Subsheet Selector**: Dropdown to select subsheet by name instead of typing ID
3. **Visual Feedback**: Show which events call which subsheets
4. **Copy/Paste**: Allow duplicating subsheets
5. **Export/Import**: Share subsheets between event sheets

## Compatibility

- **Backward Compatible**: Existing event sheets continue to work
- **Forward Compatible**: New subsheets field defaults to empty array
- **Resource Version**: No version migration needed

## Files Changed

### New Files
- `addons/flowkit/resources/fk_subsheet.gd`
- `addons/flowkit/actions/System/call_subsheet.gd`
- `addons/flowkit/ui/modals/subsheet_manager.gd`
- `addons/flowkit/ui/modals/subsheet_manager.tscn`
- `addons/flowkit/ui/modals/subsheet_editor.gd`
- `addons/flowkit/ui/modals/subsheet_editor.tscn`
- `SUBSHEETS_GUIDE.md`

### Modified Files
- `addons/flowkit/resources/event_sheet.gd`
- `addons/flowkit/runtime/flowkit_engine.gd`
- `addons/flowkit/ui/editor.gd`
- `addons/flowkit/ui/editor.tscn`

## Notes

- The provider manifest will need to be regenerated in the editor to include the new "Call Subsheet" action for exported builds
- Subsheets are saved as part of the event sheet `.tres` file
- The implementation follows FlowKit's existing patterns and conventions
