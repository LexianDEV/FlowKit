extends Resource
class_name FKEventSheet

@export var events: Array[FKEventBlock] = []
@export var standalone_conditions: Array[FKEventCondition] = []
@export var comments: Array[FKCommentBlock] = []
@export var groups: Array[FKGroupBlock] = []
# Stores the order of items: {"type": "event"|"comment"|"group", "index": int}
@export var item_order: Array[Dictionary] = []
