class_name CharacterRigHelper
extends RefCounted

const FALLBACK_GLB := "res://assets/character/Soldier.glb"
const BOLSONARO_GLB := "res://assets/character/bolsonaro.glb"
const LULA_FBX := "res://assets/character/lula.fbx"
const LULA_TEX := "res://assets/character/lula_diffuse.png"
const LULA_GLB := "res://assets/character/lula.glb"
const AIM_MODIFIER_SCRIPT := preload("res://scripts/upper_body_aim_modifier.gd")

static func resolve_model_path(choice: String) -> String:
	if choice == "bolsonaro":
		return BOLSONARO_GLB if ResourceLoader.exists(BOLSONARO_GLB) else FALLBACK_GLB
	if ResourceLoader.exists(LULA_FBX):
		return LULA_FBX
	if ResourceLoader.exists(LULA_GLB):
		return LULA_GLB
	return FALLBACK_GLB

static func setup_model_on(
	visual_parent: Node3D,
	model_path: String,
	tint: Color = Color.WHITE
) -> Dictionary:
	for child in visual_parent.get_children():
		child.queue_free()

	var packed := load(model_path) as PackedScene
	if packed == null:
		packed = load(FALLBACK_GLB) as PackedScene
		model_path = FALLBACK_GLB
	if packed == null:
		return {}

	var model := packed.instantiate() as Node3D
	model.name = "CharacterModel"
	visual_parent.add_child(model)

	var model_scale := 1.0
	var aabb := _get_local_aabb(model, Transform3D.IDENTITY)
	if model_path != FALLBACK_GLB and aabb.size.y < 0.01:
		model_scale = 42.0
		model.scale = Vector3.ONE * model_scale
		model.position = Vector3(0.0, -0.9, 0.0)
	elif aabb.size.y > 0.05:
		model_scale = clampf(1.8 / aabb.size.y, 0.05, 100.0)
		model.scale = Vector3.ONE * model_scale
		model.position = Vector3(0.0, -0.9 - aabb.position.y * model_scale, 0.0)
	else:
		model.position = Vector3(0.0, -0.9, 0.0)

	if model_path == LULA_FBX:
		model.rotation_degrees.y = 0.0
	elif model_path != FALLBACK_GLB:
		model.rotation_degrees.y = 180.0

	if tint != Color.WHITE:
		_tint_meshes(model, tint)

	var anim_player := _find_animation_player(model)
	var has_walk_anim := false
	if anim_player != null:
		for anim_name in ["Idle", "Walk", "Run", "Walking", "Running"]:
			if anim_player.has_animation(anim_name):
				anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		has_walk_anim = anim_player.has_animation("Walk") or anim_player.has_animation("Walking")
		if anim_player.has_animation("Idle"):
			anim_player.play("Idle")

	var skeleton := _find_skeleton(model)
	var aim_modifier: SkeletonModifier3D = null
	var weapon_attach_parent: Node3D = null
	var weapon_inv_scale := 1.0

	if skeleton != null:
		aim_modifier = AIM_MODIFIER_SCRIPT.new()
		aim_modifier.name = "UpperBodyAimModifier"
		aim_modifier.set("use_procedural_walk", not has_walk_anim)
		skeleton.add_child(aim_modifier)

		var hand_bone := ""
		for i in range(skeleton.get_bone_count()):
			var bname := skeleton.get_bone_name(i)
			if bname.contains("RightHand") and not bname.contains("Thumb") and not bname.contains("Index") and not bname.contains("Middle") and not bname.contains("Ring") and not bname.contains("Pinky"):
				hand_bone = bname
				break
		if hand_bone != "":
			var attach := BoneAttachment3D.new()
			attach.name = "RightHandAttachment"
			attach.bone_name = hand_bone
			skeleton.add_child(attach)
			weapon_attach_parent = attach
			var skel_scale := skeleton.global_transform.basis.get_scale().x
			weapon_inv_scale = 1.0 / maxf(skel_scale, 0.0001)

	return {
		"model": model,
		"anim_player": anim_player,
		"has_walk_anim": has_walk_anim,
		"aim_modifier": aim_modifier,
		"weapon_attach": weapon_attach_parent if weapon_attach_parent != null else visual_parent,
		"weapon_inv_scale": weapon_inv_scale,
		"has_bone_attach": weapon_attach_parent != null,
	}

static func _get_local_aabb(node: Node, rel_xform: Transform3D) -> AABB:
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

static func _apply_texture(node: Node, tex: Texture2D, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = tint
		mat.roughness = 0.75
		mi.material_override = mat
	for child in node.get_children():
		_apply_texture(child, tex, tint)

static func _tint_meshes(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.7
		mi.material_override = mat
	for child in node.get_children():
		_tint_meshes(child, tint)

static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
