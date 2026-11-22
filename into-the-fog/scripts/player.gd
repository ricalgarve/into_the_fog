extends CharacterBody3D

@export var max_hp: float = 100.0
@export var walk_speed: float = 3.4
@export var sprint_speed: float = 6.0
@export var acceleration: float = 10.0
@export var deceleration: float = 12.0
@export var jump_velocity: float = 4.6
@export var mouse_sensitivity: float = 0.0022
@export var fire_cooldown: float = 0.16

const CHARACTER_GLB := "res://assets/character/Soldier.glb"
const CUSTOM_PLAYER_GLB := "res://assets/character/player_custom.glb"
const FPS_ARMS_GLB := "res://assets/weapons/fps_demo_arms.glb"
const AIM_MODIFIER_SCRIPT := preload("res://scripts/upper_body_aim_modifier.gd")
const MAX_BULLET_HOLES := 80

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var body_visual: Node3D = $VisualBody

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var hp: float = 100.0
var is_dead: bool = false
var match_started: bool = false
var kills: int = 0
var kill_streak: int = 0
var current_character_choice: String = "bolsonaro"
var spawn_position: Vector3

var bob_timer: float = 0.0
var anim_player: AnimationPlayer
var current_anim: String = ""
var aim_modifier: SkeletonModifier3D
var has_walk_anim: bool = false
var leg_cycle: float = 0.0
var leg_blend: float = 0.0

# Arma, som e marcas de tiro
var weapon_tp_root: Node3D
var muzzle_tp: Node3D
var muzzle_light_tp: OmniLight3D
var muzzle_mesh_tp: MeshInstance3D
var muzzle_timer: float = 0.0
var fire_timer: float = 0.0
var is_aiming: bool = false
var gun_audio: AudioStreamPlayer
var bullet_holes: Array[Node3D] = []
var status_label: Label
var _last_hud_fog_sec: int = -1
var _last_hud_fog_active: bool = false

func _ready() -> void:
	hp = max_hp
	spawn_position = global_position
	add_to_group("combatants")
	if flashlight != null:
		flashlight.visible = false
	_setup_gun_audio()
	_setup_hud()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func start_with_character(choice: String) -> void:
	current_character_choice = choice
	var model_path := CharacterRigHelper.resolve_model_path(choice)
	_setup_character_model(model_path)
	match_started = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_character_model(model_path: String) -> void:
	if body_visual == null:
		return
	var info := CharacterRigHelper.setup_model_on(body_visual, model_path, Color.WHITE)
	if info.is_empty():
		return

	anim_player = info.get("anim_player")
	has_walk_anim = info.get("has_walk_anim", false)
	aim_modifier = info.get("aim_modifier")
	current_anim = ""

	var attach := info.get("weapon_attach") as Node3D
	if attach != null:
		var inv_s: float = info.get("weapon_inv_scale", 1.0)
		var has_bone: bool = info.get("has_bone_attach", false)
		weapon_tp_root = Node3D.new()
		weapon_tp_root.name = "WeaponThirdPerson"
		weapon_tp_root.scale = Vector3.ONE * inv_s
		weapon_tp_root.position = Vector3(0.0, 0.08 * inv_s, 0.02 * inv_s) if has_bone else Vector3(0.22, 0.22, -0.32)
		attach.add_child(weapon_tp_root)
		_build_tp_rifle(weapon_tp_root)

func _build_tp_rifle(parent: Node3D) -> void:
	var rifle_mesh: Mesh = null
	var arms_packed := load(FPS_ARMS_GLB) as PackedScene
	if arms_packed != null:
		var tmp := arms_packed.instantiate()
		rifle_mesh = _find_mesh_by_name(tmp, "assualt")
		tmp.queue_free()

	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.14, 0.15, 0.17)
	gun_mat.metallic = 0.75
	gun_mat.roughness = 0.35

	if rifle_mesh != null:
		var mi := MeshInstance3D.new()
		mi.name = "AssaultRifleMesh"
		mi.mesh = rifle_mesh
		mi.material_override = gun_mat
		mi.scale = Vector3(0.85, 0.85, 0.85)
		parent.add_child(mi)

	muzzle_tp = Node3D.new()
	muzzle_tp.position = Vector3(0.0, 0.03, -0.58)
	parent.add_child(muzzle_tp)

	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.85, 0.35)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.72, 0.22)
	flash_mat.emission_energy_multiplier = 4.5

	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.10
	muzzle_mesh_tp = MeshInstance3D.new()
	muzzle_mesh_tp.mesh = sphere
	muzzle_mesh_tp.material_override = flash_mat
	muzzle_mesh_tp.visible = false
	muzzle_tp.add_child(muzzle_mesh_tp)

	muzzle_light_tp = OmniLight3D.new()
	muzzle_light_tp.light_color = Color(1.0, 0.75, 0.35)
	muzzle_light_tp.light_energy = 5.0
	muzzle_light_tp.omni_range = 9.0
	muzzle_light_tp.visible = false
	muzzle_tp.add_child(muzzle_light_tp)

func _setup_gun_audio() -> void:
	gun_audio = AudioStreamPlayer.new()
	gun_audio.name = "GunshotAudio"
	gun_audio.volume_db = -3.0
	gun_audio.stream = _generate_gunshot_wav()
	add_child(gun_audio)

func _generate_gunshot_wav() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.32
	var sample_count := int(float(mix_rate) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var lowpass := 0.0

	for i in range(sample_count):
		var t := float(i) / float(mix_rate)
		var freq := lerpf(190.0, 48.0, minf(t / 0.06, 1.0))
		var thump := sin(TAU * freq * t) * exp(-t * 32.0) * 0.75
		var noise := rng.randf_range(-1.0, 1.0)
		lowpass = lerpf(lowpass, noise, 0.45)
		var crack := noise * exp(-t * 24.0) * 0.85
		var tail := lowpass * exp(-t * 8.5) * 0.45
		var sample := clampf(thump + crack + tail, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

func _setup_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(4, 4)
	dot.color = Color(1, 1, 1, 0.9)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(dot)

	status_label = Label.new()
	status_label.position = Vector2(24, 24)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	status_label.add_theme_constant_override("outline_size", 4)
	canvas.add_child(status_label)
	_refresh_hud()

func _refresh_hud() -> void:
	if status_label == null:
		return
	var base_text := "Vida: %d   |   Abates: %d" % [int(maxf(0.0, hp)), kills]
	var fog_mgr := get_tree().get_first_node_in_group("fog_manager")
	if fog_mgr != null and match_started:
		var fog_active := bool(fog_mgr.get("is_fog_active"))
		var rem := int(ceilf(float(fog_mgr.call("get_time_remaining"))))
		if fog_active:
			status_label.text = "%s   |   NEVOEIRO: %ds" % [base_text, rem]
			status_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.38))
		else:
			status_label.text = "%s   |   Nevoeiro em: %ds" % [base_text, rem]
			status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	else:
		status_label.text = base_text

func _process(_delta: float) -> void:
	if not match_started or status_label == null:
		return
	var fog_mgr := get_tree().get_first_node_in_group("fog_manager")
	if fog_mgr == null:
		return
	var fog_active := bool(fog_mgr.get("is_fog_active"))
	var rem := int(ceilf(float(fog_mgr.call("get_time_remaining"))))
	if rem != _last_hud_fog_sec or fog_active != _last_hud_fog_active:
		_last_hud_fog_sec = rem
		_last_hud_fog_active = fog_active
		_refresh_hud()

func register_kill() -> void:
	kills += 1
	kill_streak += 1
	_refresh_hud()
	if kill_streak > 0 and kill_streak % 2 == 0:
		var audio_mgr := get_tree().current_scene.get_node_or_null("AudioManager")
		if audio_mgr != null and audio_mgr.has_method("play_upscore_audio"):
			audio_mgr.call("play_upscore_audio", current_character_choice)

func take_damage(amount: float, _attacker: Node3D = null) -> void:
	if is_dead:
		return
	hp -= amount
	_refresh_hud()
	if hp <= 0.0:
		is_dead = true
		kill_streak = 0
		await get_tree().create_timer(2.0).timeout
		if is_inside_tree():
			hp = max_hp
			is_dead = false
			global_position = spawn_position
			velocity = Vector3.ZERO
			_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not match_started:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-65.0), deg_to_rad(70.0))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.keycode == KEY_F and flashlight != null:
			flashlight.visible = not flashlight.visible
	elif event is InputEventMouseButton:
		if event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not match_started or is_dead:
		return

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
	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and input_dir.y < -0.1 and not is_aiming
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var target_vel := direction * target_speed

	var rate := acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, target_vel.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, rate * delta)

	move_and_slide()
	_handle_weapon(delta)
	_update_camera_and_animation(delta)

func _handle_weapon(delta: float) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)

	if muzzle_timer > 0.0:
		muzzle_timer -= delta
		if muzzle_timer <= 0.0:
			if muzzle_mesh_tp: muzzle_mesh_tp.visible = false
			if muzzle_light_tp: muzzle_light_tp.visible = false

	var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	is_aiming = captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	if captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_timer <= 0.0:
		_fire_weapon()

	var target_fov: float = 55.0 if is_aiming else 75.0
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 12.0, 0.0, 1.0))

func _fire_weapon() -> void:
	fire_timer = fire_cooldown
	muzzle_timer = 0.055
	if muzzle_mesh_tp: muzzle_mesh_tp.visible = true
	if muzzle_light_tp: muzzle_light_tp.visible = true

	if gun_audio != null:
		gun_audio.pitch_scale = randf_range(0.94, 1.06)
		gun_audio.play()

	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	var to := from + dir * 150.0
	var muzzle_origin := muzzle_tp.global_position if muzzle_tp != null else from

	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("position"):
		var hit_pos: Vector3 = hit["position"]
		var hit_normal: Vector3 = hit["normal"]
		_spawn_tracer(muzzle_origin, hit_pos)
		_spawn_impact_spark(hit_pos)
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("take_damage"):
			collider.call("take_damage", 34.0, self)
		else:
			_spawn_bullet_hole(hit_pos, hit_normal)
	else:
		_spawn_tracer(muzzle_origin, to)

func _spawn_tracer(start_pos: Vector3, end_pos: Vector3) -> void:
	var dist := start_pos.distance_to(end_pos)
	if dist < 0.2:
		return
	var tracer := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.015, 0.015, dist)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.3)
	mat.emission_energy_multiplier = 3.5
	tracer.mesh = bm
	tracer.material_override = mat
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (start_pos + end_pos) * 0.5
	var up := Vector3.UP if absf((end_pos - start_pos).normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	tracer.look_at(end_pos, up)
	get_tree().create_timer(0.045).timeout.connect(tracer.queue_free)

func _spawn_impact_spark(pos: Vector3) -> void:
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.58, 0.18)
	mat.emission_energy_multiplier = 4.0
	spark.mesh = sm
	spark.material_override = mat
	spark.global_position = pos
	get_tree().current_scene.add_child(spark)
	get_tree().create_timer(0.18).timeout.connect(spark.queue_free)

func _spawn_bullet_hole(pos: Vector3, normal: Vector3) -> void:
	var hole := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.11, 0.11, 0.016)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.05)
	mat.roughness = 0.95
	hole.mesh = bm
	hole.material_override = mat
	get_tree().current_scene.add_child(hole)

	hole.global_position = pos + normal * 0.012
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	hole.look_at(pos + normal * 2.0, up)

	bullet_holes.append(hole)
	if bullet_holes.size() > MAX_BULLET_HOLES:
		var oldest := bullet_holes.pop_front() as Node3D
		if is_instance_valid(oldest):
			oldest.queue_free()

func _update_camera_and_animation(delta: float) -> void:
	if aim_modifier != null:
		aim_modifier.set("aim_pitch_rad", head.rotation.x)

	var h_speed: float = Vector2(velocity.x, velocity.z).length()
	var bob_y: float = 0.0
	if h_speed > 0.25 and is_on_floor():
		var is_running: bool = h_speed > walk_speed + 0.8
		_play_anim("Run" if is_running else "Walk")
		var ratio: float = clampf(h_speed / sprint_speed, 0.0, 1.0)
		bob_timer += delta * lerpf(8.5, 13.0, ratio)
		bob_y = sin(bob_timer) * lerpf(0.012, 0.022, ratio)
		leg_cycle += delta * lerpf(8.5, 13.5, ratio)
		leg_blend = lerpf(leg_blend, 1.0, clampf(delta * 10.0, 0.0, 1.0))
	else:
		_play_anim("Idle")
		bob_timer = 0.0
		leg_blend = lerpf(leg_blend, 0.0, clampf(delta * 10.0, 0.0, 1.0))

	if aim_modifier != null:
		aim_modifier.set("walk_cycle", leg_cycle)
		aim_modifier.set("walk_blend", leg_blend)
	elif body_visual != null:
		# Para modelos estáticos sem esqueleto (ex: lula_hd.glb), aplica balanço natural de caminhada
		body_visual.position.y = absf(sin(leg_cycle)) * 0.06 * leg_blend
		body_visual.rotation_degrees.z = sin(leg_cycle) * 2.5 * leg_blend

	var desired_tp_local := Vector3(0.55, 0.15 + bob_y, 2.65)
	var pivot_world := head.global_position
	var cam_world := head.to_global(desired_tp_local)
	var query := PhysicsRayQueryParameters3D.create(pivot_world, cam_world, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("position"):
		var hit_pos: Vector3 = hit["position"]
		var dir := (hit_pos - pivot_world).normalized()
		var safe_dist: float = max(0.35, pivot_world.distance_to(hit_pos) - 0.2)
		desired_tp_local = head.to_local(pivot_world + dir * safe_dist)

	camera.position = desired_tp_local

	if weapon_tp_root != null:
		var aim_target := camera.global_position + (-camera.global_transform.basis.z) * 60.0
		weapon_tp_root.look_at(aim_target, Vector3.UP)

func _get_local_aabb(node: Node, rel_xform: Transform3D) -> AABB:
	var cur_xform := rel_xform
	if node is Node3D:
		cur_xform = rel_xform * (node as Node3D).transform

	var result := AABB()
	var has_bounds := false
	if node is VisualInstance3D:
		var local_aabb := (node as VisualInstance3D).get_aabb()
		if local_aabb.size != Vector3.ZERO:
			result = cur_xform * local_aabb
			has_bounds = true
	for child in node.get_children():
		var child_aabb := _get_local_aabb(child, cur_xform)
		if child_aabb.size != Vector3.ZERO:
			if has_bounds:
				result = result.merge(child_aabb)
			else:
				result = child_aabb
				has_bounds = true
	return result

func _find_mesh_by_name(node: Node, target_name: String) -> Mesh:
	if node is MeshInstance3D and node.name == target_name:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var m := _find_mesh_by_name(child, target_name)
		if m != null:
			return m
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _play_anim(anim_name: String) -> void:
	if anim_player == null:
		return
	var resolved := anim_name
	if not anim_player.has_animation(resolved):
		if anim_name == "Walk" and anim_player.has_animation("Walking"):
			resolved = "Walking"
		elif anim_name == "Run" and anim_player.has_animation("Running"):
			resolved = "Running"
		elif anim_name == "Idle":
			if current_anim != "":
				anim_player.pause()
				current_anim = ""
			return
		else:
			return
	if current_anim == resolved and anim_player.is_playing():
		return
	anim_player.play(resolved, 0.2)
	current_anim = resolved
