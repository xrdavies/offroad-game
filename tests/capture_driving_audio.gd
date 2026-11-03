extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output:="res://build/audio-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.ui.hide()
	scene.camera.set_mode(2)
	await create_timer(2).timeout
	var capture:=AudioEffectRecord.new()
	capture.format=AudioStreamWAV.FORMAT_16_BITS
	var effect_index:=AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,capture)
	var manifest: Array=[]
	for index in scene.VEHICLES.SPECS.size():
		scene.switch_vehicle(index)
		var car: RigidBody3D=scene.car
		car.reset_to_start(Vector3(-180,scene.world.height_at(-180,30)+1.7,30))
		car.reset_yaw=0
		await create_timer(2).timeout
		capture.set_recording_active(true)
		await create_timer(1.5).timeout
		Input.action_press("accelerate")
		await create_timer(5.0).timeout
		var peak_kmh:=car.linear_velocity.length()*3.6
		Input.action_release("accelerate")
		await create_timer(1.5).timeout
		Input.action_press("handbrake")
		await create_timer(1.5).timeout
		Input.action_release("handbrake")
		capture.set_recording_active(false)
		var recording:=capture.get_recording()
		assert(recording!=null and recording.get_length()>9,"Audio driver must provide real samples")
		var path: String=output+"/drive_"+car.spec.id+".wav"
		assert(recording.save_to_wav(ProjectSettings.globalize_path(path))==OK)
		assert(peak_kmh>25,"Capture must include driving at speed")
		manifest.append({"vehicle":car.spec.id,"file":path.get_file(),"seconds":recording.get_length(),"peak_kmh":peak_kmh})
		print("AUDIO_CAPTURE ",car.spec.id," peak_kmh=",peak_kmh," duration=",recording.get_length())
	AudioServer.remove_bus_effect(0,effect_index)
	var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  "))
	file.close()
	print("AUDIO_CAPTURE: PASS")
	await scene._quit()
