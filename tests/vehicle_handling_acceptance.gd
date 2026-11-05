extends SceneTree

const VEHICLES := preload("res://vehicles.gd")
const CAR := preload("res://car.gd")
var failures: Array[String]=[]
var report: Array[Dictionary]=[]
var stage: Node3D
var ground: StaticBody3D

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func box(size: Vector3, at: Vector3, parent: Node3D) -> StaticBody3D:
	var body:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var mesh:=BoxShape3D.new()
	mesh.size=size
	shape.shape=mesh
	body.add_child(shape)
	body.position=at
	parent.add_child(body)
	return body

func reset(car: RigidBody3D, at:=Vector3(0,1.8,0)) -> void:
	car.autopilot_input=Vector2.ZERO
	car.reset_to_start(at)
	car.reset_yaw=0
	await frames(150)

func turn(car: RigidBody3D, direction: float) -> Dictionary:
	await reset(car)
	var samples:=0
	var radius_sum:=0.0
	var rear_sum:=0.0
	var front_sum:=0.0
	var yaw_sum:=0.0
	var speed_sum:=0.0
	var contact_frames:=0
	var yaw_direction_ok:=true
	for tick in 4200:
		var speed: float=car.linear_velocity.dot(-car.global_basis.z)
		car.autopilot_input=Vector2(direction,clampf(0.06+(1.5-speed)*0.45,-0.3,0.5))
		await physics_frame
		if tick<300:
			continue
		var yaw: float=car.angular_velocity.y
		var velocity:=Vector3(car.linear_velocity.x,0,car.linear_velocity.z)
		if absf(yaw)>0.001:
			var com: Vector3=car.global_transform*car.center_of_mass
			var center:=com+Vector3(velocity.z,0,-velocity.x)/yaw
			var rear_z: float=(float(car.spec.axles[1])+float(car.spec.axles[-1]))*0.5
			var rear: Vector3=car.global_transform*Vector3(0,0,rear_z)
			var outer: Vector3=car.wheels[0 if direction>0 else 1].global_position
			radius_sum+=velocity.length()/absf(yaw)
			rear_sum+=Vector2(rear.x-center.x,rear.z-center.z).length()
			front_sum+=Vector2(outer.x-center.x,outer.z-center.z).length()
			speed_sum+=velocity.length()*3.6
			yaw_sum+=absf(yaw)/60.0
			yaw_direction_ok=yaw_direction_ok and yaw*direction<0
			samples+=1
		if car.grounded_wheels==car.rays.size(): contact_frames+=1
		if yaw_sum>=TAU: break
	check(samples>100 and yaw_sum>=TAU,"Complete low-speed circle: "+car.spec.id)
	check(yaw_direction_ok,"Wheel forces turn in the commanded direction: "+car.spec.id)
	var theoretical: float=car.wheelbase/tan(car.max_steer_angle)
	var measured: float=rear_sum/maxi(samples,1)
	check(absf(measured/theoretical-1.0)<0.25,"Rear-group radius within 25% of steering geometry: "+car.spec.id)
	check(float(contact_frames)/maxi(samples,1)>0.99,"Full wheel contact throughout steady circle: "+car.spec.id)
	return {"direction":direction,"com_radius_m":radius_sum/maxi(samples,1),"rear_group_radius_m":measured,"outer_front_wheel_center_radius_m":front_sum/maxi(samples,1),"ideal_rear_group_radius_m":theoretical,"speed_kmh":speed_sum/maxi(samples,1),"circle_radians":yaw_sum}

func _run() -> void:
	for action in ["accelerate","reverse","left","right","handbrake"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	stage=Node3D.new()
	root.add_child(stage)
	ground=box(Vector3(2000,1,2000),Vector3(0,-0.5,0),stage)
	for index in VEHICLES.SPECS.size():
		var car:=RigidBody3D.new()
		car.set_script(CAR)
		car.vehicle_index=index
		car.position=Vector3(0,1.8,0)
		stage.add_child(car)
		car.autopilot_enabled=true
		await frames(150)
		var row: Dictionary={"id":car.spec.id,"turns":[]}
		check(car.grounded_wheels==car.rays.size(),"Initial stable contact: "+car.spec.id)
		if car.spec.axles.size()==3:
			var tread_radius:=0.0
			var wheel_mesh: Mesh=car.wheels[0].get_child(0).get_node("Model").mesh
			for vertex in wheel_mesh.get_faces():
				tread_radius=maxf(tread_radius,Vector2(vertex.y,vertex.z).length()*car.radius/0.48)
			# Rear axles do not steer; vertical suspension travel can only increase their centre distance.
			row.minimum_rear_tread_gap_m=float(car.spec.axles[2])-float(car.spec.axles[1])-2*tread_radius
			check(row.minimum_rear_tread_gap_m>0.05,"Rear tires remain separated at every spin/travel position: "+car.spec.id)
		for direction in [-1.0,1.0]:
			row.turns.append(await turn(car,direction))
		check(absf(row.turns[0].rear_group_radius_m-row.turns[1].rear_group_radius_m)<0.1,"Left/right circle symmetry: "+car.spec.id)
		await reset(car)
		car.current_steer_angle=car.max_steer_angle
		check(absf(car.wheel_steer_angle(1))>absf(car.wheel_steer_angle(0)),"Inner wheel steers farther: "+car.spec.id)
		# Collision rays cover the visible upper box and tire side, not just shape counts.
		if car.spec.id in ["unimog","eq246"]:
			var z: float=(car.spec.seat.z+1.02+car.spec.length/2)*0.5
			var a: Vector3=car.global_transform*Vector3(-4,2.2,z)
			var b: Vector3=car.global_transform*Vector3(4,2.2,z)
			var hit:=stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b))
			check(hit.get("collider")==car,"Upper cargo actually collides: "+car.spec.id)
		var wheel: Vector3=car.wheels[0].global_position
		var tire_hit:=stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(wheel-Vector3.RIGHT*0.7,wheel+Vector3.RIGHT*0.1))
		check(tire_hit.get("collider")==car,"Tire side actually collides: "+car.spec.id)
		# Begin a drop only after establishing loaded contact; every wheel must time its flight.
		car.reset_to_start(Vector3(0,7,0))
		await frames(20)
		check(car.grounded_wheels==0 and car.all_airtime>0.25,"Whole-car flight is timed: "+car.spec.id)
		for value in car.wheel_airtime:
			check(value>0.25,"Each airborne wheel is timed: "+car.spec.id)
		await frames(150)
		row.drop_max_wheel_airtime_s=Array(car.wheel_max_airtime)
		row.drop_max_all_airtime_s=car.max_all_airtime
		check(car.grounded_wheels==car.rays.size(),"All wheels return after drop: "+car.spec.id)
		# Both side and fore/aft rollover are detected; reset must settle and drive again.
		for axis in [Vector3.FORWARD,Vector3.RIGHT]:
			car.reset_to_start(Vector3(0,8,0))
			await frames(2)
			car.basis=Basis(axis,deg_to_rad(110))
			await frames(3)
			check(car.tipped,"Side/pitch tip detection: "+car.spec.id)
		car.reset_to_start(Vector3(0,1.8,0))
		var stable:=0
		var settled_at:=-1.0
		for tick in 240:
			await physics_frame
			if car.grounded_wheels==car.rays.size() and car.global_basis.y.y>0.98 and car.linear_velocity.length()<0.3 and car.angular_velocity.length()<0.15:
				stable+=1
			else: stable=0
			if stable==30:
				settled_at=(tick+1)/60.0
				break
		check(settled_at>0,"Reset sustains stable ground contact for 0.5 s: "+car.spec.id)
		row.reset_stable_confirmed_s=settled_at
		var before: Vector3=car.position
		car.autopilot_input=Vector2(0,0.5)
		await frames(120)
		row.post_reset_distance_m=car.position.distance_to(before)
		check(row.post_reset_distance_m>3 and not car.tipped,"Can drive after recovery: "+car.spec.id)
		report.append(row)
		print("HANDLING ",JSON.stringify(row))
		car.set_physics_process(false)
		car.stop_audio()
		OS.delay_msec(80)
		car.queue_free()
		await frames(2)
	var file:=FileAccess.open("res://build/vehicle-handling-acceptance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"vehicles":report,"failures":failures},"  "))
	file.close()
	print("VEHICLE_HANDLING_ACCEPTANCE: ","PASS" if failures.is_empty() else failures)
	stage.queue_free()
	await frames(2)
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
