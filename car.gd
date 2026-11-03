extends RigidBody3D

const VEHICLES := preload("res://vehicles.gd")
const WHEEL := preload("res://assets/models/scout_wheel.tscn")
const ENGINE := preload("res://assets/audio/engine.wav")
const GRAVEL := preload("res://assets/audio/gravel.wav")
const WATER := preload("res://assets/audio/water.wav")
const IMPACT := preload("res://assets/audio/impact.wav")

var vehicle_index := 0
var spec: Dictionary
var wheel_points: Array[Vector3]
var radius := 0.48
var rest := 0.65
var low_range := false
var steering_wheel: Node3D
var speed_needle: Node3D
var heading_needle: Node3D
var speed_readout: Label3D
var world: Node3D
var start_position := Vector3.ZERO
var start_yaw := 0.0
var grounded_wheels := 0
var surface_kind := "dirt"
var rays: Array[RayCast3D] = []
var wheels: Array[Node3D] = []
var wheel_spin := 0.0
var engine_audio: AudioStreamPlayer
var gravel_audio: AudioStreamPlayer
var water_audio: AudioStreamPlayer
var impact_audio: AudioStreamPlayer
var dust: CPUParticles3D
var spray: CPUParticles3D
var trail: ImmediateMesh
var marks: Array = []
var last_mark := Vector3.ZERO
var impact_cooldown := 0.0
var previous_velocity := Vector3.ZERO
var pending_reset := false
var reset_position := Vector3.ZERO
var reset_yaw := 0.0

func _ready() -> void:
	spec=VEHICLES.SPECS[vehicle_index]
	wheel_points=VEHICLES.wheel_points(spec)
	radius=spec.radius
	rest=spec.travel
	mass=spec.mass
	linear_damp=0.12
	angular_damp=2.8
	continuous_cd=true
	center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass=Vector3(0,-0.38,0.05)
	contact_monitor=true
	max_contacts_reported=6
	var pm := PhysicsMaterial.new()
	pm.friction=0.2
	pm.bounce=0.0
	physics_material_override=pm
	start_position=global_position
	start_yaw=rotation.y
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(spec.width*0.87,0.7,spec.length)
	collision.shape=box
	collision.position.y=0.25
	add_child(collision)
	var cabin_collision := CollisionShape3D.new()
	var cabin_box := BoxShape3D.new()
	cabin_box.size=Vector3(spec.width*0.87,spec.roof-0.6,1.6)
	cabin_collision.shape=cabin_box
	cabin_collision.position=Vector3(0,(spec.roof+0.6)/2,spec.seat.z)
	add_child(cabin_collision)
	var body: Node3D = load("res://assets/models/"+spec.id+"_body.tscn").instantiate()
	add_child(body)
	steering_wheel = body.get_node("SteeringWheel")
	speed_needle = body.get_node("SpeedNeedle")
	heading_needle = body.get_node("HeadingNeedle")
	speed_readout = body.get_node("SpeedReadout")
	_update_dashboard(0)
	for point in wheel_points:
		var ray := RayCast3D.new()
		ray.position=point
		ray.target_position=Vector3(0,-rest-radius-0.2,0)
		ray.exclude_parent=true
		ray.enabled=true
		add_child(ray)
		rays.append(ray)
		var pivot := Node3D.new()
		pivot.position=point-Vector3.UP*rest
		add_child(pivot)
		var wheel: Node3D=WHEEL.instantiate()
		wheel.scale=Vector3.ONE*radius/0.48
		pivot.add_child(wheel)
		wheels.append(pivot)
	engine_audio=_loop(ENGINE,-23)
	gravel_audio=_loop(GRAVEL,-60)
	water_audio=_loop(WATER,-60)
	impact_audio=AudioStreamPlayer.new()
	impact_audio.stream=IMPACT
	add_child(impact_audio)
	dust=_particles(Color("a69b80"),0.95,48)
	spray=_particles(Color("c4d5c4"),0.5,36)
	trail=ImmediateMesh.new()
	var visual := MeshInstance3D.new()
	visual.mesh=trail
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color("696650")
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	visual.material_override=mat
	visual.top_level=true
	visual.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(visual)
	visual.global_transform=Transform3D.IDENTITY

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if pending_reset:
		state.transform=Transform3D(Basis(Vector3.UP,reset_yaw),reset_position)
		state.linear_velocity=Vector3.ZERO
		state.angular_velocity=Vector3.ZERO
		pending_reset=false
		reset_physics_interpolation()

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null

func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis("reverse","accelerate")
	var steering := Input.get_axis("left","right")
	var braking := Input.is_action_pressed("handbrake")
	var forward := -global_basis.z
	var right := global_basis.x
	var speed := linear_velocity.dot(forward)
	grounded_wheels=0
	var handling := Vector3.ZERO
	for i in rays.size():
		var ray := rays[i]
		ray.force_raycast_update()
		var travel := rest
		if ray.is_colliding():
			travel=ray.global_position.distance_to(ray.get_collision_point())-radius
			if travel < rest:
				grounded_wheels+=1
				var surface: String=world.surface_at(ray.get_collision_point()+Vector3.UP*0.05) if is_instance_valid(world) else "dirt"
				handling+=VEHICLES.SURFACES.get(surface,VEHICLES.SURFACES.dirt)
				var normal := ray.get_collision_normal()
				var offset := ray.global_position-global_position
				var point_velocity := linear_velocity+angular_velocity.cross(offset)
				var load_scale := mass/850.0*4.0/rays.size()
				var spring := ((rest-travel)*28000.0-point_velocity.dot(normal)*3200.0)*load_scale
				apply_force(normal*clampf(spring,0,22000*load_scale),offset)
		wheels[i].position=wheel_points[i]-Vector3.UP*clampf(travel,0.05,rest)
		wheels[i].rotation.y=lerp_angle(wheels[i].rotation.y,-steering*0.48 if i<2 else 0.0,delta*9)
		wheels[i].get_child(0).rotation.x=-wheel_spin
	surface_kind=world.surface_at(global_position) if is_instance_valid(world) else "dirt"
	var contact := float(grounded_wheels)/rays.size()
	if grounded_wheels>0:
		handling/=grounded_wheels
		var drive: float=spec.drive*handling.z*(1.65 if low_range else 1.0)
		var max_speed: float=(spec.speed*(0.32 if low_range else 1.0)) if throttle>=0 else 7.0
		var available := clampf((max_speed-absf(speed))*0.7,0,1) if signf(speed)==signf(throttle) else 1.0
		apply_central_force(forward*throttle*drive*available*contact)
		var grip := handling.x*(0.3 if braking else 1.0)
		apply_central_force(-right*linear_velocity.dot(right)*mass*grip*contact)
		apply_central_force(-forward*speed*mass*(3.5 if braking else handling.y)*contact)
		var desired_yaw: float=-steering*spec.steer*clampf(speed/7.0,-1,1)/(1.0+maxf(0,absf(speed)-13)*0.035)
		apply_torque(Vector3.UP*(desired_yaw-angular_velocity.y)*mass*2.4*contact)
		apply_torque(global_basis.y.cross(Vector3.UP)*mass*3.0)
	steering_wheel.rotation.z=lerp_angle(steering_wheel.rotation.z,-steering*1.5,delta*9)
	_update_dashboard(absf(speed)*3.6)
	wheel_spin+=speed*delta/radius
	var speed_ratio := clampf(absf(speed)/24,0,1)
	engine_audio.pitch_scale=lerpf(engine_audio.pitch_scale,0.72+speed_ratio*1.25+absf(throttle)*0.16,delta*4)
	engine_audio.volume_db=lerpf(-25,-15,maxf(speed_ratio,absf(throttle)*0.45))
	gravel_audio.volume_db=lerpf(gravel_audio.volume_db,-25+speed_ratio*9 if grounded_wheels>0 and absf(speed)>1 and surface_kind in ["dirt","sand","grass","forest","rock","gobi","snow"] else -65,delta*5)
	water_audio.volume_db=lerpf(water_audio.volume_db,-20+speed_ratio*6 if grounded_wheels>0 and absf(speed)>1 and surface_kind in ["water","mud","swamp"] else -65,delta*5)
	dust.emitting=grounded_wheels>0 and absf(speed)>2 and surface_kind in ["dirt","sand","grass","forest","rock","gobi","snow"]
	var dust_color := Color("e1e9e7") if surface_kind=="snow" else Color("b9a381")
	dust.color_ramp.set_color(0,Color(dust_color,0.55))
	dust.color_ramp.set_color(1,Color(dust_color,0))
	spray.emitting=grounded_wheels>0 and absf(speed)>1 and surface_kind in ["water","mud","swamp"]
	impact_cooldown=maxf(0,impact_cooldown-delta)
	if (linear_velocity-previous_velocity).length()>3.5 and get_contact_count()>0 and impact_cooldown==0:
		impact_audio.volume_db=-14
		impact_audio.play()
		impact_cooldown=0.35
	previous_velocity=linear_velocity
	if grounded_wheels>1 and surface_kind!="road" and global_position.distance_to(last_mark)>0.65:
		_add_tracks()

func reset_to_start(at: Vector3 = start_position) -> void:
	reset_position=at
	reset_yaw=start_yaw
	pending_reset=true
	sleeping=false
	previous_velocity=Vector3.ZERO
	marks.clear()
	trail.clear_surfaces()
	dust.restart()
	dust.emitting=false
	spray.restart()
	spray.emitting=false
	last_mark=at

func _loop(stream: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var looped := stream.duplicate() as AudioStreamWAV
	looped.loop_mode=AudioStreamWAV.LOOP_FORWARD
	looped.loop_end=int(looped.mix_rate*looped.get_length())
	player.stream=looped
	player.volume_db=db
	add_child(player)
	player.play()
	return player

func _particles(color: Color,lifetime: float,amount: int) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.position=Vector3(0,-0.35,1.4)
	emitter.local_coords=false
	emitter.amount=amount
	emitter.lifetime=lifetime
	emitter.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.emission_box_extents=Vector3(1,0.05,0.2)
	emitter.direction=Vector3(0,1,0.3)
	emitter.spread=35
	emitter.initial_velocity_min=0.7
	emitter.initial_velocity_max=2
	emitter.gravity=Vector3(0,-1.8,0)
	emitter.scale_amount_min=0.1
	emitter.scale_amount_max=0.3
	var gradient := Gradient.new()
	gradient.set_color(0,Color(color,0.55))
	gradient.set_color(1,Color(color,0))
	emitter.color_ramp=gradient
	var mesh := SphereMesh.new()
	mesh.radial_segments=6
	mesh.rings=3
	mesh.radius=0.7
	mesh.height=1.1
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material=material
	emitter.mesh=mesh
	emitter.emitting=false
	add_child(emitter)
	return emitter

func _add_tracks() -> void:
	last_mark=global_position
	for index in range(rays.size()-2,rays.size()):
		if not rays[index].is_colliding():
			continue
		var p := rays[index].get_collision_point()+Vector3.UP*0.025
		var side := global_basis.x*0.14
		var along := global_basis.z*0.32
		marks.append([p-side-along,p+side-along,p+side+along,p-side+along])
	while marks.size()>320:
		marks.pop_front()
	trail.clear_surfaces()
	trail.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for mark in marks:
		for i in [0,1,2,0,2,3]:
			trail.surface_add_vertex(mark[i])
	trail.surface_end()

func _update_dashboard(kmh: float) -> void:
	speed_needle.rotation.z = deg_to_rad(135-clampf(kmh/float(speed_needle.get_meta("maximum_kmh",140.0)),0,1)*270)
	heading_needle.rotation.z = rotation.y
	speed_readout.text = "%03d" % roundi(kmh*float(speed_readout.get_meta("unit_scale",1.0)))
