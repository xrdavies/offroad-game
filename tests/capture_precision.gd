extends SceneTree

const IDS := ["wrangler","eq246"]
const OUTPUT := "res://build/precision-review"

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		if count>=50 and _i%25==24:
			print("PRECISION_PROGRESS ",_i+1,"/",count)

func index_for(scene: Node3D, id: String) -> int:
	for i in scene.VEHICLES.SPECS.size():
		if scene.VEHICLES.SPECS[i].id==id:
			return i
	return -1

func shot(scene: Node3D, id: String, view: String) -> void:
	await RenderingServer.frame_post_draw
	var path:=OUTPUT+"/"+id+"-"+view+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	print("PRECISION_RENDER ",path)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.ui.hide()
	await frames(100)
	for id in IDS:
		scene.switch_vehicle(index_for(scene,id))
		await frames(25)
		var car: RigidBody3D=scene.car
		car.reset_to_start(Vector3(-180,scene.world.height_at(-180,30)+1.7,30))
		car.reset_yaw=0.0
		await frames(45)
		car.freeze=true
		car.linear_velocity=Vector3.ZERO
		car.angular_velocity=Vector3.ZERO
		car.reset_physics_interpolation()
		# Orthographic three-quarter exterior view.
		scene.camera.set_process(false)
		scene.camera.set_cull_mask_value(2,true)
		scene.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		scene.camera.size=7.4
		var target: Vector3=car.global_position+Vector3.UP*1.0
		scene.camera.position=target+Vector3(-7,4.2,-9)
		scene.camera.look_at(target)
		await frames(10)
		await shot(scene,id,"exterior")
		# Driver eye view with the vehicle-specific dashboard and steering wheel.
		scene.camera.set_mode(1)
		scene.camera.set_process(false)
		scene.camera.look=Vector2.ZERO
		scene.camera._process(0)
		await frames(10)
		await shot(scene,id,"cockpit")
	print("PRECISION_CAPTURE: PASS")
	scene.set_process(false)
	paused=true
	for player in scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	scene.queue_free()
	await create_timer(0.2).timeout
	quit()
