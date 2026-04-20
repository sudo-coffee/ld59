extends Node3D

var player_spin = Vector3()
var block_positions = {}
var block_rotations = {}

func _ready():
    var rng = RandomNumberGenerator.new()
    for map in $"< maps >".get_children():
        map.get_node("< blocks >").visible = false
    for block in $"< blocks >".get_children():
        for object in block.get_children():
            if object is MeshInstance3D:
                object.material_override = StandardMaterial3D.new()
                object.material_override.albedo_color = Color(
                    rng.randf_range(0.2, 0.24),
                    rng.randf_range(0.1, 0.14),
                    rng.randf_range(0.1, 0.14),
                    1,
                )
                object.material_override.metallic_specular = \
                    rng.randf_range(0.2, 0.3)
                object.material_override.metallic = \
                    rng.randf_range(0.2, 0.3)
    for map in $"< maps >".get_children():
        block_positions[map.name] = {}
        block_rotations[map.name] = {}
        for map_block in map.get_node("< blocks >").find_children("*"):
            if map_block is StaticBody3D:
                block_positions[map.name][map_block.name] = map_block.global_position
                block_rotations[map.name][map_block.name] = map_block.global_rotation
    Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func basis_standing_over(basis, vector):
    var new_basis = Basis()
    var temp_basis = Basis.looking_at(vector, -basis.z)
    new_basis.x = temp_basis.x
    new_basis.y = temp_basis.z
    new_basis.z = -temp_basis.y
    return new_basis

func _physics_process(delta):
    # Process beacon strength
    var listener_position = $player/receiver.global_position
    var beacon_values = {}
    var beacon_values_total = 0
    var beacon_distances = {}
    var beacon_distances_min = 99999999
    var beacon_values_normalized = {}
    for map in $"< maps >".get_children():
        var beacon = map.get_node("beacon")
        var distance = beacon.global_position.distance_to(listener_position)
        beacon_distances[map.name] = distance
        beacon_distances_min = min(beacon_distances_min, distance)
    for map_name in beacon_distances:
        var distance = beacon_distances[map_name]
        beacon_values[map_name] = 1 \
            / max(distance ** (20 / ((beacon_distances_min + 1) ** 0.5)), 0.001)
        beacon_values_total += beacon_values[map_name]
    for map_name in beacon_values:
        var value = beacon_values[map_name]
        var normalized = value / beacon_values_total
        beacon_values_normalized[map_name] = normalized

    # Get position and rotation targets
    var block_position_targets = {}
    var block_rotation_targets = {}
    for block in $"< blocks >".get_children():
        block_position_targets[block.name] = Vector3()
        block_rotation_targets[block.name] = Vector3()
    for map_name in block_positions:
        var value = beacon_values_normalized[map_name]
        for block_name in block_positions[map_name]:
            block_position_targets[block_name] += block_positions[map_name][block_name] * value
    for map_name in block_rotations:
        var value = beacon_values_normalized[map_name]
        for block_name in block_rotations[map_name]:
            block_rotation_targets[block_name] += block_rotations[map_name][block_name] * value

    #for map in $"< maps >".get_children():
        #var value = beacon_values_normalized[map.name]
        #for map_block in map.get_node("< blocks >").find_children("*"):
            #if map_block is StaticBody3D:
                #for block in $"< blocks >".get_children():
                    #if block.name == map_block.name:
                        #block_position_targets[block.name] \
                            #+= map_block.global_position * value
                        #block_rotation_targets[block.name] \
                            #+= map_block.global_rotation * value

    # Apply position and rotation targets
    var block_position_delta = {}
    var block_rotation_delta = {}
    for block in $"< blocks >".get_children():
        if Time.get_ticks_msec() < 5000:
            block.position = block_position_targets[block.name]
            block.rotation = block_rotation_targets[block.name]
            block_position_delta[block.name] = Vector3()
            block_rotation_delta[block.name] = Vector3()
        else:
            var old_block_position = block.position
            var old_block_rotation = block.rotation
            block.position = (block.position * (1 - delta)) \
                + (block_position_targets[block.name] * delta)
            block.rotation = (block.rotation * (1 - delta)) \
                + (block_rotation_targets[block.name] * delta)
            block_position_delta[block.name] = block.position \
                - old_block_position
            block_rotation_delta[block.name] = block.rotation \
                - old_block_rotation

    # Get info about floor under the player
    var floor_name = null
    var floor_effect = null
    var floor_normal = null
    var floor_point = null
    if $player/shape_cast.is_colliding():
        floor_name = $player/shape_cast.get_collider(0).name
        floor_effect = \
            1 - $player/shape_cast.get_closest_collision_safe_fraction()
        floor_normal = $player/shape_cast.get_collision_normal(0)
        floor_point = $player/shape_cast.target_position \
            * (1 - floor_effect) \
            * $player/shape_cast.global_basis.y \
            + $player.global_position
        floor_effect = min(floor_effect * 1.2, 1)

    # Apply block collisions to player
    var overlapping_blocks = $player/block_check.get_overlapping_bodies()
    var skip_floor_movement = false
    for block in overlapping_blocks:
        $player.velocity += block_position_delta[block.name] * 0.51
        $player.global_position += block_position_delta[block.name] * 0.51
        player_spin += block_rotation_delta[block.name] * 0.4
        if floor_name == block.name:
            skip_floor_movement = true

    ## Apply movement of floor to player
    for block in $"< blocks >".get_children():
        if block.name == floor_name and not skip_floor_movement:
            $player.velocity += block_position_delta[block.name] \
                * floor_effect * 0.8
            player_spin += block_rotation_delta[block.name] * 0.4 \
                * floor_effect * 0.8

    # Process head rotation
    var look = Vector2()
    look.x += Input.get_last_mouse_velocity().x * 0.1
    look.y -= Input.get_last_mouse_velocity().y * 0.1
    if Input.is_action_pressed("look_right"):
        look.x += Input.get_action_strength("look_right") * 120
    if Input.is_action_pressed("look_left"):
        look.x -= Input.get_action_strength("look_left") * 120
    if Input.is_action_pressed("look_up"):
        look.y += Input.get_action_strength("look_up") * 120
    if Input.is_action_pressed("look_down"):
        look.y -= Input.get_action_strength("look_down") * 120
    if abs($player/head.rotation_degrees.x + look.y * delta) < 70:
        $player/head.rotation_degrees.x += look.y * delta
    $player/head.rotation_degrees.y -= look.x * delta

    # Get position of gravity
    var gravity_position = Vector3()
    for map in $"< maps >".get_children():
        var beacon = map.get_node("beacon")
        gravity_position += beacon.global_position \
            * beacon_values_normalized[map.name]
    if floor_name:
        gravity_position = gravity_position * max(0.6 - floor_effect, 0)
        gravity_position += floor_point * min(0.4 + floor_effect, 1)

    # Apply gravity to player velocity
    var gravity_vector = $player.global_position.direction_to(gravity_position)
    var gravity_distance = $player.global_position.distance_to(gravity_position)
    var gravity = Vector3()
    if floor_name:
        gravity_vector = gravity_vector.slerp(-floor_normal, 0.1)
    if floor_name and floor_effect < 0.98:
        gravity += delta * gravity_vector * gravity_distance ** 0.8 * 0.2 \
            * (1 - floor_effect)
        gravity += delta * gravity_vector * floor_effect * 4
    elif not floor_name:
        gravity += delta * gravity_vector * gravity_distance ** 0.8 * 0.2
    $player.velocity += gravity

    # Apply gravity to player rotation
    if floor_name:
        var floor_basis = \
            basis_standing_over($player.global_basis, -floor_normal)
        $player.global_basis = \
            $player.global_basis.slerp(floor_basis, floor_effect * delta * 4)
    else:
        var torque = 0.8 / max(gravity_distance ** .2, 0.001)
        var gravity_basis = \
            basis_standing_over($player.global_basis, gravity_vector)
        $player.global_basis = \
            $player.global_basis.slerp(gravity_basis, delta * torque * .4)

    # Gradually center player view if not on floor
    if not floor_name:
        $player/head.global_basis.y = \
            $player/head.global_basis.y.slerp($player.up_direction, delta * 0.1)
        $player/head.global_basis = $player/head.global_basis.orthonormalized()

    #$player.global_basis = basis_standing_over($player.global_basis, Vector3(0, 1, 0))

    # Process input for movement
    var move = Vector2()
    if Input.is_action_pressed("move_backward"):
        move.y += Input.get_action_strength("move_backward")
    if Input.is_action_pressed("move_forward"):
        move.y -= Input.get_action_strength("move_forward")
    if Input.is_action_pressed("move_right"):
        move.x += Input.get_action_strength("move_right")
    if Input.is_action_pressed("move_left"):
        move.x -= Input.get_action_strength("move_left")
    if floor_name:
        var boost = 1 + 4 / max(1 + $player.velocity.length(), 0.001)
        var old_rotation_x = $player/head.rotation.x
        var new_velocity = Vector3()
        $player/head.rotation.x = 0
        new_velocity += $player/head.global_basis.z \
            * delta * move.y * boost * 0.4
        new_velocity += $player/head.global_basis.x \
            * delta * move.x * boost * 0.4
        new_velocity *= 1 + move.length() * delta * 0.4
        new_velocity *= 1 + $player.velocity.length() * delta * 4
        $player.velocity += new_velocity
        $player/head.rotation.x = old_rotation_x

    # Apply spin
    $player.global_rotation += player_spin * delta
    player_spin /= 1 + delta

    # Add friction
    if floor_name:
        var slide = min(move.length() + 0.2, 1)
        $player.velocity *= max(1 - floor_effect * delta * 8, slide)

    # Fix gimbal lock and other problems
    $player/head.rotation_degrees.z = 0
    if $player/head.rotation_degrees.x > 70:
        $player/head.rotation_degrees.x = 70
    if $player/head.rotation_degrees.x < -70:
        $player/head.rotation_degrees.x = -70
    if $player.rotation_degrees.x > 89.9:
        $player.rotation_degrees.x = 89.9
    if $player.rotation_degrees.x < -89.9:
        $player.rotation_degrees.x = -89.9
    if $player.rotation_degrees.z > 179.9:
        $player.rotation_degrees.z = 179.9
    if $player.rotation_degrees.z < -179.9:
        $player.rotation_degrees.z = -179.9

    # Set player's up direction
    $player.up_direction = $player.global_basis.y

    #print(gravity_distance)
    #print(gravity_vector)
    #print($player.global_position)
    ##print(floor_name)
    ##print(gravity)
    #print($player.velocity)
    ##print($player.up_direction)
    #print()

    #print("floor_effect    : ", floor_effect)
    #print("floor_name      : ", floor_name)
    #print("floor_normal    : ", floor_normal)
    #print("gravity_vector  : ", gravity_vector)
    #print("global_basis.y  : ", $player.global_basis.y)
    #print("head_basis.x    : ", $player/head.global_basis.x)
    #print("head_basis.z    : ", $player/head.global_basis.z)
    #print("velocity        : ", $player.velocity)
    #print("global_position : ", $player.global_position)
    #print()

    # Apply player velocity
    $player.move_and_slide()
