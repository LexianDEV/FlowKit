<center>
   <img src="https://github.com/user-attachments/assets/54975590-91e2-4f1d-826f-390ebf20c729" alt="default-monochrome-2" width="100%">
</center>

---

## 💬 Join the Community

**Discord Server:**  
Come hang out, ask questions, get help, and share your FlowKit creations!

👉 https://discord.gg/flowkit

---

A **Clickteam Fusion 2.5/Construct** inspired visual scripting addon for **Godot 4**, enabling event-driven programming through an intuitive event sheet interface.

![Godot Version](https://img.shields.io/badge/Godot-4.5-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## 📋 Overview

FlowKit brings the power of visual event-based programming to Godot, allowing you to create game logic without writing code. Inspired by popular event sheet systems like Clickteam Fusion and Construct, FlowKit provides a familiar workflow for non-programmers and rapid prototyping enthusiasts.

### Key Features

- **🎯 Event Sheet System**: Create game logic using intuitive event blocks with conditions and actions
- **🔌 Node-Based Architecture**: Target specific nodes in your scene tree for granular control
- **📦 Extensible Provider System**: Easily add custom events, conditions, and actions
- **⚡ Runtime Engine**: Efficient event processing during gameplay with automatic scene detection
- **🎨 Editor Integration**: Seamless integration with Godot's editor interface
- **💾 Resource-Based Storage**: Event sheets saved as `.tres` resources for version control friendliness

## 🚀 Getting Started

### Installation

1. Download or clone this repository
2. Copy the `flowkit` folder into your Godot project's `addons/` directory
3. Enable the plugin in **Project → Project Settings → Plugins**
4. The FlowKit panel will appear at the bottom of the editor

### Creating Your First Event Sheet

1. Open a scene in the Godot editor
2. Click the **FlowKit** tab in the bottom panel
3. Click **"Create Event Sheet"** to initialize an event sheet for the current scene
4. Add an event block:
   - Click **"Add Event"** and select an event type (e.g., `On Process`)
   - Select the target node from your scene tree
5. Add conditions (optional):
   - Click **"Add Condition"** on the event block
   - Choose condition type and configure parameters
6. Add actions:
   - Click **"Add Action"** on the event block
   - Select target node and action type
   - Configure action parameters using expressions
7. Save your event sheet (**File → Save**)

Event sheets are automatically loaded and executed when their associated scene runs.

## 🏗️ Architecture

FlowKit operates as a dual-mode system:

### Editor Mode

- **Visual Authoring**: Bottom panel UI for creating and editing event sheets
- **Node Selection**: Integration with Godot's scene tree for target selection
- **Expression Editor**: Configure action/condition parameters with GDScript expressions

### Runtime Mode

- **FlowKit Engine**: Autoloaded singleton (`FlowKit`) that executes event sheets
- **Scene Detection**: Automatically loads event sheets matching the current scene
- **Event Loop**: Processes events, conditions, and actions every frame

### Event Sheet Structure

```

FKEventSheet (Resource)
└─ events: Array[FKEventBlock]
├─ event_id: String (e.g., "on_process")
├─ target_node: NodePath
├─ conditions: Array[FKEventCondition]
│   ├─ condition_id: String
│   ├─ target_node: NodePath
│   └─ inputs: Dictionary
└─ actions: Array[FKEventAction]
├─ action_id: String
├─ target_node: NodePath
└─ inputs: Dictionary

````

## 📦 Built-in Providers

### Events

- **On Ready**: Triggered once when the node enters the scene tree
- **On Process**: Triggered every frame
- **On Key Pressed**: Triggered when a keyboard key is pressed

### Conditions

- **Get Key Down**: Check if a specific key is currently pressed

### Actions

**Node Actions:**

- **Print**: Output text to the console

**CharacterBody2D Actions:**

- **Move and Collide**: Move with collision detection
- **Move and Slide**: Move with sliding collision response
- **Normalize Velocity**: Normalize the velocity vector
- **Set Position X/Y**: Set horizontal/vertical position
- **Set Rotation**: Set rotation angle
- **Set Velocity X/Y**: Set horizontal/vertical velocity

**Note**: More providers will be added in future updates, and this list is not exhaustive.

## 🔧 Creating Custom Providers

FlowKit's provider system makes it easy to extend functionality. Providers are automatically discovered through the registry system.

### Creating a Custom Action

```gdscript
extends FKAction

func get_id() -> String:
    return "my_custom_action"

func get_name() -> String:
    return "My Custom Action"

func get_supported_types() -> Array:
    return ["Node2D"]

func get_inputs() -> Array:
    return [
        {"name": "amount", "type": "float"},
        {"name": "message", "type": "String"}
    ]

func execute(node: Node, inputs: Dictionary) -> void:
    var amount = inputs.get("amount", 0.0)
    var message = inputs.get("message", "")
    print(message, " - ", amount)
````

### Creating a Custom Condition

```gdscript
extends FKCondition

func get_id() -> String:
    return "my_custom_condition"

func get_name() -> String:
    return "My Custom Condition"

func get_supported_types() -> Array:
    return ["Node"]

func get_inputs() -> Array:
    return [{"name": "threshold", "type": "float"}]

func check(node: Node, inputs: Dictionary) -> bool:
    var threshold = inputs.get("threshold", 0.0)
    return true
```

### Creating a Custom Event

```gdscript
extends FKEvent

func get_id() -> String:
    return "on_custom_event"

func get_name() -> String:
    return "On Custom Event"

func get_supported_types() -> Array:
    return ["Node"]

func poll(node: Node) -> bool:
    return false
```

## 📁 File Structure

```
flowkit/
├── flowkit.gd
├── registry.gd
├── actions/
├── conditions/
├── events/
├── resources/
├── runtime/
├── ui/
└── saved/
```

## 💡 Usage Tips

* Event sheets match scenes by filename
* Node paths are relative to the scene root
* Inputs support GDScript expressions
* Group providers in folders
* Check the console for FlowKit logs

## 🛠️ Development

* Godot 4.5+
* Knowledge of GDScript
* Understanding of Godot plugins

## 📄 License

MIT License.

## 🙏 Acknowledgments

* Clickteam Fusion 2.5
* Construct
* Scratch
* Godot Engine

## 📞 Support

Open an issue on GitHub for questions or bugs, alternatively you can ask in the Discussions or Discord community, but issues are preferred.

---

**Made with ❤️ for the Godot community by LexianDEV**

```
