##
## In charge of saving and loading Event Sheets to/from disk.
##

extends RefCounted
class_name FKSheetIO

const SHEET_DIR := "res://addons/flowkit/saved/event_sheet"

func get_sheet_path(scene_uid: int) -> String:
	if scene_uid == 0:
		return ""
	return "%s/%d.tres" % [SHEET_DIR, scene_uid]

func load_sheet(scene_uid: int) -> FKEventSheet:
	var sheet_path := get_sheet_path(scene_uid)
	if sheet_path == "" or not FileAccess.file_exists(sheet_path):
		return null

	var sheet := ResourceLoader.load(sheet_path)
	if sheet is FKEventSheet:
		return sheet
	return null

func save_sheet(scene_uid: int, sheet: FKEventSheet) -> int:
	var sheet_path := get_sheet_path(scene_uid)
	if sheet_path == "":
		print("[SheetIo] Returning err invalid param")
		return ERR_INVALID_PARAMETER

	DirAccess.make_dir_recursive_absolute(SHEET_DIR)
	return ResourceSaver.save(sheet, sheet_path)

func new_sheet() -> FKEventSheet:
	return FKEventSheet.new()

# -------------------------------------------------------------------
#  EVENT COPY (supports both old dict format and new FKUnit format)
# -------------------------------------------------------------------

func copy_event_block(data: FKEventBlock) -> FKEventBlock:
	if data == null:
		return null

	return data.duplicate_block()

# -------------------------------------------------------------------
#  ACTION COPY (supports nested branches)
# -------------------------------------------------------------------

func copy_action(act: FKActionUnit) -> FKActionUnit:
	if act == null:
		return null
	
	return act.duplicate_block()

# -------------------------------------------------------------------
#  GROUP COPY (supports both dict children and FKUnit children)
# -------------------------------------------------------------------

func copy_group_block(data: FKGroup) -> FKGroup:
	if data == null:
		return null

	var result := data.duplicate_block()
	return result
