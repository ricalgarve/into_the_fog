@tool
extends Node3D

@export var rebuild_in_editor: bool = false:
	set(value):
		if value:
			rebuild_in_editor = false
			build_map()

const GLB_PATH := "res://assets/neighborhood_market/GLB/Supermarket_All.glb"
const BUILD_TAG := "CozySunsetNeighborhood"

var _mesh_cache: Dictionary = {}

func _ready() -> void:
	if get_node_or_null(BUILD_TAG) == null:
		build_map()

func build_map() -> void:
	for child in get_children():
		child.queue_free()

	var root := Node3D.new()
	root.name = BUILD_TAG
	add_child(root)

	var packed := load(GLB_PATH) as PackedScene
	if packed != null:
		var source := packed.instantiate()
		_mesh_cache.clear()
		_collect_meshes(source)
		source.queue_free()

	# 1. Estrada principal, calçadas e gramado amplo (z = -64 até +64)
	for z in range(-64, 68, 4):
		_place(root, "SM_Supermarket_AsphaltSlab_A", Vector3(-4.0, 0.0, float(z)), 0.0, true)
		_place(root, "SM_Supermarket_AsphaltSlab_B", Vector3(0.0, 0.0, float(z)), 0.0, true)
		_place(root, "SM_Supermarket_AsphaltSlab_A", Vector3(4.0, 0.0, float(z)), 0.0, true)

		_place(root, "SM_Supermarket_SidewalkSlab_A", Vector3(-8.0, 0.08, float(z)), 0.0, true)
		_place(root, "SM_Supermarket_SidewalkSlab_D", Vector3(-12.0, 0.08, float(z)), 0.0, true)
		_place(root, "SM_Supermarket_SidewalkSlab_A", Vector3(8.0, 0.08, float(z)), 0.0, true)
		_place(root, "SM_Supermarket_SidewalkSlab_D", Vector3(12.0, 0.08, float(z)), 0.0, true)

	for z in range(-64, 68, 8):
		for x in [-20.0, -28.0, -36.0, -44.0, 20.0, 28.0, 36.0, 44.0]:
			_place(root, "SM_Supermarket_Lawn_A", Vector3(x, -0.05, float(z)), 0.0, true)

	# 2. Casas aconchegantes e completas (sem frestas, telhado inclinado, varanda e janelas acesas)
	var house_configs := [
		# Lado esquerdo (viradas para +X / rua)
		{ "pos": Vector3(-18.5, 0.12, -38.0), "yaw": 90.0,  "w": 9.5,  "d": 7.5, "h": 3.6, "floors": 1, "wall": Color(0.36, 0.46, 0.52), "roof": Color(0.18, 0.17, 0.20) },
		{ "pos": Vector3(-19.0, 0.12, -20.0), "yaw": 90.0,  "w": 10.5, "d": 8.0, "h": 3.5, "floors": 2, "wall": Color(0.76, 0.71, 0.62), "roof": Color(0.24, 0.16, 0.14) },
		{ "pos": Vector3(-18.5, 0.12, -2.0),  "yaw": 90.0,  "w": 9.0,  "d": 7.5, "h": 3.6, "floors": 1, "wall": Color(0.42, 0.48, 0.38), "roof": Color(0.17, 0.18, 0.19) },
		{ "pos": Vector3(-19.0, 0.12, 16.0),  "yaw": 90.0,  "w": 10.0, "d": 8.0, "h": 3.5, "floors": 2, "wall": Color(0.62, 0.28, 0.24), "roof": Color(0.16, 0.16, 0.18) },
		{ "pos": Vector3(-18.5, 0.12, 36.0),  "yaw": 90.0,  "w": 9.5,  "d": 7.5, "h": 3.6, "floors": 1, "wall": Color(0.55, 0.50, 0.44), "roof": Color(0.20, 0.17, 0.16) },
		# Lado direito (viradas para -X / rua)
		{ "pos": Vector3(18.5, 0.12, -40.0),  "yaw": -90.0, "w": 9.5,  "d": 7.5, "h": 3.5, "floors": 2, "wall": Color(0.72, 0.66, 0.56), "roof": Color(0.19, 0.18, 0.20) },
		{ "pos": Vector3(19.0, 0.12, -22.0),  "yaw": -90.0, "w": 10.0, "d": 7.5, "h": 3.6, "floors": 1, "wall": Color(0.38, 0.44, 0.48), "roof": Color(0.22, 0.16, 0.15) },
		{ "pos": Vector3(18.5, 0.12, -4.0),   "yaw": -90.0, "w": 9.5,  "d": 8.0, "h": 3.5, "floors": 2, "wall": Color(0.48, 0.52, 0.42), "roof": Color(0.17, 0.17, 0.19) },
		{ "pos": Vector3(19.0, 0.12, 15.0),   "yaw": -90.0, "w": 10.0, "d": 7.5, "h": 3.6, "floors": 1, "wall": Color(0.64, 0.34, 0.26), "roof": Color(0.18, 0.16, 0.17) },
		{ "pos": Vector3(18.5, 0.12, 34.0),   "yaw": -90.0, "w": 9.5,  "d": 7.5, "h": 3.5, "floors": 2, "wall": Color(0.68, 0.64, 0.58), "roof": Color(0.20, 0.18, 0.18) },
	]

	for i in range(house_configs.size()):
		_build_cozy_house(root, "House_%02d" % (i + 1), house_configs[i])

	# 3. Postes de iluminação quentes ao longo da rua
	for z in [-52.0, -32.0, -12.0, 8.0, 28.0, 48.0]:
		_place_lamp(root, Vector3(-6.4, 0.14, z), 90.0)
		_place_lamp(root, Vector3(6.4, 0.14, z + 8.0), -90.0)

	# 4. Carros estacionados na rua
	_place(root, "SM_Supermarket_Car_A", Vector3(-4.3, 0.10, -28.0), 0.0, true)
	_place(root, "SM_Supermarket_Car_B", Vector3(4.3, 0.10, -14.0), 180.0, true)
	_place(root, "SM_Supermarket_Car_A", Vector3(4.3, 0.10, 18.0), 180.0, true)
	_place(root, "SM_Supermarket_Car_B", Vector3(-4.3, 0.10, 32.0), 0.0, true)

	# 5. Árvores nos jardins e bosque ao redor do bairro
	var trees := ["SM_Supermarket_Tree_A", "SM_Supermarket_Tree_B", "SM_Supermarket_Tree_C", "SM_Supermarket_Tree_D"]
	var idx := 0
	for z in range(-54, 58, 12):
		_place(root, trees[idx % trees.size()], Vector3(-28.0 - float((idx % 3) * 3), 0.0, float(z)), float(idx * 47), false)
		idx += 1
		_place(root, trees[idx % trees.size()], Vector3(28.0 + float((idx % 3) * 3), 0.0, float(z + 5)), float(idx * 63), false)
		idx += 1

	for z in [-48.0, -29.0, -11.0, 7.0, 26.0, 46.0]:
		_place(root, trees[idx % trees.size()], Vector3(-14.5, 0.05, z), float(idx * 35), false)
		idx += 1
		_place(root, trees[idx % trees.size()], Vector3(14.5, 0.05, z + 3.0), float(idx * 55), false)
		idx += 1

	# 6. Bancos, cercas vivas e detalhes de calçada
	for z in [-45.0, -25.0, -7.0, 11.0, 29.0]:
		_place(root, "SM_Supermarket_Hedge_A", Vector3(-13.2, 0.12, z), 90.0, true)
		_place(root, "SM_Supermarket_Hedge_A", Vector3(13.2, 0.12, z + 4.0), -90.0, true)

	_place(root, "SM_Supermarket_Bench_A", Vector3(-9.2, 0.12, -12.0), 90.0, true)
	_place(root, "SM_Supermarket_Bench_A", Vector3(9.2, 0.12, 6.0), -90.0, true)
	_place(root, "SM_Supermarket_StreetBin_A", Vector3(-7.0, 0.12, -15.0), 0.0, true)
	_place(root, "SM_Supermarket_StreetBin_B", Vector3(7.0, 0.12, 3.0), 180.0, true)

	# 7. Colinas ao fundo na neblina para fechar o horizonte
	_build_horizon_hills(root)

func _build_cozy_house(parent: Node3D, house_name: String, cfg: Dictionary) -> void:
	var house := Node3D.new()
	house.name = house_name
	house.position = cfg["pos"]
	house.rotation_degrees.y = cfg["yaw"]
	parent.add_child(house)

	var w: float = cfg["w"]
	var d: float = cfg["d"]
	var floor_h: float = cfg["h"]
	var floors: int = cfg["floors"]
	var total_h := floor_h * float(floors)

	var wall_mat := _make_mat(cfg["wall"], 0.85)
	var roof_mat := _make_mat(cfg["roof"], 0.75)
	var trim_mat := _make_mat(Color(0.88, 0.86, 0.82), 0.65)
	var wood_mat := _make_mat(Color(0.28, 0.17, 0.11), 0.7)
	var window_mat := _make_emissive_mat(Color(1.0, 0.78, 0.42), Color(1.0, 0.64, 0.24), 2.3)

	# Corpo principal sólido (com colisor!)
	_add_box(house, "Body", Vector3(0.0, total_h * 0.5, 0.0), Vector3(w, total_h, d), wall_mat, true)

	# Rodapé/base de pedra
	_add_box(house, "Foundation", Vector3(0.0, 0.15, 0.0), Vector3(w + 0.2, 0.3, d + 0.2), roof_mat, false)

	# Telhado inclinado (duas águas com PrismMesh)
	var roof_h := 2.4
	var prism := PrismMesh.new()
	prism.left_to_right = 0.5
	prism.size = Vector3(w + 1.0, roof_h, d + 1.0)
	var roof_mi := MeshInstance3D.new()
	roof_mi.name = "Roof"
	roof_mi.mesh = prism
	roof_mi.material_override = roof_mat
	roof_mi.position = Vector3(0.0, total_h + roof_h * 0.5 - 0.05, 0.0)
	house.add_child(roof_mi)

	# Chaminé
	_add_box(house, "Chimney", Vector3(w * 0.28, total_h + roof_h * 0.65, -d * 0.2), Vector3(0.75, 1.8, 0.75), roof_mat, false)

	# Varanda frontal (+Z local aponta para a rua)
	var front_z := d * 0.5
	_add_box(house, "PorchDeck", Vector3(0.0, 0.14, front_z + 1.0), Vector3(3.6, 0.28, 2.0), wood_mat, true)
	_add_box(house, "PorchRoof", Vector3(0.0, 3.05, front_z + 0.95), Vector3(3.8, 0.16, 2.1), roof_mat, false)
	_add_box(house, "PorchPillarL", Vector3(-1.65, 1.6, front_z + 1.8), Vector3(0.18, 2.8, 0.18), trim_mat, true)
	_add_box(house, "PorchPillarR", Vector3(1.65, 1.6, front_z + 1.8), Vector3(0.18, 2.8, 0.18), trim_mat, true)

	# Porta frontal + luz aconchegante
	_add_box(house, "DoorFrame", Vector3(0.0, 1.32, front_z + 0.04), Vector3(1.24, 2.25, 0.08), trim_mat, false)
	_add_box(house, "Door", Vector3(0.0, 1.30, front_z + 0.07), Vector3(1.04, 2.12, 0.06), wood_mat, false)

	var porch_light := OmniLight3D.new()
	porch_light.position = Vector3(0.0, 2.75, front_z + 1.1)
	porch_light.light_color = Color(1.0, 0.72, 0.36)
	porch_light.light_energy = 2.8
	porch_light.omni_range = 10.0
	house.add_child(porch_light)

	# Janelas com moldura e brilho quente em todos os andares e laterais
	for f in range(floors):
		var wy := f * floor_h + 1.85
		_add_framed_window(house, Vector3(-w * 0.30, wy, front_z + 0.05), 0.0, Vector2(1.45, 1.25), trim_mat, window_mat)
		_add_framed_window(house, Vector3(w * 0.30, wy, front_z + 0.05), 0.0, Vector2(1.45, 1.25), trim_mat, window_mat)
		if f >= 1:
			_add_framed_window(house, Vector3(0.0, wy, front_z + 0.05), 0.0, Vector2(1.3, 1.25), trim_mat, window_mat)

		_add_framed_window(house, Vector3(-w * 0.5 - 0.05, wy, 0.0), -90.0, Vector2(1.6, 1.25), trim_mat, window_mat)
		_add_framed_window(house, Vector3(w * 0.5 + 0.05, wy, 0.0), 90.0, Vector2(1.6, 1.25), trim_mat, window_mat)

func _add_framed_window(parent: Node3D, pos: Vector3, yaw_deg: float, size: Vector2, frame_mat: Material, glass_mat: Material) -> void:
	var win := Node3D.new()
	win.position = pos
	win.rotation_degrees.y = yaw_deg
	parent.add_child(win)

	_add_box(win, "Frame", Vector3.ZERO, Vector3(size.x + 0.2, size.y + 0.2, 0.06), frame_mat, false)
	_add_box(win, "Glass", Vector3(0.0, 0.0, 0.02), Vector3(size.x, size.y, 0.05), glass_mat, false)
	_add_box(win, "BarV", Vector3(0.0, 0.0, 0.05), Vector3(0.06, size.y, 0.03), frame_mat, false)
	_add_box(win, "BarH", Vector3(0.0, 0.0, 0.05), Vector3(size.x, 0.06, 0.03), frame_mat, false)

func _build_horizon_hills(parent: Node3D) -> void:
	var hill_mat := _make_mat(Color(0.14, 0.16, 0.13), 0.95)
	var hills := [
		Vector3(-68.0, 7.0, -55.0), Vector3(-72.0, 10.0, 0.0), Vector3(-66.0, 8.0, 58.0),
		Vector3(68.0, 8.0, -52.0),  Vector3(74.0, 11.0, 5.0),  Vector3(66.0, 7.5, 55.0),
		Vector3(0.0, 9.0, 82.0),    Vector3(-35.0, 8.0, 80.0), Vector3(36.0, 8.5, 78.0),
		Vector3(0.0, 8.5, -82.0),   Vector3(-38.0, 9.0, -78.0), Vector3(38.0, 8.0, -80.0),
	]
	for i in range(hills.size()):
		var sphere := SphereMesh.new()
		sphere.radius = 28.0
		sphere.height = 36.0
		var mi := MeshInstance3D.new()
		mi.name = "HorizonHill_%d" % i
		mi.mesh = sphere
		mi.material_override = hill_mat
		mi.position = hills[i]
		mi.scale = Vector3(1.6, 0.65, 1.6)
		parent.add_child(mi)

func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material, add_collision: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

	if add_collision:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		mi.add_child(body)

func _make_mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _make_emissive_mat(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat

func _place_lamp(parent: Node3D, pos: Vector3, yaw_deg: float) -> void:
	var lamp := _place(parent, "SM_Supermarket_StreetLamp_A", pos, yaw_deg, true)
	if lamp == null:
		return
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 6.8, 1.3)
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 5.2
	light.omni_range = 18.0
	lamp.add_child(light)

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and not _mesh_cache.has(mi.name):
			_mesh_cache[mi.name] = mi.mesh
	for c in node.get_children():
		_collect_meshes(c)

func _place(parent: Node3D, mesh_name: String, pos: Vector3, yaw_deg: float, add_collision: bool) -> Node3D:
	var mesh: Mesh = _mesh_cache.get(mesh_name)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	parent.add_child(mi)
	if add_collision:
		mi.create_trimesh_collision()
	return mi
