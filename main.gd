extends Node3D

const WORLD := preload("res://world.gd")
const CAR := preload("res://car.gd")
const MAP := preload("res://map.gd")
const WIND := preload("res://assets/audio/wind.wav")
const DISCOVERY := preload("res://assets/audio/discovery.wav")
var world: Node3D
var car: RigidBody3D
var camera: Camera3D
var speed_label: Label
var area_label: Label
var journey_label: Label
var map_panel: PanelContainer
var pause_panel: PanelContainer
var map_view: Control
var discovered: Array[String]=[]
var spawn_point: Vector3
var wind: AudioStreamPlayer
var chime: AudioStreamPlayer
var zoom := 24.0
var ui: Control
var quitting := false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit=false
	_inputs()
	_environment()
	world=WORLD.new()
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var spawn: Array=world.layout.spawn
	spawn_point=Vector3(spawn[0],world.height_at(spawn[0],spawn[1])+1.4,spawn[1])
	car=RigidBody3D.new()
	car.set_script(CAR)
	car.world=world
	car.process_mode=Node.PROCESS_MODE_PAUSABLE
	car.position=spawn_point
	car.rotation.y=0.8
	add_child(car)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=zoom
	camera.far=400
	camera.current=true
	add_child(camera)
	camera.position=spawn_point+Vector3(30,34,33)
	camera.look_at(spawn_point)
	wind=car._loop(WIND,-31)
	chime=AudioStreamPlayer.new()
	chime.stream=DISCOVERY
	chime.volume_db=-16
	add_child(chime)
	_ui()

func _process(delta: float) -> void:
	if not is_instance_valid(car) or get_tree().paused:
		return
	var target: Vector3=car.global_position+Vector3(0,0.5,0)+car.linear_velocity*0.22
	var offset := Vector3(30,34,33)
	camera.global_position=camera.global_position.lerp(target+offset,1-exp(-delta*5))
	camera.look_at(camera.global_position-offset)
	camera.size=lerpf(camera.size,zoom,1-exp(-delta*5))
	var speed := Vector2(car.linear_velocity.x,car.linear_velocity.z).length()*3.6
	speed_label.text="%02d  /  KM·H"%int(speed)
	if car.global_position.y < -6 or absf(car.global_position.x)>151 or absf(car.global_position.z)>131:
		car.reset_to_start(spawn_point)
	var region := "OPEN WASTELAND"
	for place in world.landmarks:
		var p := Vector2(place.position[0],place.position[1])
		if Vector2(car.global_position.x,car.global_position.z).distance_to(p)<22:
			region=place.name
			if not discovered.has(place.id):
				discovered.append(place.id)
				chime.play()
	area_label.text=region
	journey_label.text="FIELD NOTES   %02d / %02d PLACES"%[discovered.size(),world.landmarks.size()]
	map_view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset") and not get_tree().paused:
		car.reset_to_start(spawn_point)
	elif event.is_action_pressed("map"):
		map_panel.visible=not map_panel.visible
	elif event.is_action_pressed("pause"):
		if map_panel.visible:
			map_panel.hide()
		else:
			_pause(not get_tree().paused)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			zoom=clampf(zoom-2,18,55)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			zoom=clampf(zoom+2,18,55)

func _inputs() -> void:
	var bindings := {"accelerate":[KEY_W,KEY_UP],"reverse":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"handbrake":[KEY_SPACE],"reset":[KEY_R],"map":[KEY_M],"pause":[KEY_ESCAPE]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in bindings[action]:
			var key := InputEventKey.new()
			key.physical_keycode=code
			if not InputMap.action_has_event(action,key):
				InputMap.action_add_event(action,key)

func _environment() -> void:
	var node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("c8bcaa")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("aea2d5")
	env.ambient_light_energy=0.65
	env.tonemap_mode=Environment.TONE_MAPPER_ACES
	env.fog_enabled=true
	env.fog_light_color=Color("d0bba7")
	env.fog_density=0.0012
	env.ssao_enabled=true
	env.ssao_radius=1.6
	env.ssao_intensity=1.7
	env.ssao_light_affect=0.35
	node.environment=env
	add_child(node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-32,0)
	sun.light_color=Color("ffe6bc")
	sun.light_energy=1.05
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=130
	sun.shadow_bias=0.025
	add_child(sun)

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var top := VBoxContainer.new()
	top.position=Vector2(32,28)
	ui.add_child(top)
	top.add_child(_label("D U S T L I N E",23,Color("f0ecd5")))
	area_label=_label("DUSTLINE SERVICE",12,Color("e8dfbd"))
	top.add_child(area_label)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left=28
	footer.offset_right=-28
	footer.offset_top=-67
	footer.offset_bottom=-23
	footer.add_theme_stylebox_override("panel",_panel())
	ui.add_child(footer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",28)
	footer.add_child(row)
	speed_label=_label("00 / KM·H",19,Color("f1e7c5"))
	speed_label.custom_minimum_size.x=155
	row.add_child(speed_label)
	var controls := _label("WASD  DRIVE    SPACE  BRAKE    R  RECOVER    M  MAP    ESC  PAUSE",12,Color("d3d1be"))
	controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	controls.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	row.add_child(controls)
	journey_label=_label("",11,Color("bfbd9d"))
	journey_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	row.add_child(journey_label)
	map_panel=PanelContainer.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	map_panel.position=Vector2(-340,-270)
	map_panel.size=Vector2(680,540)
	map_panel.add_theme_stylebox_override("panel",_panel())
	ui.add_child(map_panel)
	var map_column := VBoxContainer.new()
	map_panel.add_child(map_column)
	map_column.add_child(_label("SURVEY MAP   /   M TO CLOSE",16,Color("e8dfbd")))
	map_view=MAP.new()
	map_view.world=world
	map_view.car=car
	map_view.journal=discovered
	map_view.custom_minimum_size=Vector2(640,470)
	map_column.add_child(map_view)
	map_panel.hide()
	pause_panel=PanelContainer.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.position=Vector2(-180,-160)
	pause_panel.size=Vector2(360,320)
	pause_panel.add_theme_stylebox_override("panel",_panel())
	ui.add_child(pause_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	pause_panel.add_child(column)
	column.add_child(_label("REST STOP",24,Color("e8dfbd")))
	var resume := Button.new()
	resume.text="Continue driving"
	resume.pressed.connect(func(): _pause(false))
	column.add_child(resume)
	column.add_child(_label("MASTER VOLUME",12,Color("d3d1be")))
	var volume := HSlider.new()
	volume.min_value=0
	volume.max_value=100
	volume.value=75
	AudioServer.set_bus_volume_db(0,linear_to_db(0.75))
	volume.value_changed.connect(func(value: float): AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value/100,0.0001))))
	column.add_child(volume)
	var quit_button := Button.new()
	quit_button.text="Quit"
	quit_button.pressed.connect(_quit)
	column.add_child(quit_button)
	pause_panel.hide()

func _pause(value: bool) -> void:
	get_tree().paused=value
	pause_panel.visible=value
	if value:
		pause_panel.get_child(0).get_child(1).grab_focus()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()

func _quit() -> void:
	if quitting:
		return
	quitting=true
	get_tree().paused=true
	for player in [car.engine_audio,car.gravel_audio,car.water_audio,car.impact_audio,wind,chime]:
		player.stop()
	# Let the audio thread release its active playback before closing the window.
	await get_tree().create_timer(0.15,true).timeout
	get_tree().quit()

func _label(words: String,size: int,color: Color) -> Label:
	var label := Label.new()
	label.text=words
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0.1,0.15,0.13,0.8))
	label.add_theme_constant_override("shadow_offset_y",2)
	return label

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.10,0.14,0.13,0.92)
	style.border_color=Color(0.65,0.66,0.5,0.45)
	style.set_border_width_all(1)
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=10
	style.content_margin_bottom=10
	return style
