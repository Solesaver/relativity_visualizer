extends Camera3D
class_name FlyCamera
## Simple Fly Camera for Godot Engine 3.x / 4.x.
## This Fly camera can be moved using the mouse and keyboard "WASD".
## You can toggle this camera activation by pressing the TAB key.
## The idea is to put this camera as autoload.
## It's possible to customize it by changing: The mouse `sensibility` and camera `speed`.
## 
## If you want to contribute, please leave a comment, I'll update the code.
## 
## License: MIT.

# ------------------------------------------------------------------------ Const
@export var speed : float = 1.0
@export var turn : float = 1.0

# ----------------------------------------------------------------------- Global
var motion: Vector3
var rot: float
var default: Transform3D

# ----------------------------------------------------------------- Notification
func _ready():
	default = global_transform


func _input(event):
	if event is InputEventKey:

		var value: float = 0
		if event.pressed:
			value = 1

		if event.keycode == KEY_A:
			motion.x = -value
		elif event.keycode == KEY_D:
			motion.x = value
		elif event.keycode == KEY_W:
			motion.z = -value
		elif event.keycode == KEY_S:
			motion.z = value
		elif event.keycode == KEY_Q:
			rot = value
		elif event.keycode == KEY_E:
			rot = -value
		elif event.keycode == KEY_SPACE:
			reset_camera();
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta):
	translate(motion * delta * speed)
	rotate(Vector3.UP, rot * delta * turn)


# ---------------------------------------------------------------------- Private
func reset_camera():
	global_transform = default;
