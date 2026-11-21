extends CharacterBody3D

@export var walk_speed: float = 3.2
@export var sprint_speed: float = 5.8
@export var acceleration: float = 10.0
@export var deceleration: float = 12.0
@export var jump_velocity: float = 4.6
@export var mouse_sensitivity: float = 0.0022
@export var start_in_third_person: bool = true
@export var model_yaw_offset_deg: float = 0.0

const CHARACTER_GLB := "res://assets/character/Soldier.glb"

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var body_visual: Node3D = $VisualBody

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_third_person: bool = true
var cam_blend: float = 1.0
var bob_timer: float = 0.0
var anim_player: AnimationPlayer
var current_anim: String = ""

func _ready() -> void:
	is_third_person = start_in_third_person
	cam_blend = 1.0 if is_third_person else 0.0
	if flashlight != null:
		flashlight.visible = false
	_setup_character_model()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_character_model() -> void:
	if body_visual == null:
		return
	for child in body_visual.get_children():
		child.queue_free()

	var packed := load(CHARACTER_GLB) as PackedScene
	if packed == null:
		push_warning("[Player] Modelo não encontrado: " + CHARACTER_GLB)
		return

	var model := packed.instantiate() as Node3D
	model.name = "CharacterModel"
	# CapsuleShape3D tem height=1.8, então os pés ficam em y = -0.9
	model.position = Vector3(0.0, -0.9, 0.0)
	model.rotation_degrees.y = model_yaw_offset_deg
	body_visual.add_child(model)

	anim_player = _find_animation_player(model)
	if anim_player != null:
		for anim_name in ["Idle", "Walk", "Run"]:
			if anim_player.has_animation(anim_name):
				anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_play_anim("Idle")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _play_anim(anim_name: String) -> void:
	if anim_player == null or current_anim == anim_name:
		return
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name, 0.2)
		current_anim = anim_name

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-70.0), deg_to_rad(75.0))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.keycode == KEY_V:
			is_third_person = not is_third_person
		elif event.keycode == KEY_F and flashlight != null:
			flashlight.visible = not flashlight.visible
	elif event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0

	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and input_dir.y < -0.1
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var target_vel := direction * target_speed

	var rate := acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, target_vel.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, rate * delta)

	move_and_slide()
	_update_camera_and_animation(delta)

func _update_camera_and_animation(delta: float) -> void:
	var target_blend: float = 1.0 if is_third_person else 0.0
	cam_blend = lerpf(cam_blend, target_blend, clampf(delta * 10.0, 0.0, 1.0))

	if body_visual != null:
		body_visual.visible = cam_blend > 0.25

	var h_speed: float = Vector2(velocity.x, velocity.z).length()
	var bob_y: float = 0.0
	if h_speed > 0.25 and is_on_floor():
		var is_running: bool = h_speed > walk_speed + 0.8
		_play_anim("Run" if is_running else "Walk")
		var ratio: float = clampf(h_speed / sprint_speed, 0.0, 1.0)
		bob_timer += delta * lerpf(8.5, 13.0, ratio)
		bob_y = sin(bob_timer) * lerpf(0.035, 0.065, ratio) * lerpf(1.0, 0.25, cam_blend)
	else:
		_play_anim("Idle")
		bob_timer = 0.0

	var desired_tp_local := Vector3(0.55, 0.15 + bob_y, 2.65)
	var fp_local := Vector3(0.0, bob_y, 0.0)

	# Evita que a câmera de 3ª pessoa atravesse paredes ou casas
	if cam_blend > 0.05:
		var pivot_world := head.global_position
		var cam_world := head.to_global(desired_tp_local)
		var query := PhysicsRayQueryParameters3D.create(pivot_world, cam_world, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.has("position"):
			var hit_pos: Vector3 = hit["position"]
			var dir := (hit_pos - pivot_world).normalized()
			var safe_dist: float = max(0.35, pivot_world.distance_to(hit_pos) - 0.2)
			desired_tp_local = head.to_local(pivot_world + dir * safe_dist)

	camera.position = fp_local.lerp(desired_tp_local, cam_blend)
