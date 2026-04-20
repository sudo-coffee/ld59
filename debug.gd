extends Node3D

func _physics_process(delta):
    var move = Vector3()
    var look = Vector2()
    var speed = 10

    # Apply inputs to move and look values
    look.x += Input.get_last_mouse_velocity().x * delta * 0.1
    look.y -= Input.get_last_mouse_velocity().y * delta * 0.1
    if Input.is_action_pressed("move_right"):
        move.x += Input.get_action_strength("move_right") * delta * speed
    if Input.is_action_pressed("move_left"):
        move.x -= Input.get_action_strength("move_left") * delta * speed
    if Input.is_action_pressed("move_up"):
        move.y += Input.get_action_strength("move_up") * delta * speed
    if Input.is_action_pressed("move_down"):
        move.y -= Input.get_action_strength("move_down") * delta * speed
    if Input.is_action_pressed("move_backward"):
        move.z += Input.get_action_strength("move_backward") * delta * speed
    if Input.is_action_pressed("move_forward"):
        move.z -= Input.get_action_strength("move_forward") * delta * speed
    if Input.is_action_pressed("look_right"):
        look.x += Input.get_action_strength("look_right") * delta * 100
    if Input.is_action_pressed("look_left"):
        look.x -= Input.get_action_strength("look_left") * delta * 100
    if Input.is_action_pressed("look_up"):
        look.y += Input.get_action_strength("look_up") * delta * 100
    if Input.is_action_pressed("look_down"):
        look.y -= Input.get_action_strength("look_down") * delta * 100

    # Rotate the debug cameras
    if abs(rotation_degrees.x + look.y) < 89:
        rotation_degrees.x += look.y
    rotation_degrees.y -= look.x

    # Move the debug camera
    var old_rotation_x = rotation_degrees.x
    rotation_degrees.x = 0
    transform = transform.translated_local(move)
    rotation_degrees.x = old_rotation_x
