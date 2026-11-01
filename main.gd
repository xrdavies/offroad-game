extends Node3D

const WORLD := preload("res://world.gd")
const CAR := preload("res://car.gd")
const CAMERA := preload("res://driving_camera.gd")
const VEHICLES := preload("res://vehicles.gd")
const RECORDER := preload("res://recorder.gd")
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
var vehicle_index := 0
var garage_panel: PanelContainer
var driving_label: Label
var recording_label: Label
var toast_label: Label
var toast_time := 0.0
var recorder: Node
var film_view: SubViewport
var film_camera: Camera3D
var film_mode := 1
var film_option: OptionButton
var hud_hidden := false
var waypoint := Vector2.INF
const FILM_MODES := ["DRIVER VIEW", "CHASE", "SIDE TRACK", "DRONE", "DIRECTOR"]

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
	camera=CAMERA.new()
	camera.car=car
	camera.world=world
	add_child(camera)
	wind=car._loop(WIND,-31)
	wind.reparent(self)
	chime=AudioStreamPlayer.new()
	chime.stream=DISCOVERY
	chime.volume_db=-16
	add_child(chime)
	_ui()
	_setup_recording()

func _process(delta: float) -> void:
	if not is_instance_valid(car):
		return
	camera.zoom=zoom
	var speed := Vector2(car.linear_velocity.x,car.linear_velocity.z).length()*3.6
	speed_label.text="%02d  /  KM·H"%int(speed)
	if car.global_position.y < -6 or absf(car.global_position.x)>world.SIZE.x+1 or absf(car.global_position.z)>world.SIZE.y+1:
		car.reset_to_start(spawn_point)
	var region: String=world.REGIONS.zone_at(Vector2(car.position.x,car.position.z)).get("name","OPEN WASTELAND")
	for place in world.landmarks:
		var p := Vector2(place.position[0],place.position[1])
		if Vector2(car.global_position.x,car.global_position.z).distance_to(p)<22:
			region=place.name
			if not discovered.has(place.id):
				discovered.append(place.id)
				chime.play()
	area_label.text=region
	journey_label.text="FIELD NOTES   %02d / %02d PLACES"%[discovered.size(),world.landmarks.size()]
	driving_label.text="%s   ·   %s   ·   %s   ·   %s"%[car.spec.name,car.surface_kind.to_upper(),"4L / CRAWL" if car.low_range else "4H / TOUR",camera.MODES[camera.mode]]
	if waypoint!=Vector2.INF:
		driving_label.text+="   ·   WAYPOINT %d m"%Vector2(car.position.x,car.position.z).distance_to(waypoint)
	toast_time=maxf(0,toast_time-delta)
	toast_label.visible=toast_time>0 and not hud_hidden
	recording_label.text=recorder.status_text()+"   |   FILM: "+FILM_MODES[film_mode]
	map_view.waypoint=waypoint
	map_view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset") and not get_tree().paused:
		car.reset_to_start(spawn_point)
	elif event.is_action_pressed("map"):
		map_panel.visible=not map_panel.visible
	elif event.is_action_pressed("camera") and not get_tree().paused:
		camera.set_mode(camera.mode+1)
	elif event.is_action_pressed("low_range") and not get_tree().paused:
		car.low_range=not car.low_range
	elif event.is_action_pressed("garage"):
		_toggle_garage()
	elif event.is_action_pressed("record"):
		if recorder.active:
			recorder.stop_recording()
		elif not get_tree().paused:
			recorder.start_recording(film_view if film_mode!=0 else get_viewport())
	elif event.is_action_pressed("film_camera"):
		_set_film_mode((film_mode+1)%FILM_MODES.size())
	elif event.is_action_pressed("recordings"):
		OS.shell_open(recorder.output_directory())
	elif event.is_action_pressed("hide_hud"):
		hud_hidden=not hud_hidden
		for child in ui.get_children():
			if child!=pause_panel and child!=garage_panel and child!=map_panel:
				child.visible=not hud_hidden
	elif event.is_action_pressed("pause"):
		if garage_panel.visible:
			garage_panel.hide()
			_pause(false)
			return
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
	var bindings := {"accelerate":[KEY_W,KEY_UP],"reverse":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"handbrake":[KEY_SPACE],"reset":[KEY_R],"map":[KEY_M],"pause":[KEY_ESCAPE],"camera":[KEY_C],"low_range":[KEY_L],"garage":[KEY_V],"record":[KEY_F9],"film_camera":[KEY_F6],"recordings":[KEY_F10],"hide_hud":[KEY_H]}
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
	env.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("7894a1")
	sky_material.sky_horizon_color=Color("d8ccae")
	sky_material.ground_horizon_color=Color("d8ccae")
	sky_material.ground_bottom_color=Color("807567")
	sky.sky_material=sky_material
	env.sky=sky
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
	var top_panel := PanelContainer.new()
	top_panel.position=Vector2(28,22)
	top_panel.add_theme_stylebox_override("panel",_panel())
	ui.add_child(top_panel)
	var top := VBoxContainer.new()
	top_panel.add_child(top)
	top.add_child(_label("O F F   R O A D   R I D E R",23,Color("f0ecd5")))
	area_label=_label("OFF ROAD RIDER SERVICE",12,Color("e8dfbd"))
	top.add_child(area_label)
	driving_label=_label("",12,Color("f2e7c3"))
	top.add_child(driving_label)
	recording_label=_label("F9 RECORD  ·  F6 FILM CAMERA  ·  F10 CLIPS",12,Color("e9c58e"))
	top.add_child(recording_label)
	toast_label=_label("",15,Color("fff0c8"))
	top.add_child(toast_label)
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
	var controls := _label("WASD DRIVE   SPACE BRAKE   C VIEW   L LOW   V VEHICLE   M MAP   ESC MENU",12,Color("d3d1be"))
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
	map_column.add_child(_label("SURVEY MAP   /   CLICK TO SET WAYPOINT   /   M TO CLOSE",16,Color("e8dfbd")))
	map_view=MAP.new()
	map_view.world=world
	map_view.car=car
	map_view.journal=discovered
	map_view.destination_selected.connect(func(p: Vector2): waypoint=p; _toast("Waypoint set. Follow the dashed trails."))
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
	column.add_child(_label("C View · Right-drag to look · L Low range
V Vehicle · R Recover · H Hide HUD
F9 Start / stop video · F10 Open clips",13,Color("e8dfbd")))
	film_option=OptionButton.new()
	for option in FILM_MODES:
		film_option.add_item("Film camera: "+option)
	film_option.select(film_mode)
	film_option.item_selected.connect(_set_film_mode)
	column.add_child(film_option)
	column.add_child(quit_button)
	_build_garage()
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
	if recorder.active:
		recorder.stop_recording()
	while recorder.finishing:
		await get_tree().process_frame
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

func _toast(message: String) -> void:
	toast_label.text=message
	toast_time=6

func _toggle_garage() -> void:
	if garage_panel.visible:
		garage_panel.hide()
		_pause(false)
		return
	if car.linear_velocity.length()>1:
		_toast("Stop the vehicle before changing vehicles.")
		return
	_pause(true)
	pause_panel.hide()
	garage_panel.show()

func _build_garage() -> void:
	garage_panel=PanelContainer.new()
	garage_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	garage_panel.position=Vector2(-300,-220)
	garage_panel.size=Vector2(600,440)
	garage_panel.add_theme_stylebox_override("panel",_panel())
	ui.add_child(garage_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	garage_panel.add_child(column)
	column.add_child(_label("EXPEDITION VEHICLES",24,Color("e8dfbd")))
	for i in VEHICLES.SPECS.size():
		var spec: Dictionary=VEHICLES.SPECS[i]
		var button := Button.new()
		button.text="%s   ·   %d kg
%s"%[spec.name,spec.mass,spec.description]
		button.custom_minimum_size.y=64
		button.pressed.connect(func(): switch_vehicle(i))
		column.add_child(button)
	var close := Button.new()
	close.text="Back to driving  /  V"
	close.pressed.connect(_toggle_garage)
	column.add_child(close)
	garage_panel.hide()

func switch_vehicle(index: int) -> void:
	if index<0 or index>=VEHICLES.SPECS.size():
		return
	var position_before := car.global_position
	var yaw_before := car.rotation.y
	var mode_before: int=camera.mode
	car.free()
	car=RigidBody3D.new()
	car.set_script(CAR)
	car.vehicle_index=index
	vehicle_index=index
	car.world=world
	car.process_mode=Node.PROCESS_MODE_PAUSABLE
	car.position=Vector3(position_before.x,maxf(position_before.y,world.height_at(position_before.x,position_before.z)+1.6),position_before.z)
	car.rotation.y=yaw_before
	add_child(car)
	car.reset_physics_interpolation()
	camera.car=car
	camera.set_mode(mode_before)
	film_camera.car=car
	film_camera.snap=true
	map_view.car=car
	garage_panel.hide()
	_pause(false)
	_toast(car.spec.name+" ready. L switches low-range gearing.")

func _setup_recording() -> void:
	film_view=SubViewport.new()
	film_view.size=Vector2i(1280,720)
	film_view.world_3d=get_viewport().world_3d
	film_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	film_view.msaa_3d=Viewport.MSAA_2X
	add_child(film_view)
	film_camera=CAMERA.new()
	film_camera.car=car
	film_camera.world=world
	film_camera.allow_look=false
	film_camera.mode=2
	film_camera.set_process(false)
	film_view.add_child(film_camera)
	recorder=RECORDER.new()
	add_child(recorder)
	recorder.message.connect(_toast)
	recorder.recording_changed.connect(func(recording: bool):
		film_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if recording and film_mode!=0 else SubViewport.UPDATE_DISABLED
		film_camera.set_process(recording and film_mode!=0))

func _set_film_mode(value: int) -> void:
	film_mode=value
	film_option.select(value)
	film_camera.director=value==4
	film_camera.set_mode([camera.mode,2,3,4,2][value])
	if recorder.active:
		recorder.source=film_view if value!=0 else get_viewport()
		film_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value!=0 else SubViewport.UPDATE_DISABLED
		film_camera.set_process(value!=0)
	_toast("Film camera: "+FILM_MODES[value])
