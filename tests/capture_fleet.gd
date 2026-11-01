extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func shot(title: String) -> void:
	await frames(30)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/fleet-"+title+".png")==OK)
	print("FLEET_RENDER ",title)

func _run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.ui.hide()
	await frames(120)
	for index in scene.VEHICLES.SPECS.size():
		scene.switch_vehicle(index)
		scene.car.reset_to_start(Vector3(-180,scene.world.height_at(-180,30)+1.7,30))
		scene.car.reset_yaw=0
		await frames(100)
		scene.car.freeze=true
		scene.car.linear_velocity=Vector3.ZERO
		scene.car.reset_physics_interpolation()
		scene.camera.set_process(false)
		scene.camera.set_cull_mask_value(2,true)
		scene.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		scene.camera.size=8.3
		var target: Vector3=scene.car.global_position+Vector3.UP*1.0
		scene.camera.position=target+Vector3(-8,5.0,-10)
		scene.camera.look_at(target)
		await shot(scene.car.spec.id)
		scene.camera.set_mode(1)
		scene.camera._process(0)
		await shot(scene.car.spec.id+"-driver")
	scene.ui.show()
	scene._toggle_garage()
	await shot("garage")
	print("FLEET_CAPTURE: PASS")
	await scene._quit()
