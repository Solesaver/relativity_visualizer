extends Node3D

@export var rate : float = 1.0
@export var ray_mesh : MeshInstance3D

var ray_ball : ShaderMaterial

var time : float
var go : float
var light_speed : float

var velocity : Vector3
var speed : float
var lorentz : float

var mode : int
var dirty : bool

func _ready():
	ray_ball = ray_mesh.get_active_material(0)
	
	time = 50.0
	go = 0.0
	
	light_speed = 30.0
	velocity = Vector3(0.0, 0.0, -1.0)
	speed = 0.0
	lorentz  = 1.0
	
	mode = 0
	dirty = true

func _input(event):
	if event is InputEventKey:
		var value = 0.0
		if event.is_pressed():
			value = 1.0
		
		if event.is_released():
			if event.keycode == KEY_TAB:
				mode = (mode + 1) % 4
			elif event.keycode == KEY_SPACE:
				time = 50.0
				light_speed = 30.0
				speed = 0.0
				velocity = Vector3(0.0, 0.0, 1.0)
				ray_ball.set_shader_parameter("time", time)
				ray_ball.set_shader_parameter("light_speed", light_speed)
				ray_ball.set_shader_parameter("speed", speed)
				ray_ball.set_shader_parameter("velocity", velocity)
				dirty = true;
		
		if event.keycode == KEY_R:
			go = value
			dirty = true;
		elif event.keycode == KEY_F:
			go = -value
			dirty = true;

func _process(delta):
	if (dirty):
		UpdateDirty(delta)

func UpdateDirty(delta):
	match mode:
		0:
			time += delta * rate * go
			time = clampf(time, 0.0, 100.0)
			ray_ball.set_shader_parameter("time", time)
		1:
			light_speed += delta * rate * go * 10.0
			light_speed = clampf(light_speed, max(speed * 1.1, 20.0), 500.0)
			lorentz = 1.0 / sqrt(1.0 - speed ** 2 / light_speed ** 2)
			ray_ball.set_shader_parameter("light_speed", light_speed)
		2:
			speed += delta * rate * go * 10.0
			speed = clampf(speed, 0.0, light_speed * 0.99)
			lorentz = 1.0 / sqrt(1.0 - speed ** 2 / light_speed ** 2)
			ray_ball.set_shader_parameter("speed", speed)
		3:
			velocity = velocity.rotated(Vector3.UP, delta * rate * go)
			ray_ball.set_shader_parameter("velocity", velocity)
	
	ray_ball.set_shader_parameter("lorentz", lorentz)
	
	dirty = false
