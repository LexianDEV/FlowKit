extends Resource
class_name FKGroupBlock

@export var title: String = "Group"
@export var collapsed: bool = false
@export var color: Color = Color(0.2, 0.4, 0.6, 1.0)
# Stores child items: {"type": "event"|"comment"|"group", "data": Resource}
@export var children: Array[Dictionary] = []
