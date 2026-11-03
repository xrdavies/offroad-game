extends SceneTree

var failures: Array[String]=[]

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func settle_audio(car: RigidBody3D, speed: float, throttle: float) -> void:
	car.linear_velocity=-car.global_basis.z*speed
	for i in 180:
		car._update_audio(1.0/60,throttle,speed)

func _run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await frames(120)
	check(AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter,"Master limiter protects overlapping layers")
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/profiles.json"))
	check(profiles.size()==scene.VEHICLES.SPECS.size(),"Every car has an engine profile")
	var fingerprints: Array[String]=[]
	for index in scene.VEHICLES.SPECS.size():
		scene.switch_vehicle(index)
		var car: RigidBody3D=scene.car
		car.set_physics_process(false)
		car.freeze=true
		var id: String=car.spec.id
		for layer in ["idle","load"]:
			var path: String="res://assets/audio/engine_"+id+"_"+layer+".wav"
			var hash:=FileAccess.get_sha256(path)
			check(not fingerprints.has(hash),"Unique engine recording: "+path)
			fingerprints.append(hash)
		check(car.engine_audio.stream.get_length()>5.9 and car.engine_load_audio.stream.get_length()>5.9,"Both engine layers load: "+id)
		check(car.engine_audio.stream.loop_end>0 and car.engine_load_audio.stream.loop_end>0,"Engine layers loop: "+id)
		car.grounded_wheels=car.rays.size()
		car.contact_surfaces={"road":car.rays.size()}
		settle_audio(car,0,0)
		check(absf(car.audio_rpm-float(profiles[id].idle_rpm))<1,"Idle RPM: "+id)
		check(car.engine_audio.volume_linear>0.1,"Idle is audible: "+id)
		check(car.surface_audio.road.volume_linear==0,"No stationary tire hiss: "+id)
		settle_audio(car,10,1)
		var touring_rpm: float=car.audio_rpm
		var under_load: float=car.engine_load_audio.volume_linear
		check(under_load>0.05,"Loaded engine audible: "+id)
		settle_audio(car,10,0)
		check(car.engine_load_audio.volume_linear<under_load,"Lift-off reduces load: "+id)
		car.low_range=true
		car.audio_gear=0
		settle_audio(car,10,1)
		check(car.audio_rpm>touring_rpm or car.audio_gear>0,"Low range changes sound gearing: "+id)
		car.low_range=false
		settle_audio(car,-4,-1)
		check(car.engine_audio.pitch_scale>0 and car.engine_load_audio.pitch_scale>0,"Reverse has positive pitch: "+id)
		check(car.surface_audio.road.volume_linear>0.02,"Reverse rolling audible: "+id)
		for kind in scene.VEHICLES.SURFACES:
			car.contact_surfaces={kind:car.rays.size()}
			settle_audio(car,8,0.4)
			for other in car.surface_audio:
				var level: float=car.surface_audio[other].volume_linear
				check(level>0.05 if other==kind else level<0.0001,"Only contacted material audible: "+id+"/"+kind+"/"+other)
		car.contact_surfaces={"road":car.rays.size()/2,"water":car.rays.size()/2}
		car._update_audio(1.0/60,0.4,8)
		check(car.surface_audio.ice.volume_linear>0 and car.surface_audio.water.volume_linear>0,"Terrain transition crossfades: "+id)
		settle_audio(car,8,0.4)
		check(car.surface_audio.road.volume_linear>0.05 and car.surface_audio.water.volume_linear>0.05,"Mixed wheel contacts blend: "+id)
		car.grounded_wheels=0
		car.contact_surfaces.clear()
		settle_audio(car,15,1)
		for player in car.surface_audio.values():
			check(not player.playing and player.volume_linear==0,"Airborne tires silent: "+id)
		check(car.audio_rpm>float(profiles[id].redline)*0.8,"Airborne revs respond to throttle: "+id)
		car.reset_to_start()
		check(car.audio_gear==0 and car.shift_time==0,"Recovery clears audio gears: "+id)
		car.stop_audio()
		for player in car.find_children("*","AudioStreamPlayer",true,false):
			check(not player.playing,"All vehicle sounds stop: "+id)
	# Exercise the real suspension path, not only the mixer with supplied contacts.
	scene.switch_vehicle(0)
	for zone in scene.world.REGIONS.ZONES:
		var p: Vector2=zone.center
		scene.car.reset_to_start(Vector3(p.x,scene.world.height_at(p.x,p.y)+2,p.y))
		await frames(140)
		check(scene.car.contact_surfaces.has(zone.surface),"Actual wheel material: "+zone.id)
	# Map travel and quitting must release all new layers, including a paused car.
	check(await scene.switch_map(1),"Travel with new audio layers")
	await frames(140)
	check(scene.car.engine_audio.playing,"New vehicle engine starts after travel")
	scene._pause(true)
	await process_frame
	check(scene.car.engine_audio.stream_paused,"Pause suspends engine playback")
	scene._pause(false)
	await process_frame
	check(not scene.car.engine_audio.stream_paused,"Resume restores playback")
	print("AUDIO: ","PASS" if failures.is_empty() else failures)
	# Audio uses wall time, even with --fixed-fps accelerated physics.
	scene.set_process(false)
	paused=true
	for player in scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	OS.delay_msec(200)
	scene.queue_free()
	await create_timer(0.2).timeout
	OS.delay_msec(100)
	quit(0 if failures.is_empty() else 1)
