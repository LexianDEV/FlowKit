## The type of Node being dragged. We can't pass actual Node types directly like
## we can in C#, so this enum will have to do.
class_name DragTargetType

const none = 0
const action_item = 1
const action = 2
const comment = 3
const condition = 4
const condition_item = 5
const event_item = 6
const group = 7
