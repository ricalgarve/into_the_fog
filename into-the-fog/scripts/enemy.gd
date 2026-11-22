extends CharacterBody3D

@export var max_hp: float = 100.0
@export var walk_speed: float = 3.0
@export var run_speed: float = 4.8
@export var fire_cooldown: float = 0.42
@export var vision_range: float = 55.0

const CHARACTER_GLB := "res://assets/character/Soldier.glb"
const CUSTOM_ENEMY_GLB := "res://assets/character/enemy_custom.glb"
const FPS_ARMS_GLB := "res://assets/weapons/fps_demo_arms.glb"
const AIM_MODIFIER_SCRIPT := preload("res://scripts/upper_body_aim_modifier.gd")

var hp: float = 100.0
var is_dead: bool = false
var character_choice: String = "lula"
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var anim_player: AnimationPlayer
var current_anim: String = ""
var aim_modifier: SkeletonModifier3D
var has_walk_anim: bool = false
var leg_cycle: float = 0.0
var leg_blend: float = 0.0
var weapon_root: Node3D
var muzzle_node: Node3D
var muzzle_mesh: MeshInstance3D
var muzzle_light: OmniLight3D
var gun_audio: AudioStreamPlayer3D

var current_target: Node3D
var fire_timer: float = 0.5
var strafe_dir: float = 1.0
var strafe_timer: float = 0.0
var retarget_timer: float = 0.0
var muzzle_timer: float = 0.0
var evade_timer: float = 0.0
var last_attacker: Node3D

signal died(killer: Node3D)

func _ready() -> void:
	hp = max_hp
	add_to_group("combatants")
	strafe_dir = 1.0 if randf() > 0.5 else -1.0
	_setup_collision()
	_setup_visuals()
	_setup_audio()

func _setup_collision() -> void:
	if get_node_or_null("CollisionShape3D") == null:
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.8
		col.shape = cap
		add_child(col)

func _setup_visuals() -> void:
	var visual_body := Node3D.new()
	visual_body.name = "VisualBody"
	add_child(visual_body)

	var model_path := CharacterRigHelper.resolve_model_path(character_choice)
	var tint := Color.WHITE if model_path != CharacterRigHelper.FALLBACK_GLB else Color(0.75, 0.38, 0.35)
	var info := CharacterRigHelper.setup_model_on(visual_body, model_path, tint)
	if info.is_empty():
		return

	anim_player = info.get("anim_player")
	has_walk_anim = info.get("has_walk_anim", false)
	aim_modifier = info.get("aim_modifier")

	var attach := info.get("weapon_attach") as Node3D
	if attach != null:
		var inv_s: float = info.get("weapon_inv_scale", 1.0)
		var has_bone: bool = info.get("has_bone_attach", false)
		weapon_root = Node3D.new()
		weapon_root.scale = Vector3.ONE * inv_s
		weapon_root.position = Vector3(0.0, 0.08 * inv_s, 0.02 * inv_s) if has_bone else Vector3(0.22, 0.22, -0.32)
		attach.add_child(weapon_root)
		_attach_rifle_mesh(weapon_root)

func _attach_rifle_mesh(parent: Node3D) -> void:
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
		mi.mesh = rifle_mesh
		mi.material_override = gun_mat
		mi.scale = Vector3(0.85, 0.85, 0.85)
		parent.add_child(mi)

	muzzle_node = Node3D.new()
	muzzle_node.position = Vector3(0.0, 0.03, -0.58)
	parent.add_child(muzzle_node)

	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.85, 0.35)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.72, 0.22)
	flash_mat.emission_energy_multiplier = 4.5

	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.10
	muzzle_mesh = MeshInstance3D.new()
	muzzle_mesh.mesh = sphere
	muzzle_mesh.material_override = flash_mat
	muzzle_mesh.visible = false
	muzzle_node.add_child(muzzle_mesh)

	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.75, 0.35)
	muzzle_light.light_energy = 4.5
	muzzle_light.omni_range = 8.0
	muzzle_light.visible = false
	muzzle_node.add_child(muzzle_light)

func _setup_audio() -> void:
	gun_audio = AudioStreamPlayer3D.new()
	gun_audio.max_distance = 75.0
	gun_audio.volume_db = -4.0
	gun_audio.stream = _generate_gunshot_wav()
	add_child(gun_audio)

func _generate_gunshot_wav() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.28
	var sample_count := int(float(mix_rate) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var lowpass := 0.0
	for i in range(sample_count):
		var t := float(i) / float(mix_rate)
		var freq := lerpf(185.0, 48.0, minf(t / 0.05, 1.0))
		var thump := sin(TAU * freq * t) * exp(-t * 32.0) * 0.75
		var noise := rng.randf_range(-1.0, 1.0)
		lowpass = lerpf(lowpass, noise, 0.45)
		var sample := clampf(thump + noise * exp(-t * 25.0) * 0.8 + lowpass * exp(-t * 9.0) * 0.4, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if muzzle_timer > 0.0:
		muzzle_timer -= delta
		if muzzle_timer <= 0.0:
			if muzzle_mesh: muzzle_mesh.visible = false
			if muzzle_light: muzzle_light.visible = false

	fire_timer = maxf(0.0, fire_timer - delta)
	strafe_timer -= delta
	retarget_timer -= delta
	evade_timer = maxf(0.0, evade_timer - delta)

	if strafe_timer <= 0.0:
		strafe_dir = -strafe_dir
		strafe_timer = randf_range(1.2, 2.6)

	if retarget_timer <= 0.0 or not _is_valid_target(current_target):
		current_target = _pick_best_target()
		retarget_timer = randf_range(0.6, 1.2)

	var move_dir := Vector3.ZERO
	var desired_speed := walk_speed

	if _is_valid_target(current_target):
		var to_target := current_target.global_position - global_position
		var flat_to := Vector3(to_target.x, 0.0, to_target.z)
		var dist := flat_to.length()
		var dir_to := flat_to.normalized() if dist > 0.01 else -transform.basis.z

		# Gira suavemente para o alvo
		var target_yaw := atan2(-dir_to.x, -dir_to.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 8.0, 0.0, 1.0))

		var has_los := _has_line_of_sight(current_target)

		# Só caminha para frente na direção do jogador (sem strafe nem recuo)
		if dist > 4.0:
			move_dir = dir_to
			desired_speed = walk_speed
		else:
			move_dir = Vector3.ZERO
			desired_speed = 0.0

		# Evita ficar preso em carros, postes ou paredes no caminho
		move_dir = _steer_around_obstacles(move_dir)

		if weapon_root != null:
			weapon_root.look_at(current_target.global_position + Vector3(0.0, 0.5, 0.0), Vector3.UP)

		if has_los and dist <= vision_range and fire_timer <= 0.0:
			_shoot_at(current_target)
	else:
		# Sem alvo visível: avança patrulhando em direção ao centro da rua (z = 0)
		var patrol_target := Vector3(randf_range(-4.0, 4.0), global_position.y, 0.0)
		var to_patrol := Vector3(patrol_target.x - global_position.x, 0.0, patrol_target.z - global_position.z)
		if to_patrol.length() > 3.0:
			move_dir = _steer_around_obstacles(to_patrol.normalized())
			var yaw := atan2(-move_dir.x, -move_dir.z)
			rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 5.0, 0.0, 1.0))
			desired_speed = walk_speed

	velocity.x = move_toward(velocity.x, move_dir.x * desired_speed, 10.0 * delta)
	velocity.z = move_toward(velocity.z, move_dir.z * desired_speed, 10.0 * delta)
	move_and_slide()

	var h_speed := Vector2(velocity.x, velocity.z).length()
	if h_speed > 0.3:
		_play_anim("Run" if h_speed > walk_speed + 0.6 else "Walk")
		leg_cycle += delta * 8.5
		leg_blend = lerpf(leg_blend, 1.0, clampf(delta * 10.0, 0.0, 1.0))
	else:
		_play_anim("Idle")
		leg_blend = lerpf(leg_blend, 0.0, clampf(delta * 10.0, 0.0, 1.0))

	if aim_modifier != null:
		aim_modifier.set("walk_cycle", leg_cycle)
		aim_modifier.set("walk_blend", leg_blend)
	else:
		var vb := get_node_or_null("VisualBody") as Node3D
		if vb != null:
			vb.position.y = absf(sin(leg_cycle)) * 0.06 * leg_blend
			vb.rotation_degrees.z = sin(leg_cycle) * 2.5 * leg_blend

func _steer_around_obstacles(desired_dir: Vector3) -> Vector3:
	if desired_dir.length_squared() < 0.01:
		return desired_dir
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 0.8, 0.0)
	var fwd_query := PhysicsRayQueryParameters3D.create(origin, origin + desired_dir * 2.2, 1, [get_rid()])
	var hit := space.intersect_ray(fwd_query)
	if not hit.is_empty():
		var side := Vector3(-desired_dir.z, 0.0, desired_dir.x) * strafe_dir
		var side_query := PhysicsRayQueryParameters3D.create(origin, origin + side * 2.0, 1, [get_rid()])
		if space.intersect_ray(side_query).is_empty():
			return side.normalized()
		return (-side).normalized()
	return desired_dir

func _pick_best_target() -> Node3D:
	# Alvo exclusivo: apenas o jogador (não ataca outros adversários)
	var player := get_tree().current_scene.get_node_or_null("Player") as Node3D
	if _is_valid_target(player):
		return player
	return null

func _is_valid_target(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.get("is_dead") == true:
		return false
	return true

func _has_line_of_sight(target: Node3D) -> bool:
	var from := global_position + Vector3(0.0, 1.35, 0.0)
	var to := target.global_position + Vector3(0.0, 0.6, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit["collider"]
	return collider == target

func _shoot_at(target: Node3D) -> void:
	fire_timer = fire_cooldown + randf_range(0.0, 0.28)
	muzzle_timer = 0.055
	if muzzle_mesh: muzzle_mesh.visible = true
	if muzzle_light: muzzle_light.visible = true

	if gun_audio != null:
		gun_audio.pitch_scale = randf_range(0.92, 1.08)
		gun_audio.play()

	var from := muzzle_node.global_position if muzzle_node != null else (global_position + Vector3(0.0, 1.35, 0.0))
	var aim_point := target.global_position + Vector3(0.0, 0.45, 0.0)
	var dir := (aim_point - from).normalized()

	# Leve dispersão realista para não ter mira perfeita 100%
	dir = (dir + Vector3(randf_range(-0.045, 0.045), randf_range(-0.035, 0.035), randf_range(-0.045, 0.045))).normalized()
	var to := from + dir * 100.0

	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("position"):
		var hit_pos: Vector3 = hit["position"]
		_spawn_tracer(from, hit_pos)
		var collider: Object = hit["collider"]
		# Só causa dano se acertar o Player (nunca fere outro adversário)
		if collider != null and collider.name == "Player" and collider.has_method("take_damage"):
			collider.call("take_damage", 12.0, self)
	else:
		_spawn_tracer(from, to)

func _spawn_tracer(start_pos: Vector3, end_pos: Vector3) -> void:
	var dist := start_pos.distance_to(end_pos)
	if dist < 0.2:
		return
	var tracer := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.014, 0.014, dist)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.65, 0.2)
	mat.emission_energy_multiplier = 3.0
	tracer.mesh = bm
	tracer.material_override = mat
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (start_pos + end_pos) * 0.5
	var up := Vector3.UP if absf((end_pos - start_pos).normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	tracer.look_at(end_pos, up)
	get_tree().create_timer(0.04).timeout.connect(tracer.queue_free)

func take_damage(amount: float, attacker: Node3D = null) -> void:
	if is_dead:
		return
	hp -= amount
	if attacker != null and attacker.name == "Player" and _is_valid_target(attacker):
		last_attacker = attacker
		current_target = attacker

	if hp <= 0.0:
		is_dead = true
		remove_from_group("combatants")
		set_physics_process(false)
		var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null:
			col.disabled = true
		rotation_degrees.x = -85.0
		global_position.y -= 0.55
		died.emit(last_attacker)
		get_tree().create_timer(4.5).timeout.connect(queue_free)

func _tint_meshes(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.7
		mi.material_override = mat
	for child in node.get_children():
		_tint_meshes(child, tint)

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
