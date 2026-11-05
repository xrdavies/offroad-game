extends SceneTree

const VEHICLES:=preload("res://vehicles.gd")
const CAR:=preload("res://car.gd")
var failures: Array[String]=[]
var report: Array=[]

class Surface extends Node3D:
	var kind: String="rock"
	func surface_at(_at: Vector3) -> String: return kind

func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func box(parent: Node3D, size: Vector3, at: Vector3, pitch:=0.0) -> void:
	var body:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)
	body.position=at
	body.rotation.x=pitch
	parent.add_child(body)

func run() -> void:
	for action in ["accelerate","reverse","left","right","handbrake"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	for index in VEHICLES.SPECS.size():
		var stage:=Surface.new()
		root.add_child(stage)
		box(stage,Vector3(300,1,300),Vector3(0,-0.5,0))
		var track: float=VEHICLES.wheel_points(VEHICLES.SPECS[index])[1].x
		box(stage,Vector3(0.26,0.18,3.4),Vector3(track,0.22,-5),0.26)
		box(stage,Vector3(0.26,0.18,3.4),Vector3(-track,0.22,-11),0.26)
		var car:=RigidBody3D.new()
		car.set_script(CAR)
		car.vehicle_index=index
		car.world=stage
		car.position=Vector3(0,1.8,0)
		stage.add_child(car)
		car.autopilot_enabled=true
		car.low_range=true
		var row: Dictionary={"id":car.spec.id,"surfaces":[]}
		for kind in ["sand","rock","forest","snow"]:
			stage.kind=kind
			car.autopilot_input=Vector2.ZERO
			car.reset_to_start(Vector3(0,1.8,0))
			await frames(150)
			check(car.grounded_wheels==car.rays.size(),"Start loaded on "+kind+": "+car.spec.id)
			car.reset_contact_metrics()
			var unloaded:=0
			var max_tilt:=0.0
			var elapsed:=0.0
			for tick in 1500:
				var speed: float=car.linear_velocity.dot(-car.global_basis.z)
				var steer: float=clampf(wrapf(car.rotation.y,-PI,PI)*2.0-car.position.x*0.25,-0.7,0.7)
				car.autopilot_input=Vector2(steer,clampf(0.13+(1.5-speed)*0.5,0,0.8))
				await physics_frame
				if car.grounded_wheels<car.rays.size(): unloaded+=1
				max_tilt=maxf(max_tilt,car.tilt_angle_degrees)
				elapsed=(tick+1)/60.0
				if car.position.z<-18 and car.grounded_wheels==car.rays.size(): break
			check(is_finite(car.position.y) and car.position.z<-18,"Drive over staggered steps on "+kind+": "+car.spec.id)
			check(max_tilt<65,"Stay upright over moderate steps on "+kind+": "+car.spec.id)
			check(unloaded>0 and Array(car.wheel_max_airtime).max()>0,"Per-wheel unloading detected on "+kind+": "+car.spec.id)
			row.surfaces.append({"surface":kind,"elapsed_s":elapsed,"distance_m":-car.position.z,"max_tilt_deg":max_tilt,"max_wheel_airtime_s":Array(car.wheel_max_airtime),"all_airtime_s":car.max_all_airtime})
		car.autopilot_input=Vector2.ZERO
		stage.kind="rock"
		var slope:=Node3D.new()
		stage.add_child(slope)
		slope.position=Vector3(0,8,40)
		box(slope,Vector3(14,1,20),Vector3.ZERO)
		# Low downhill curb prevents sliding from hiding the actual tip threshold.
		box(slope,Vector3(0.3,0.10,12),Vector3(-track-0.37*car.radius/0.48*0.5-0.20,0.55,0))
		car.reset_to_start(Vector3(0,10,40))
		await frames(180)
		check(car.grounded_wheels==car.rays.size(),"Start loaded before tilt table: "+car.spec.id)
		car.reset_contact_metrics()
		var first_unload:=-1.0
		var tip_angle:=-1.0
		var max_tilt:=0.0
		for tick in 1300:
			slope.rotation.z=deg_to_rad(minf(tick*0.09,80))
			await physics_frame
			if first_unload<0 and car.grounded_wheels<car.rays.size(): first_unload=rad_to_deg(slope.rotation.z)
			max_tilt=maxf(max_tilt,car.tilt_angle_degrees)
			if car.tipped and tip_angle<0: tip_angle=rad_to_deg(slope.rotation.z)
		check(tip_angle>0 and max_tilt>90,"Gravity produces a natural side rollover: "+car.spec.id)
		row.tilt_table={"first_unload_deg":first_unload,"tip_at_table_deg":tip_angle,"max_body_tilt_deg":max_tilt}
		report.append(row)
		print("TERRAIN ",JSON.stringify(row))
		car.set_physics_process(false)
		car.stop_audio()
		OS.delay_msec(80)
		stage.queue_free()
		await frames(2)
	var file:=FileAccess.open("res://build/vehicle-terrain-dynamics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"vehicles":report,"failures":failures},"  "))
	file.close()
	print("VEHICLE_TERRAIN_DYNAMICS: ","PASS" if failures.is_empty() else failures)
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
