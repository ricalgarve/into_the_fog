extends SkeletonModifier3D

var aim_pitch_rad: float = 0.0
var use_procedural_walk: bool = false
var walk_cycle: float = 0.0
var walk_blend: float = 0.0

var _hips_idx: int = -1
var _spine_idx: int = -1
var _l_shoulder_idx: int = -1
var _r_shoulder_idx: int = -1
var _r_arm_idx: int = -1
var _r_forearm_idx: int = -1
var _l_arm_idx: int = -1
var _l_forearm_idx: int = -1
var _l_upleg_idx: int = -1
var _l_leg_idx: int = -1
var _r_upleg_idx: int = -1
var _r_leg_idx: int = -1

func _find_bone(skel: Skeleton3D, token: String) -> int:
	for i in range(skel.get_bone_count()):
		var bname := skel.get_bone_name(i)
		if bname == token or bname.ends_with("_" + token) or bname.ends_with(":" + token) or bname.contains("_" + token + "_") or bname.contains(":" + token + "_"):
			return i
	return -1

func _ensure_indices(skel: Skeleton3D) -> bool:
	if _r_arm_idx != -1:
		return true
	_hips_idx = _find_bone(skel, "Hips")
	_spine_idx = _find_bone(skel, "Spine2")
	_l_shoulder_idx = _find_bone(skel, "LeftShoulder")
	_r_shoulder_idx = _find_bone(skel, "RightShoulder")
	_r_arm_idx = _find_bone(skel, "RightArm")
	_r_forearm_idx = _find_bone(skel, "RightForeArm")
	_l_arm_idx = _find_bone(skel, "LeftArm")
	_l_forearm_idx = _find_bone(skel, "LeftForeArm")
	_l_upleg_idx = _find_bone(skel, "LeftUpLeg")
	_l_leg_idx = _find_bone(skel, "LeftLeg")
	_r_upleg_idx = _find_bone(skel, "RightUpLeg")
	_r_leg_idx = _find_bone(skel, "RightLeg")
	return _r_arm_idx != -1 and _r_forearm_idx != -1 and _l_arm_idx != -1 and _l_forearm_idx != -1

func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or not _ensure_indices(skel):
		return

	var hips_pos := skel.get_bone_global_pose(_hips_idx).origin
	var spine_pos := skel.get_bone_global_pose(_spine_idx).origin
	var l_sh_pos := skel.get_bone_global_pose(_l_shoulder_idx).origin
	var r_sh_pos := skel.get_bone_global_pose(_r_shoulder_idx).origin

	var up_dir := (spine_pos - hips_pos).normalized()
	var left_dir := (l_sh_pos - r_sh_pos).normalized()
	var fwd_dir := left_dir.cross(up_dir).normalized()

	var pitch_rot := Basis(left_dir, -aim_pitch_rad * 0.75)
	var aim_fwd := (pitch_rot * fwd_dir).normalized()
	var aim_up := (pitch_rot * up_dir).normalized()

	# Braço direito levantado para segurar o rifle na altura do peito/ombro
	var r_arm_dir := (aim_fwd * 0.85 - aim_up * 0.35 - left_dir * 0.28).normalized()
	var r_arm_global := _set_bone_local_aim(skel, _r_arm_idx, r_arm_dir, skel.get_bone_global_pose(_r_shoulder_idx).basis)

	var r_forearm_dir := (aim_fwd * 0.88 + aim_up * 0.14 + left_dir * 0.44).normalized()
	_set_bone_local_aim(skel, _r_forearm_idx, r_forearm_dir, r_arm_global)

	# Braço esquerdo levantado e cruzado para apoiar a parte frontal do rifle
	var l_arm_dir := (aim_fwd * 0.84 - aim_up * 0.36 - left_dir * 0.40).normalized()
	var l_arm_global := _set_bone_local_aim(skel, _l_arm_idx, l_arm_dir, skel.get_bone_global_pose(_l_shoulder_idx).basis)

	var l_forearm_dir := (aim_fwd * 0.90 + aim_up * 0.16 - left_dir * 0.32).normalized()
	_set_bone_local_aim(skel, _l_forearm_idx, l_forearm_dir, l_arm_global)

	# Movimento procedural das pernas caso o modelo não tenha animação Walk/Run própria
	if use_procedural_walk and _l_upleg_idx != -1 and _r_upleg_idx != -1:
		var hip_basis := skel.get_bone_global_pose(_hips_idx).basis
		var swing := sin(walk_cycle) * 0.55 * walk_blend
		var l_thigh_dir := (-aim_up * cos(swing) + aim_fwd * sin(swing)).normalized()
		var r_thigh_dir := (-aim_up * cos(-swing) + aim_fwd * sin(-swing)).normalized()
		var l_thigh_global := _set_bone_local_aim(skel, _l_upleg_idx, l_thigh_dir, hip_basis)
		var r_thigh_global := _set_bone_local_aim(skel, _r_upleg_idx, r_thigh_dir, hip_basis)

		if _l_leg_idx != -1:
			var l_knee_bend := maxf(0.0, -sin(walk_cycle)) * 0.65 * walk_blend
			var l_shin_dir := (-aim_up * cos(swing - l_knee_bend) + aim_fwd * sin(swing - l_knee_bend)).normalized()
			_set_bone_local_aim(skel, _l_leg_idx, l_shin_dir, l_thigh_global)
		if _r_leg_idx != -1:
			var r_knee_bend := maxf(0.0, sin(walk_cycle)) * 0.65 * walk_blend
			var r_shin_dir := (-aim_up * cos(-swing - r_knee_bend) + aim_fwd * sin(-swing - r_knee_bend)).normalized()
			_set_bone_local_aim(skel, _r_leg_idx, r_shin_dir, r_thigh_global)

func _set_bone_local_aim(skel: Skeleton3D, bone_idx: int, target_y_dir: Vector3, parent_global_basis: Basis) -> Basis:
	var old_local := skel.get_bone_pose_rotation(bone_idx)
	var old_global_basis := (parent_global_basis * Basis(old_local)).orthonormalized()
	var cur_y := old_global_basis.y.normalized()
	var delta_q := Quaternion(cur_y, target_y_dir)
	var new_global_basis := (Basis(delta_q) * old_global_basis).orthonormalized()
	var new_local_basis := (parent_global_basis.inverse() * new_global_basis).orthonormalized()
	skel.set_bone_pose_rotation(bone_idx, new_local_basis.get_rotation_quaternion())
	return new_global_basis
