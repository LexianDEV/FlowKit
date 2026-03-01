## The type of Node being dragged. We can't pass actual Node types directly like
## we can in C#, so this enum will have to do.
class_name DragTargetType

const none = 0
const action_item = 1
const action = 1.5
const branch_item = 2
const condition = 3
const event_item = 4
const group = 5
