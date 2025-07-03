# Godot Angle Editor Plugin (In-House Tool)

This addon provides a UI for editing angle properties in the Godot editor, inspired by the workflow in Valve's Hammer Editor.

## Core Features

1.  **Angle Dial & Text Input:** A custom Inspector widget for any `float` property that replaces the default number box. It supports visual dragging, precise text input (with 0-360 clamping), and a "Point At" tool.
2.  **Viewport Gizmo:** A reusable component that draws a directional arrow in the 2D editor, synced to an angle property.

---

## How to Use

The plugin is designed to be simple and convention-based.

### 1. Getting the Inspector Dial

To get the custom UI for a property, you only need to follow one rule:

*   The exported `float` variable name **must end with the suffix `_angle`**.

**Example:**

```gdscript
# This script does NOT need @tool for the dial to appear.
extends CharacterBody2D

# This will automatically get the custom dial UI.
@export var facing_direction_angle: float = 0.0

# This will get the standard Godot UI.
@export var move_speed: float = 100.0
```

#### A Note on the `@tool` Annotation

While `@tool` is **not required** for the dial to show up, you should still add it to your script if you want that script's *own logic* (like a `_draw` function or a complex setter with `notify_property_list_changed()`) to run and update visuals within the editor itself. Our gizmo works without this because it is its own separate `@tool` script.

### 2. Getting the Viewport Gizmo

To display the corresponding arrow gizmo in the 2D editor:

1.  From the FileSystem, find `addons/angle_editor_plugin/angle_gizmo_2d.tscn`.
2.  **Drag `angle_gizmo_2d.tscn` and drop it as a child** of the node that has the `_angle` property.

The gizmo component is "smart" and requires **zero configuration**. It automatically finds the first `_angle` property on its parent node and begins tracking it.

---

## How It Works (Implementation Overview)

The plugin is split into logical parts:

*   **`plugin.gd`:** The main entry point. Its only jobs are to load the inspector plugin and to handle the "Point At..." viewport logic, as it's the only script with guaranteed access to `get_editor_interface()`.

*   **`angle_inspector_plugin.gd`:** Hooks into the Godot Inspector. It scans every property of a selected object. If it finds a `float` ending in `_angle`, it tells the editor to use our custom `AnglePropertyEditor` instead of the default UI. It also adds the "Point At..." button and `emits` a signal back to `plugin.gd` when it's clicked.

*   **`angle_property_editor.gd`:** The heart of the UI. This is a self-contained widget that manually draws the text, the dial, and a temporary `LineEdit`-style background for text input. It manages its own state for "dial dragging" vs. "text editing" and handles all the complex input logic. It uses `emit_changed()` to report new values back to the editor, which also creates Undo/Redo actions automatically.

*   **`angle_gizmo_2d.gd` / `.tscn`:** The gizmo component. This is a standard `@tool` script on a `Node2D`. It cannot be a global plugin due to Godot 4.x API limitations for 2D gizmos. Instead, it uses its `_draw()` function to inspect its parent, find the target `_angle` property, and draw an arrow based on that value. It calls `queue_redraw()` in `_process` to stay synced in real-time.
