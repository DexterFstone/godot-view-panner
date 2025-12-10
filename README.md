<table align="center">
  <tr>
    <td valign="middle">
      <img src="./icon.png" alt="icon" width="48" />
    </td>
    <td valign="middle">
      <h1>ViewPanner for GDScript</h1>
    </td>
  </tr>
</table>
A utility class for handling view panning and zooming operations in 2D editors. This is a GDScript wrapper around the engine's native ViewPanner implementation.

## Features
- Panning and Zooming: Support for pan and zoom operations with mouse and touch screen
- Scroll Control: Two modes for interpreting mouse scroll input (pan or zoom)
- Axis Restriction: Ability to restrict panning to specific axes
- Gestures: Support for zoom and pan gestures
- Customization: Various settings to customize behavior

## Installation
Copy the `view_panner.gd` file into your project.

## Basic Usage
```gdscript
# Initialize ViewPanner  
var panner = ViewPanner.new()  
panner.set_callbacks(_on_pan, _on_zoom)  
panner.setup(ViewPanner.ControlScheme.SCROLL_ZOOMS, pan_shortcut, false)  
  
# In your gui_input method  
func _gui_input(event):  
    if panner.gui_input(event, get_global_rect()):  
        accept_event()  # Event was handled by ViewPanner
```

## API Reference
### Enumerations
#### `ControlScheme`
Determines how mouse scroll wheel input is interpreted

- `SCROLL_PANS`: Scroll wheel pans the view
- `SCROLL_ZOOMS`: Scroll wheel zooms the view

#### `PanAxis`
Restricts panning to specific axes

- `PAN_AXIS_BOTH`: Pan in both directions
- `PAN_AXIS_HORIZONTAL`: Pan horizontally only
- `PAN_AXIS_VERTICAL`: Pan vertically only

#### `DragType`
Current drag operation state

- `DRAG_TYPE_NONE`: No drag operation
- `DRAG_TYPE_PAN`: Currently panning
- `DRAG_TYPE_ZOOM`: Currently zooming

#### `ZoomStyle`
Direction for drag-to-zoom gestures: view_panner.cpp:97-105

- `ZOOM_HORIZONTAL`: Horizontal drag zooms
- `ZOOM_VERTICAL`: Vertical drag zooms

### Main Methods
#### `setup()`
Configure basic settings:
```gdscript
func setup(p_scheme: ControlScheme, p_shortcut: Shortcut, p_simple_panning: bool)
```

#### `gui_input()`
Main input handler - processes mouse, keyboard, and gesture events:
```gdscript
func gui_input(p_event: InputEvent, p_canvas_rect := Rect2()) -> bool
```

#### `set_callbacks()`
Set the callback functions:
```gdscript
func set_callbacks(p_pan_callback: Callable, p_zoom_callback: Callable)
```

### Configuration Methods
- `set_control_scheme()`: Sets the control scheme
- `set_enable_rmb()`: Enables or disables right mouse button for panning
- `set_force_drag()`: Forces drag mode with left mouse button when enabled
- `set_pan_axis()`: Restricts panning to specific axes
- `set_scroll_speed()`: Sets the speed multiplier for scroll-based panning
- `set_scroll_zoom_factor()`: Sets the zoom factor for scroll-based zooming
- `set_simple_panning_enabled()`: Enables simplified panning behavior
- `set_zoom_style()`: Sets the direction for drag zoom gestures

### Complete Example
```gdscript
extends Control  
  
var panner: ViewPanner  
  
func _ready():  
    panner = ViewPanner.new()  
      
    # Create shortcut for panning (space key)  
    var shortcut = Shortcut.new()  
    var events = [ViewPanner.create_reference(KEY_SPACE)]  
    shortcut.set_events(events)  
      
    # Configure ViewPanner  
    panner.set_callbacks(_on_pan, _on_zoom)  
    panner.setup(ViewPanner.ControlScheme.SCROLL_ZOOMS, shortcut, false)  
    panner.set_scroll_speed(32)  
    panner.set_scroll_zoom_factor(1.1)  
  
func _gui_input(event):  
    if panner.gui_input(event, get_global_rect()):  
        accept_event()  
  
func _on_pan(scroll_vec: Vector2, event):  
    # Pan logic here  
    position -= scroll_vec  
  
func _on_zoom(zoom_factor: float, origin: Vector2, event):  
    # Zoom logic here  
    scale *= zoom_factor
```

## Notes
- This class is a GDScript wrapper around the native C++ ViewPanner implementation
- For best results, use it in custom controls or 2D editors
- You can customize the default behavior by setting callbacks
- The class supports touch gestures, mouse input, and keyboard shortcuts
- Warped panning allows for continuous panning when the mouse reaches screen edges

## License
This code is released under the same license as Godot Engine.
