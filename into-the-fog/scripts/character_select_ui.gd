extends CanvasLayer

@export var player_path: NodePath = NodePath("../Player")
@export var spawner_path: NodePath = NodePath("../EnemySpawner")
@export var audio_manager_path: NodePath = NodePath("../AudioManager")
@export var fog_manager_path: NodePath = NodePath("../FogManager")

func _ready() -> void:
	layer = 20
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.06, 0.72)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.09, 0.12, 0.94)
	style.border_color = Color(0.95, 0.62, 0.30, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "INTO THE FOG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.48))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Escolha seu personagem para iniciar"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.92, 0.90, 0.88))
	vbox.add_child(subtitle)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var btn_bolsonaro := _make_choice_button("BOLSONARO", "Adversários: Lula", Color(0.16, 0.45, 0.25))
	btn_bolsonaro.pressed.connect(func() -> void: _start_match("bolsonaro", "lula"))
	hbox.add_child(btn_bolsonaro)

	var btn_lula := _make_choice_button("LULA", "Adversários: Bolsonaro", Color(0.62, 0.16, 0.16))
	btn_lula.pressed.connect(func() -> void: _start_match("lula", "bolsonaro"))
	hbox.add_child(btn_lula)

func _make_choice_button(title_text: String, sub_text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 96)
	btn.text = "%s\n(%s)" % [title_text, sub_text]
	btn.add_theme_font_size_override("font_size", 18)

	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = accent.lightened(0.18)
	hover.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", hover)

	return btn

func _start_match(player_choice: String, enemy_choice: String) -> void:
	var player := get_node_or_null(player_path)
	if player != null and player.has_method("start_with_character"):
		player.call("start_with_character", player_choice)

	var spawner := get_node_or_null(spawner_path)
	if spawner != null and spawner.has_method("start_spawning"):
		spawner.call("start_spawning", enemy_choice)

	var audio_mgr := get_node_or_null(audio_manager_path)
	if audio_mgr != null and audio_mgr.has_method("start_match_audio"):
		audio_mgr.call("start_match_audio", player_choice)

	var fog_mgr := get_node_or_null(fog_manager_path)
	if fog_mgr != null and fog_mgr.has_method("start_fog_cycle"):
		fog_mgr.call("start_fog_cycle")

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
