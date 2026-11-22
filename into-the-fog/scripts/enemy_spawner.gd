extends Node3D

@export var max_alive_enemies: int = 4
@export var respawn_delay: float = 5.0

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")

var spawn_points: Array[Vector3] = [
	Vector3(-5.0, 1.3, 44.0),
	Vector3(5.0, 1.3, 48.0),
	Vector3(-2.0, 1.3, 54.0),
	Vector3(6.5, 1.3, 40.0),
	Vector3(-6.5, 1.3, 50.0),
]

var _spawn_index: int = 0
var _enemy_choice: String = "lula"
var _started: bool = false

func _ready() -> void:
	pass

func start_spawning(enemy_choice: String) -> void:
	if _started:
		return
	_started = true
	_enemy_choice = enemy_choice
	await get_tree().physics_frame
	for i in range(max_alive_enemies):
		_spawn_enemy()

func _spawn_enemy() -> void:
	var enemy := CharacterBody3D.new()
	enemy.name = "Enemy_%d" % (_spawn_index + 1)
	enemy.set_script(ENEMY_SCRIPT)
	enemy.set("character_choice", _enemy_choice)

	var pt := spawn_points[_spawn_index % spawn_points.size()]
	_spawn_index += 1
	enemy.position = pt + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	enemy.rotation_degrees.y = 180.0 # Olha em direção ao centro do mapa (-Z)
	add_child(enemy)

	enemy.connect("died", _on_enemy_died)

func _on_enemy_died(killer: Node3D) -> void:
	if killer != null and killer.name == "Player" and killer.has_method("register_kill"):
		killer.call("register_kill")

	await get_tree().create_timer(respawn_delay).timeout
	if is_inside_tree():
		_spawn_enemy()
