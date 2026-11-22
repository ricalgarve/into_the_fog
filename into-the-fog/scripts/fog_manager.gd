extends Node

signal fog_mode_changed(active: bool)

@export var fog_interval: float = 60.0
@export var fog_duration: float = 30.0
@export var transition_speed: float = 1.6

@export var normal_fog_density: float = 0.015
@export var heavy_fog_density: float = 0.16
@export var normal_fog_sky_affect: float = 0.55
@export var heavy_fog_sky_affect: float = 0.94
@export var normal_fog_color: Color = Color(0.76, 0.48, 0.36, 1.0)
@export var heavy_fog_color: Color = Color(0.54, 0.52, 0.54, 1.0)
@export var normal_fog_energy: float = 1.0
@export var heavy_fog_energy: float = 0.65

var is_fog_active: bool = false
var _cycle_started: bool = false
var _phase_timer: float = 0.0
var _env: Environment

func _ready() -> void:
	add_to_group("fog_manager")
	var world_env := get_tree().current_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env != null:
		_env = world_env.environment
		if _env != null:
			normal_fog_density = _env.fog_density
			normal_fog_sky_affect = _env.fog_sky_affect
			normal_fog_color = _env.fog_light_color
			normal_fog_energy = _env.fog_light_energy

func start_fog_cycle() -> void:
	if _cycle_started:
		return
	_cycle_started = true
	is_fog_active = false
	_phase_timer = fog_interval

func get_time_remaining() -> float:
	return maxf(0.0, _phase_timer)

func _process(delta: float) -> void:
	if _cycle_started:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			is_fog_active = not is_fog_active
			_phase_timer = fog_duration if is_fog_active else fog_interval
			fog_mode_changed.emit(is_fog_active)

	if _env != null:
		var target_density := heavy_fog_density if is_fog_active else normal_fog_density
		var target_sky := heavy_fog_sky_affect if is_fog_active else normal_fog_sky_affect
		var target_color := heavy_fog_color if is_fog_active else normal_fog_color
		var target_energy := heavy_fog_energy if is_fog_active else normal_fog_energy
		var t := clampf(delta * transition_speed, 0.0, 1.0)

		_env.fog_density = lerpf(_env.fog_density, target_density, t)
		_env.fog_sky_affect = lerpf(_env.fog_sky_affect, target_sky, t)
		_env.fog_light_color = _env.fog_light_color.lerp(target_color, t)
		_env.fog_light_energy = lerpf(_env.fog_light_energy, target_energy, t)
