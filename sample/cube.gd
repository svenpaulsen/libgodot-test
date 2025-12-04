extends MeshInstance3D

var rotation_speed := 2.0
var mouse_sensitivity := 0.005
var is_dragging := false
var last_mouse_pos := Vector2.ZERO

func _process(delta):
	rotate_x(delta)

	# WASD rotation
	if Input.is_key_pressed(KEY_W):
		rotate_x(-rotation_speed * delta)
	if Input.is_key_pressed(KEY_S):
		rotate_x(rotation_speed * delta)
	if Input.is_key_pressed(KEY_A):
		rotate_y(-rotation_speed * delta)
	if Input.is_key_pressed(KEY_D):
		rotate_y(rotation_speed * delta)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			if event.pressed:
				last_mouse_pos = event.position

	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - last_mouse_pos
		rotate_y(delta.x * mouse_sensitivity)
		rotate_x(delta.y * mouse_sensitivity)
		last_mouse_pos = event.position
