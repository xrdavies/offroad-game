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

func _run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await frames(100)
	check(scene.VEHICLES.SPECS.size()==10,"Ten vehicles must be selectable")
	var ids: Array=[]
	for spec in scene.VEHICLES.SPECS:
		ids.append(spec.id)
		check(ResourceLoader.exists("res://assets/models/"+spec.id+"_body.tscn"),"Vehicle model must exist: "+spec.id)
	check(ids==["scout","ridge","pickup","hauler","wrangler","unimog","f150","hilux","eq246","wc62"],"Retain original IDs and append all six references")
	check(scene.WORLD.MAPS.SPECS.size()>=3,"At least three maps")
	scene.switch_vehicle(8)
	scene.camera.set_mode(1)
	scene.discovered.append("test_note")
	scene.waypoint=Vector2(123,234)
	var old_world: Node3D=scene.world
	check(not await scene.switch_map(-1),"Invalid map must be rejected")
	check(scene.world==old_world,"Invalid selection must preserve world")
	scene.recorder.finishing=true
	check(not await scene.switch_map(1),"Do not destroy a world while a recording is finalizing")
	scene.recorder.finishing=false
	for index in [1,2,0]:
		check(await scene.switch_map(index),"Map switch must finish")
		await frames(120)
		var world: Node3D=scene.world
		check(world.map_index==index and world.SIZE==Vector2(720,600),"Map identity and bounds")
		check(scene.car.spec.id=="eq246" and scene.camera.mode==1,"Travel retains vehicle and camera")
		check(scene.camera.world==world and scene.film_camera.world==world and scene.map_view.world==world,"All camera and navigation references must follow the new world")
		check(scene.car.grounded_wheels==6,"All six wheels settle after travel")
		check(not paused and not scene.changing_map and not scene.loading_label.visible,"Travel must restore play state")
		if index!=0:
			check(not scene.discovered.has("test_note") and scene.waypoint==Vector2.INF,"Map notes and destinations must be isolated")
		for zone in world.REGIONS.ZONES:
			var p: Vector2=zone.center+Vector2(2,-2)
			var y: float=world.height_at(p.x,p.y)
			var at := Vector3(p.x,y+0.5,p.y)
			check(world.surface_at(at)==zone.surface,"Surface: "+world.map_spec.id+"/"+zone.id)
			var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*10,at-Vector3.UP*3)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty(),"Region has physical ground: "+zone.id)
			if not hit.is_empty():
				check(absf(hit.position.y-y)<0.25,"Rendered terrain agrees with collision: "+zone.id)
		for trail in world.REGIONS.TRAILS:
			for point in trail:
				check(absf(point.x)<world.SIZE.x-10 and absf(point.y)<world.SIZE.y-10,"Routes stay within map boundaries")
		for lake in world.REGIONS.lakes:
			var p: Vector2=lake.center
			check(world.surface_at(Vector3(p.x,1,p.y))==("ice" if lake.frozen else "water"),"Lake material: "+lake.name)
		if index==1:
			check(world.height_at(-690,0)<world.WATER_LEVEL,"Sea has a submerged bed")
			check(world.surface_at(Vector3(-475,80,80))=="sand","Coast has a sandy shore")
		if index==2:
			# Drive on the physical ice sheet, beyond the startup garage.
			scene.car.reset_to_start(Vector3(330,2.7,-20))
			await frames(120)
			check(scene.car.surface_kind=="ice" and scene.car.grounded_wheels==6,"Ice supports the truck and applies low grip")
			var start: Vector3=scene.car.position
			Input.action_press("accelerate")
			await frames(90)
			Input.action_release("accelerate")
			check(scene.car.position.distance_to(start)>3,"Truck can drive across ice")
		if index==0:
			var center := Vector2(-490,-340)
			var at := Vector3(center.x,world.height_at(center.x,center.y),center.y)
			var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*5,at-Vector3.UP)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.position.y>at.y+0.29,"Rock course steps must have raised collision")
			scene.car.reset_to_start(Vector3(center.x-31,world.height_at(center.x-31,center.y)+1.7,center.y))
			scene.car.reset_yaw=-PI/2
			scene.car.low_range=true
			await frames(120)
			var start: Vector3=scene.car.position
			Input.action_press("accelerate")
			await frames(240)
			Input.action_release("accelerate")
			check(scene.car.position.x-start.x>12,"Six-wheel truck must climb the rock course in low range")
			check(scene.car.global_basis.y.dot(Vector3.UP)>0.75,"Truck remains upright through the rock course")
	check(scene.discovered.has("test_note") and scene.waypoint==Vector2(123,234),"Returning restores notes and destination")
	scene._show_destinations()
	check(scene.destinations_panel.visible and paused,"Map picker pauses driving")
	# Exercise the same-map UI button without rebuilding or losing state.
	scene.destinations_panel.get_child(0).get_child(1).pressed.emit()
	await process_frame
	check(not paused and not scene.destinations_panel.visible,"Map choice returns to driving")
	print("MAPS: ","PASS" if failures.is_empty() else failures)
	scene.set_process(false)
	paused=true
	for player in scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	OS.delay_msec(200)
	scene.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
