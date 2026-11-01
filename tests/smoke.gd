extends SceneTree

var failures: Array[String]=[]

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool,description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	_check_spatial_batches()
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await _frames(150)
	var car: RigidBody3D=scene.car
	_check(car.grounded_wheels==4,"All suspension rays must settle on the road")
	_check(car.linear_velocity.length()<0.8,"Car must remain stable at rest")
	_check(car.global_position.y>scene.world.height_at(car.position.x,car.position.z),"Car must stay above terrain")
	_check(scene.world.models.size()>=10,"World must instantiate the authored asset library")
	_check(car.engine_audio.stream.get_length()>1,"Engine resource must load after import")
	_check(car.engine_audio.stream.loop_end>0,"Engine loop must include samples")
	for center in scene.world.SCRAP_CENTERS:
		var height: float=scene.world.height_at(center.x,center.y)
		var point := Vector3(center.x,height,center.y)
		var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*15,point-Vector3.UP*3)
		var hit: Dictionary=scene.world.get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not hit.is_empty(),"Scrap heaps must have terrain collision")
		if not hit.is_empty():
			_check(absf(hit.position.y-height)<0.15,"Heap collision must match its visible supporting terrain")
	var start: Vector3=car.position
	Input.action_press("accelerate")
	await _frames(90)
	var speed := car.linear_velocity.length()
	_check(speed>4,"Throttle must accelerate the car")
	_check(car.position.distance_to(start)>3,"Throttle must move through the map")
	Input.action_press("right")
	await _frames(30)
	_check(car.angular_velocity.y<0,"Right steering must rotate clockwise while driving forward")
	Input.action_release("right")
	Input.action_release("accelerate")
	Input.action_press("handbrake")
	await _frames(90)
	_check(car.linear_velocity.length()<speed*0.4,"Handbrake must remove forward speed")
	Input.action_release("handbrake")
	car.reset_to_start(scene.spawn_point)
	await _frames(150)
	_check(Vector2(car.position.x-start.x,car.position.z-start.z).length()<1,"Recovery must restore spawn without stale velocity")
	_check(car.grounded_wheels==4,"Recovery must restore wheel contact")
	car.reset_to_start(scene.spawn_point+Vector3.UP*30)
	await _frames(2)
	Input.action_press("accelerate")
	await _frames(25)
	Input.action_release("accelerate")
	_check(car.grounded_wheels==0,"Airborne probe must be above all surfaces")
	_check(Vector2(car.linear_velocity.x,car.linear_velocity.z).length()<0.1,"Engine must not accelerate the car in mid-air")
	var x: float=scene.world.river_x(0)
	var marsh := Vector3(scene.world.river_x(-15)+9,1.1,-15)
	_check(scene.world.surface_at(marsh)=="water","Widened shallows must use the same water boundary as the terrain")
	car.reset_to_start(Vector3(x,scene.world.height_at(x,0)+1.4,0))
	await _frames(150)
	_check(car.surface_kind=="water","Ford must use water drag and sound")
	_check(car.grounded_wheels>1,"Shallow water must have a drivable bed")
	var before: Vector3=car.position
	scene._pause(true)
	await _frames(20)
	_check(car.position.distance_to(before)<0.01,"Pause must stop vehicle physics")
	scene._pause(false)
	for crossing in [[-57.0,-0.34],[36.0,0.04]]:
		var center := Vector3(scene.world.river_x(crossing[0]),2.36,crossing[0])
		var direction := Basis(Vector3.UP,crossing[1])*Vector3.RIGHT
		var entry := center-direction*25
		entry.y=scene.world.height_at(entry.x,entry.z)+1.4
		car.reset_to_start(entry)
		car.reset_yaw=-PI/2+crossing[1]
		await _frames(120)
		Input.action_press("accelerate")
		await _frames(330)
		Input.action_release("accelerate")
		_check((car.position-center).dot(direction)>19,"Both bridges must be traversable from bank to bank")
		_check(car.position.y>1,"Bridge crossing must not drop the car into the river bed")
	for place in scene.world.landmarks:
		var p:=Vector2(place.position[0],place.position[1])
		_check(absf(p.x)<scene.world.SIZE.x and absf(p.y)<scene.world.SIZE.y,"Landmark must be within map boundaries")
	print("SMOKE: ","PASS" if failures.is_empty() else failures)
	# Audio runs on wall time even when the test uses --fixed-fps.
	scene.set_process(false)
	paused=true
	for player in scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	OS.delay_msec(200)
	scene.queue_free()
	await create_timer(0.15).timeout
	OS.delay_msec(100)
	quit(0 if failures.is_empty() else 1)

func _check_spatial_batches() -> void:
	var world := Node3D.new()
	world.set_script(load("res://world.gd"))
	var transforms: Array[Transform3D]=[]
	var colors: Array[Color]=[Color.RED,Color.GREEN,Color.BLUE,Color.WHITE,Color.YELLOW]
	for x in [-32.1,-0.1,0.1,32.1,0.5]:
		transforms.append(Transform3D(Basis.IDENTITY,Vector3(x,0,0)))
	world._multimesh(transforms,BoxMesh.new(),Color.WHITE,false,colors)
	_check(world.get_child_count()==4,"Nearby instances must share a spatial batch on both sides of zero")
	var seen := 0
	for batch in world.get_children():
		seen+=batch.multimesh.instance_count
		# Godot's headless dummy renderer does not retain instance transforms/colors.
		if DisplayServer.get_name()=="headless":
			continue
		for i in batch.multimesh.instance_count:
			var transform: Transform3D=batch.multimesh.get_instance_transform(i)
			var index := -1
			for candidate in transforms.size():
				if transforms[candidate].is_equal_approx(transform):
					index=candidate
			_check(index>=0,"Spatial batches must preserve transforms across positive and negative cells")
			if index>=0:
				_check(batch.multimesh.get_instance_color(i).is_equal_approx(colors[index].srgb_to_linear()),"Spatial batches must keep each instance's assigned color")
	_check(seen==transforms.size(),"Spatial batches must retain every instance")
	world.free()
