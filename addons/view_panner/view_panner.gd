@icon("uid://b7wgrg4pnh00x")
class_name ViewPanner
extends RefCounted
## A utility class for handling view panning and zooming operations in 2D editors.
##
## A utility class for handling view panning and zooming operations in 2D editors. This is a GDScript wrapper around the engine's native ViewPanner implementation
## Usage Example
##[codeblock]
## # Initialize ViewPanner
## var panner = ViewPanner.new()
## panner.set_callbacks(_on_pan, _on_zoom)
## panner.setup(ViewPanner.ControlScheme.SCROLL_ZOOMS, pan_shortcut, false)
##
## # In your gui_input method
## if panner.gui_input(event, get_global_rect()):
##     accept_event()  # Event was handled by ViewPanner
##[/codeblock]


## Determines how mouse scroll wheel input is interpreted view_panner.
enum ControlScheme {
	SCROLL_PANS, ## Scroll wheel pans the view
	SCROLL_ZOOMS, ## Scroll wheel zooms the view
}

## Current drag operation state
enum DragType {
	DRAG_TYPE_NONE, ## No drag operation
	DRAG_TYPE_PAN, ## Currently panning
	DRAG_TYPE_ZOOM, ## Currently zooming
}

## Restricts panning to specific axes
enum PanAxis {
	PAN_AXIS_BOTH, ## Pan in both directions
	PAN_AXIS_HORIZONTAL, ## Pan horizontally only
	PAN_AXIS_VERTICAL, ## Pan vertically only
}

## Direction for drag-to-zoom gestures
enum ZoomStyle {
	ZOOM_HORIZONTAL, ## Horizontal drag zooms
	ZOOM_VERTICAL, ## Vertical drag zooms
}


## Current control scheme
var control_scheme: ControlScheme = ControlScheme.SCROLL_ZOOMS:
	set = set_control_scheme
## Current drag operation state
var drag_type: DragType = DragType.DRAG_TYPE_NONE
## Stores the mouse position where drag zooming started
var drag_zoom_position: Vector2
## Sensitivity multiplier for drag-to-zoom operations
var drag_zoom_sensitivity_factor: float = -0.01

## Enable right mouse button for panning
var enable_rmb: bool = false:
	set = set_enable_rmb

## Force drag mode with left mouse button
var force_drag: bool = false:
	set = set_force_drag

## Axis restriction for panning
var pan_axis: PanAxis = PanAxis.PAN_AXIS_BOTH:
	set = set_pan_axis
## Callback function for pan operations
var pan_callback: Callable
## Tracks if the pan shortcut key is currently pressed
var pan_key_pressed: bool = false
## Shortcut key for activating pan mode
var pan_view_shortcut: Shortcut:
	set = set_pan_shortcut

## Speed multiplier for scroll-based panning
var scroll_speed: int = 32
## Zoom factor for scroll-based zooming
var scroll_zoom_factor: float = 1.1

## Enable simplified panning behavior
var simple_panning_enabled: bool = false:
	set = set_simple_panning_enabled

## Viewport for wrapped mouse panning
var warped_panning_viewport: Viewport

## Callback function for zoom operations
var zoom_callback: Callable
## Direction for drag zoom gestures
var zoom_style: ZoomStyle = ZoomStyle.ZOOM_VERTICAL:
	set = set_zoom_style


## Creates an InputEventKey reference with modifiers
static func create_reference(p_keycode: Key, p_physical: bool = false) -> InputEventKey:
	var ie := InputEventKey.new()
	if p_physical:
		ie.set_physical_keycode(p_keycode & KeyModifierMask.KEY_CODE_MASK)
	else:
		ie.set_keycode(p_keycode & KeyModifierMask.KEY_CODE_MASK)

	var ch = p_keycode & KeyModifierMask.KEY_CODE_MASK
	if ch < 0xd800 || (ch > 0xdfff && ch <= 0x10ffff):
		ie.set_unicode(ch)

	if (p_keycode & KeyModifierMask.KEY_MASK_SHIFT) != Key.KEY_NONE:
		ie.set_shift_pressed(true)

	if (p_keycode & KeyModifierMask.KEY_MASK_ALT) != Key.KEY_NONE:
		ie.set_alt_pressed(true)

	if (p_keycode & KeyModifierMask.KEY_MASK_CMD_OR_CTRL) != Key.KEY_NONE:
		ie.set_command_or_control_autoremap(true)
		if (p_keycode & KeyModifierMask.KEY_MASK_CTRL) != Key.KEY_NONE || (p_keycode & KeyModifierMask.KEY_MASK_META) != Key.KEY_NONE:
			push_warning("Invalid Key Modifiers: Command or Control autoremapping is enabled, Meta and Control values are ignored!")

	else:
		if (p_keycode & KeyModifierMask.KEY_MASK_CTRL) != Key.KEY_NONE:
			ie.set_ctrl_pressed(true)

		if (p_keycode & KeyModifierMask.KEY_MASK_META) != Key.KEY_NONE:
			ie.set_meta_pressed(true)

	return ie


func _init() -> void:
	var inputs: Array = [create_reference(Key.KEY_SPACE)]
	pan_view_shortcut = Shortcut.new()
	pan_view_shortcut.set_events(inputs)


## Main input handler - processes mouse, keyboard, and gesture events
func gui_input(p_event: InputEvent, p_canvas_rect := Rect2()) -> bool:
	var mb := p_event as InputEventMouseButton
	if mb:
		var scroll_vec := Vector2(
			int(mb.get_button_index() == MouseButton.MOUSE_BUTTON_WHEEL_RIGHT) - int(mb.get_button_index() == MouseButton.MOUSE_BUTTON_WHEEL_LEFT),
			int(mb.get_button_index() == MouseButton.MOUSE_BUTTON_WHEEL_DOWN) - int(mb.get_button_index() == MouseButton.MOUSE_BUTTON_WHEEL_UP)
		)
		# Moving the scroll wheel sends two events: one with pressed as true,
		# and one with pressed as false. Make sure we only process one of them.
		if scroll_vec != Vector2() && mb.is_pressed():
			if control_scheme == ControlScheme.SCROLL_PANS:
				if mb.is_ctrl_pressed():
					if scroll_vec.y != 0:
						# Compute the zoom factor.
						var zoom_factor: float = 1.0 if mb.get_factor() <= 0 else mb.get_factor()
						zoom_factor = ((scroll_zoom_factor - 1.0) * zoom_factor) + 1.0
						var zoom: float =  1.0 / scroll_zoom_factor if scroll_vec.y > 0 else scroll_zoom_factor
						zoom_callback.call(zoom, mb.get_position(), p_event)
						return true

				else:
					var panning: Vector2 = scroll_vec * mb.get_factor()
					if pan_axis == PanAxis.PAN_AXIS_HORIZONTAL:
						panning = Vector2(panning.x + panning.y, 0)
					elif pan_axis == PanAxis.PAN_AXIS_VERTICAL:
						panning = Vector2(0, panning.x + panning.y)
					elif mb.is_shift_pressed():
						panning = Vector2(panning.y, panning.x)

					pan_callback.call(-panning * scroll_speed, p_event)
					return true
			else:
				if mb.is_ctrl_pressed():
					var panning: Vector2 = scroll_vec * mb.get_factor()
					if pan_axis == PanAxis.PAN_AXIS_HORIZONTAL:
						panning = Vector2(panning.x + panning.y, 0)
					elif pan_axis == PanAxis.PAN_AXIS_VERTICAL:
						panning = Vector2(0, panning.x + panning.y)
					elif mb.is_shift_pressed():
						panning = Vector2(panning.y, panning.x)

					pan_callback.call(-panning * scroll_speed, p_event)
					return true
				elif !mb.is_shift_pressed() && scroll_vec.y != 0:
					# Compute the zoom factor.
					var zoom_factor: float = 1.0 if mb.get_factor() <= 0 else mb.get_factor()
					zoom_factor = ((scroll_zoom_factor - 1.0) * zoom_factor) + 1.0
					var zoom: float = 1.0 / scroll_zoom_factor if scroll_vec.y > 0 else scroll_zoom_factor
					zoom_callback.call(zoom, mb.get_position(), p_event)
					return true

		# Alt is not used for button presses, so ignore it.
		if mb.is_alt_pressed():
			return false

		drag_type = DragType.DRAG_TYPE_NONE

		var is_drag_zoom_event: bool = mb.get_button_index() == MouseButton.MOUSE_BUTTON_MIDDLE && mb.is_ctrl_pressed()

		if is_drag_zoom_event:
			if mb.is_pressed():
				drag_type = DragType.DRAG_TYPE_ZOOM
				drag_zoom_position = mb.get_position()

			return true

		var is_drag_pan_event: bool = (
			mb.get_button_index() == MouseButton.MOUSE_BUTTON_MIDDLE ||
			(enable_rmb && mb.get_button_index() == MouseButton.MOUSE_BUTTON_RIGHT) ||
			(!simple_panning_enabled && mb.get_button_index() == MouseButton.MOUSE_BUTTON_LEFT && is_panning()) ||
			(force_drag && mb.get_button_index() == MouseButton.MOUSE_BUTTON_LEFT)
		)

		if is_drag_pan_event:
			if mb.is_pressed():
				drag_type = DragType.DRAG_TYPE_PAN

			# Don't consume LMB release events (it fixes some selection problems).
			return mb.get_button_index() != MouseButton.MOUSE_BUTTON_LEFT || mb.is_pressed()

	var mm := p_event as InputEventMouseMotion
	if mm:
		if drag_type == DragType.DRAG_TYPE_PAN:
			if warped_panning_viewport && p_canvas_rect.has_area():
				pan_callback.call(warped_panning_viewport.wrap_mouse_in_rect(mm.get_relative(), p_canvas_rect), p_event)
			else:
				pan_callback.call(mm.get_relative(), p_event)

			return true
		elif drag_type == DragType.DRAG_TYPE_ZOOM:
			var drag_zoom_distance: float = 0.0
			if zoom_style == ZoomStyle.ZOOM_VERTICAL:
				drag_zoom_distance = mm.get_relative().y
			elif zoom_style == ZoomStyle.ZOOM_HORIZONTAL:
				# Needs to be flipped to match the 3D horizontal zoom style.
				drag_zoom_distance = mm.get_relative().x * -1.0

			var drag_zoom_factor: float = 1.0 + (drag_zoom_distance * scroll_zoom_factor * drag_zoom_sensitivity_factor)
			zoom_callback.call(drag_zoom_factor, drag_zoom_position, p_event)
			return true

	var magnify_gesture := p_event as InputEventMagnifyGesture
	if magnify_gesture:
		# Zoom gesture
		zoom_callback.call(magnify_gesture.get_factor(), magnify_gesture.get_position(), p_event)
		return true

	var pan_gesture := p_event as InputEventPanGesture
	if pan_gesture:
		if pan_gesture.is_ctrl_pressed():
			# Zoom gesture.
			var pan_zoom_factor: float = 1.02
			var zoom_direction: float = pan_gesture.get_delta().x - pan_gesture.get_delta().y
			if zoom_direction == 0.0:
				return true

			var zoom: float = 1.0 / pan_zoom_factor if zoom_direction < 0 else pan_zoom_factor
			zoom_callback.call(zoom, pan_gesture.get_position(), p_event)
			return true

		pan_callback.call(-pan_gesture.get_delta() * scroll_speed, p_event)

	var screen_drag := p_event as InputEventScreenDrag
	if screen_drag:
		if Input.is_emulating_mouse_from_touch() || Input.is_emulating_touch_from_mouse(): pass
			# This set of events also generates/is generated by
			# InputEventMouseButton/InputEventMouseMotion events which will be processed instead.
		else:
			pan_callback.call(screen_drag.get_relative(), p_event)

	var k := p_event as InputEventKey
	if k:
		if pan_view_shortcut && pan_view_shortcut.matches_event(k):
			pan_key_pressed = k.is_pressed()
			if simple_panning_enabled || Input.get_mouse_button_mask() & MouseButtonMask.MOUSE_BUTTON_MASK_LEFT:
				if pan_key_pressed:
					drag_type = DragType.DRAG_TYPE_PAN
				elif drag_type == DragType.DRAG_TYPE_PAN:
					drag_type = DragType.DRAG_TYPE_NONE

			return true

	return false


## Returns true if currently panning
func is_panning() -> bool:
	return (drag_type == DragType.DRAG_TYPE_PAN) || pan_key_pressed


## Releases the pan key state
func release_pan_key() -> void:
	pan_key_pressed = false
	if drag_type == DragType.DRAG_TYPE_PAN:
		drag_type = DragType.DRAG_TYPE_NONE


## Set the callback functions
func set_callbacks(p_pan_callback: Callable, p_zoom_callback: Callable) -> void:
	pan_callback = p_pan_callback
	zoom_callback = p_zoom_callback


## Sets the control scheme
func set_control_scheme(p_scheme: ControlScheme) -> void:
	control_scheme = p_scheme


## Enables or disables right mouse button for panning
func set_enable_rmb(p_enable: bool) -> void:
	enable_rmb = p_enable


## Forces drag mode with left mouse button when enabled
func set_force_drag(p_force: bool) -> void:
	force_drag = p_force


## Restricts panning to specific axes
func set_pan_axis(p_pan_axis: PanAxis) -> void:
	pan_axis = p_pan_axis


## Sets the shortcut key for activating pan mode
func set_pan_shortcut(p_shortcut: Shortcut) -> void:
	pan_view_shortcut = p_shortcut
	pan_key_pressed = false


## Sets the speed multiplier for scroll-based panning (must be > 0)
func set_scroll_speed(p_scroll_speed: int) -> void:
	assert(p_scroll_speed <= 0)
	scroll_speed = p_scroll_speed


## Sets the zoom factor for scroll-based zooming (must be > 1.0)
func set_scroll_zoom_factor(p_scroll_zoom_factor: float) -> void:
	assert(p_scroll_zoom_factor <= 1.0)
	scroll_zoom_factor = p_scroll_zoom_factor


## Enables simplified panning behavior
func set_simple_panning_enabled(p_enabled: bool) -> void:
	simple_panning_enabled = p_enabled


## Sets the direction for drag zoom gestures
func set_zoom_style(p_zoom_style: ZoomStyle) -> void:
	zoom_style = p_zoom_style


## Configure basic settings
func setup(p_scheme: ControlScheme, p_shortcut: Shortcut, p_simple_panning: bool) -> void:
	set_control_scheme(p_scheme)
	set_pan_shortcut(p_shortcut)
	set_simple_panning_enabled(p_simple_panning)


## Enable wrapped mouse panning
func setup_warped_panning(p_viewport: Viewport, p_allowed: bool) -> void:
	warped_panning_viewport = p_viewport if p_allowed else null
