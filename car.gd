extends RigidBody3D

const VEHICLES := preload("res://vehicles.gd")
const WHEEL := preload("res://assets/models/scout_wheel.tscn")
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
var tire_edge_rays: Array[Array] = []
var contact_rays: Array[RayCast3D] = []
var wheels: Array[Node3D] = []
var wheel_colliders: Array[CollisionShape3D] = []
var wheel_loads := PackedFloat64Array()
var wheel_airtime := PackedFloat64Array()
var wheel_max_airtime := PackedFloat64Array()
var all_airtime := 0.0
var max_all_airtime := 0.0
var tilt_angle_degrees := 0.0
var wheel_spin := 0.0
var engine_audio: AudioStreamPlayer
var engine_load_audio: AudioStreamPlayer
var surface_audio: Dictionary = {}
var audio_profile: Dictionary
var contact_surfaces: Dictionary = {}
var audio_rpm := 750.0
var audio_gear := 0
var shift_time := 0.0
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
var max_steer_angle := deg_to_rad(30.0)
var current_steer_angle := 0.0
var wheelbase := 2.5
var roll_angle_degrees := 0.0
var max_roll_angle_degrees := 0.0
var tipped := false
var autopilot_enabled := false
var autopilot_input := Vector2.ZERO

func _ready() -> void:
	spec=VEHICLES.SPECS[vehicle_index]
	wheel_points=VEHICLES.wheel_points(spec)
	radius=spec.radius
	rest=spec.travel
	mass=spec.mass
	# shortcut: sprung-body box inertia stays fixed as wheel proxies move; replace with measured tensors when CAD mass data exists.
	inertia=mass/12.0*Vector3(spec.length*spec.length+spec.roof*spec.roof,spec.width*spec.width+spec.length*spec.length,spec.width*spec.width+spec.roof*spec.roof)
	linear_damp=0.12
	angular_damp=0.35
	continuous_cd=true
	center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass=spec.get("center_of_mass",Vector3(0,-0.38,0.05))
	max_steer_angle=deg_to_rad(float(spec.get("max_steer_deg",30.0)))
	wheelbase=absf((float(spec.axles[1])+float(spec.axles[-1]))*0.5-float(spec.axles[0]))
	contact_monitor=true
	max_contacts_reported=6
	var pm := PhysicsMaterial.new()
	pm.friction=0.2
	pm.bounce=0.0
	physics_material_override=pm
	start_position=global_position
	start_yaw=rotation.y
	_add_vehicle_collisions()
	var body: Node3D = load("res://assets/models/"+spec.id+"_body.tscn").instantiate()
	add_child(body)
	steering_wheel = body.get_node("SteeringWheel")
	speed_needle = body.get_node("SpeedNeedle")
	heading_needle = body.get_node("HeadingNeedle")
	speed_readout = body.get_node("SpeedReadout")
	_update_dashboard(0)
	wheel_loads.resize(wheel_points.size())
	wheel_airtime.resize(wheel_points.size())
	wheel_max_airtime.resize(wheel_points.size())
	for point in wheel_points:
		var ray := RayCast3D.new()
		ray.position=point
		ray.target_position=Vector3(0,-rest-radius-0.2,0)
		ray.exclude_parent=true
		ray.enabled=true
		add_child(ray)
		rays.append(ray)
		contact_rays.append(ray)
		var edge_rays: Array=[]
		for side in [-1,1]:
			var edge:=RayCast3D.new()
			edge.position=point+Vector3.RIGHT*side*0.37*radius/0.48*0.4
			edge.target_position=ray.target_position
			edge.exclude_parent=true
			add_child(edge)
			edge_rays.append(edge)
		tire_edge_rays.append(edge_rays)
		var pivot := Node3D.new()
		pivot.position=point-Vector3.UP*rest
		add_child(pivot)
		var wheel: Node3D=WHEEL.instantiate()
		wheel.scale=Vector3.ONE*radius/0.48
		pivot.add_child(wheel)
		wheels.append(pivot)
		var tire := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		# Slightly inset tread leaves suspension rays supporting normal ground contact.
		cylinder.radius=radius*0.94
		cylinder.height=0.37*radius/0.48
		tire.shape=cylinder
		tire.position=pivot.position
		tire.rotation.z=PI/2
		tire.set_meta("collision_role","tire")
		add_child(tire)
		wheel_colliders.append(tire)
	audio_profile=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/profiles.json"))[spec.id]
	audio_rpm=audio_profile.idle_rpm
	engine_audio=_loop(load("res://assets/audio/engine_"+spec.id+"_idle.wav"),-20)
	engine_load_audio=_loop(load("res://assets/audio/engine_"+spec.id+"_load.wav"),-80)
	for kind in VEHICLES.SURFACES:
		var player:=_loop(load("res://assets/audio/tire_"+kind+".wav"),-80)
		player.stop()
		player.volume_linear=0
		surface_audio[kind]=player
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

func _add_vehicle_collisions() -> void:
	# Keep the visual mesh independent from the physics proxy; each proxy is stable on slopes.
	_add_box_collision(Vector3(spec.width*0.88,0.64,spec.length*0.84),Vector3(0,0.30,0))
	var cabin_front: float=spec.seat.z-1.02
	var cabin_back: float=spec.length/2-0.3 if spec.id in ["scout","wrangler"] else spec.seat.z+(1.12 if spec.id in ["f150","hilux"] else 0.9)
	var cabin_height: float=spec.roof-0.42
	_add_box_collision(Vector3(spec.width*0.96,cabin_height,cabin_back-cabin_front),Vector3(0,0.42+cabin_height*0.5,(cabin_front+cabin_back)*0.5))
	var cargo_start: float=cabin_back+0.12
	var cargo_length: float=spec.length*0.5-cargo_start
	if cargo_length>0.45:
		var cargo_height: float=0.9 if spec.id in ["pickup","f150","hilux"] else 1.15
		var cargo_y: float=0.75 if cargo_height<1.0 else 1.25
		if spec.id=="unimog":
			cargo_height=2.0
			cargo_y=1.62
		elif spec.id=="eq246":
			cargo_height=1.6
			cargo_y=1.70
		_add_box_collision(Vector3(spec.width*0.92,cargo_height,cargo_length),Vector3(0,cargo_y,cargo_start+cargo_length*0.5))
	_add_box_collision(Vector3(spec.width*0.98,0.28,0.34),Vector3(0,0.31,-spec.length*0.48))
	_add_box_collision(Vector3(spec.width*0.98,0.28,0.28),Vector3(0,0.31,spec.length*0.48))

func _add_box_collision(size: Vector3, position: Vector3) -> void:
	var shape_node:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape_node.shape=box
	shape_node.position=position
	shape_node.set_meta("collision_role", "vehicle_compound")
	add_child(shape_node)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if pending_reset:
		state.transform=Transform3D(Basis(Vector3.UP,reset_yaw),reset_position)
		state.linear_velocity=Vector3.ZERO
		state.angular_velocity=Vector3.ZERO
		pending_reset=false
		grounded_wheels=0
		wheel_loads.fill(0.0)
		reset_contact_metrics()
		reset_physics_interpolation()

func _exit_tree() -> void:
	stop_audio()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stream=null

func stop_audio() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()

func wheel_steer_angle(index: int) -> float:
	if index>=2 or absf(current_steer_angle)<0.0001:
		return 0.0
	var turn_radius := wheelbase/tan(absf(current_steer_angle))
	# Inner and outer front wheels follow concentric circles about the rear axle group.
	return -signf(current_steer_angle)*atan(wheelbase/(turn_radius-signf(current_steer_angle)*wheel_points[index].x))

func reset_contact_metrics() -> void:
	wheel_airtime.fill(0.0)
	wheel_max_airtime.fill(0.0)
	all_airtime=0.0
	max_all_airtime=0.0

func _physics_process(delta: float) -> void:
	var throttle := autopilot_input.y if autopilot_enabled else Input.get_axis("reverse","accelerate")
	var steering := autopilot_input.x if autopilot_enabled else Input.get_axis("left","right")
	var braking := not autopilot_enabled and Input.is_action_pressed("handbrake")
	current_steer_angle=move_toward(current_steer_angle,steering*max_steer_angle,delta*float(spec.get("steer_response",1.0))*2.5)
	var forward := -global_basis.z
	var speed := linear_velocity.dot(forward)
	grounded_wheels=0
	contact_surfaces.clear()
	for i in rays.size():
		var ray := rays[i]
		ray.force_raycast_update()
		wheels[i].rotation.y=wheel_steer_angle(i)
		for edge_index in 2:
			var edge: RayCast3D=tire_edge_rays[i][edge_index]
			edge.position=wheel_points[i]+wheels[i].basis.x*(edge_index*2-1)*0.37*radius/0.48*0.4
			edge.force_raycast_update()
			if edge.is_colliding() and (not ray.is_colliding() or edge.global_position.distance_to(edge.get_collision_point())<ray.global_position.distance_to(ray.get_collision_point())):
				ray=edge
		contact_rays[i]=ray
		var travel := rest
		wheel_loads[i]=0.0
		if ray.is_colliding():
			travel=ray.global_position.distance_to(ray.get_collision_point())-radius
			if travel < rest:
				var surface: String=world.surface_at(ray.get_collision_point()+Vector3.UP*0.05) if is_instance_valid(world) else "dirt"
				var normal := ray.get_collision_normal()
				var offset := ray.get_collision_point()-global_position
				var point_velocity := linear_velocity+angular_velocity.cross(offset-global_basis*center_of_mass)
				var load_scale := mass/850.0*4.0/rays.size()
				var spring := ((rest-travel)*28000.0-point_velocity.dot(normal)*3200.0)*load_scale
				var load := clampf(spring,0,22000*load_scale)
				wheel_loads[i]=load
				if load>1.0:
					grounded_wheels+=1
					contact_surfaces[surface]=contact_surfaces.get(surface,0)+1
					apply_force(normal*load,offset)

		wheel_airtime[i]=wheel_airtime[i]+delta if wheel_loads[i]<=1.0 else 0.0
		wheel_max_airtime[i]=maxf(wheel_max_airtime[i],wheel_airtime[i])
		wheels[i].position=wheel_points[i]-Vector3.UP*clampf(travel,0.05,rest)
		wheels[i].get_child(0).rotation.x=-wheel_spin
		wheel_colliders[i].transform=Transform3D(wheels[i].basis*Basis(Vector3.BACK,PI/2),wheels[i].position)
	var total_load:=0.0
	for load in wheel_loads: total_load+=load
	for i in rays.size():
		if wheel_loads[i]>1.0:
			_apply_tire_force(i,throttle,braking,speed,total_load)
	all_airtime=all_airtime+delta if grounded_wheels==0 else 0.0
	max_all_airtime=maxf(max_all_airtime,all_airtime)
	surface_kind=world.surface_at(global_position) if is_instance_valid(world) else "dirt"
	roll_angle_degrees=rad_to_deg(atan2(global_basis.x.y,global_basis.y.y))
	max_roll_angle_degrees=maxf(max_roll_angle_degrees,absf(roll_angle_degrees))
	tilt_angle_degrees=rad_to_deg(acos(clampf(global_basis.y.dot(Vector3.UP),-1,1)))
	tipped=tilt_angle_degrees>75.0
	steering_wheel.rotation.z=lerp_angle(steering_wheel.rotation.z,-steering*1.5,delta*9)
	_update_dashboard(absf(speed)*3.6)
	wheel_spin+=speed*delta/radius
	_update_audio(delta,throttle,speed)
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

func _apply_tire_force(i: int, throttle: float, braking: bool, speed: float, total_load: float) -> void:
	var ray:=contact_rays[i]
	var normal:=ray.get_collision_normal()
	var offset:=ray.get_collision_point()-global_position
	var point_velocity:=linear_velocity+angular_velocity.cross(offset-global_basis*center_of_mass)
	var surface: String=world.surface_at(ray.get_collision_point()+Vector3.UP*0.05) if is_instance_valid(world) else "dirt"
	var handling: Vector3=VEHICLES.SURFACES.get(surface,VEHICLES.SURFACES.dirt)
	var tire_forward := (-wheels[i].global_basis.z).slide(normal).normalized()
	var tire_right := tire_forward.cross(normal).normalized()
	var along_speed := point_velocity.dot(tire_forward)
	var side_speed := point_velocity.dot(tire_right)
	var max_speed: float=(spec.speed*(0.32 if low_range else 1.0)) if throttle>=0 else 7.0
	var available := clampf((max_speed-absf(speed))*0.7,0,1) if signf(speed)==signf(throttle) else 1.0
	# Load sharing approximates locked all-wheel drive without creating extra total engine force.
	var drive: float=throttle*spec.drive*handling.z*available*(1.65 if low_range else 1.0)*wheel_loads[i]/total_load
	var resistance := -along_speed*mass/rays.size()*(3.5 if braking else handling.y)
	var lateral := -side_speed*mass/rays.size()*handling.x*6.0*(0.3 if braking else 1.0)
	# shortcut: load-limited tire friction; add tire deformation when soft-soil physics is implemented.
	var tire_force := (tire_forward*(drive+resistance)+tire_right*lateral).limit_length(wheel_loads[i]*handling.x*0.28)
	apply_force(tire_force,offset)

func reset_to_start(at: Vector3 = start_position) -> void:
	reset_position=at
	reset_yaw=start_yaw
	pending_reset=true
	sleeping=false
	previous_velocity=Vector3.ZERO
	audio_gear=0
	audio_rpm=audio_profile.idle_rpm
	shift_time=0
	roll_angle_degrees=0.0
	max_roll_angle_degrees=0.0
	tipped=false
	contact_surfaces.clear()
	for player in surface_audio.values():
		player.volume_linear=0
		player.stop()
	marks.clear()
	trail.clear_surfaces()
	dust.restart()
	dust.emitting=false
	spray.restart()
	spray.emitting=false
	last_mark=at

func _update_audio(delta: float, throttle: float, forward_speed: float) -> void:
	var blend:=1-exp(-delta*7)
	var idle: float=audio_profile.idle_rpm
	var redline: float=audio_profile.redline
	var gears: Array=audio_profile.gears
	var reverse:=forward_speed < -0.5 or throttle < 0
	var wheel_rpm:=absf(forward_speed)/radius*60/TAU
	var final_drive:=4.1*(2.6 if low_range else 1.0)
	var coupled: float=wheel_rpm*float(gears[audio_gear])*final_drive
	shift_time=maxf(0,shift_time-delta)
	# shortcut: sound-only transmission; replace with drivetrain RPM when mechanical gears exist.
	if not reverse and shift_time==0:
		if coupled>redline*0.80 and audio_gear<gears.size()-1:
			audio_gear+=1
			shift_time=0.28
		elif coupled<redline*0.30 and audio_gear>0:
			audio_gear-=1
			shift_time=0.28
	coupled=wheel_rpm*float(gears[0] if reverse else gears[audio_gear])*final_drive
	var target:=maxf(idle+absf(throttle)*(redline-idle)*0.22,coupled)
	if grounded_wheels==0:
		target=lerpf(idle,redline*0.85,absf(throttle))
	audio_rpm=lerpf(audio_rpm,clampf(target,idle,redline),blend)
	var rev:=clampf((audio_rpm-idle)/(redline-idle),0,1)
	var load_gain:=lerpf(0.28,1.0,absf(throttle))*(0.48 if shift_time>0.12 else 1.0)
	engine_audio.pitch_scale=clampf(audio_rpm/idle,0.8,4.0)
	engine_load_audio.pitch_scale=clampf(audio_rpm/float(audio_profile.run_rpm),0.2,3.0)
	var run_mix:=smoothstep(0.04,0.32,rev)
	engine_audio.volume_linear=lerpf(engine_audio.volume_linear,0.20*(1-run_mix),blend)
	engine_load_audio.volume_linear=lerpf(engine_load_audio.volume_linear,0.48*run_mix*load_gain,blend)
	var road_speed:=Vector2(linear_velocity.x,linear_velocity.z).length()
	var moving:=smoothstep(0.12,1.5,road_speed)
	var rolling:=moving*lerpf(0.20,0.85,clampf(road_speed/24,0,1))
	var weight:=clampf(pow(mass/1800.0,0.18),0.85,1.25)
	var slip:=clampf(absf(linear_velocity.dot(global_basis.x))/8,0,0.5)
	for kind in surface_audio:
		var player: AudioStreamPlayer=surface_audio[kind]
		var share:=float(contact_surfaces.get(kind,0))/rays.size()
		var gain:=rolling*share*weight*(1+slip)
		player.pitch_scale=clampf((0.70+road_speed*0.025)*sqrt(0.53/radius),0.6,1.65)
		player.volume_linear=lerpf(player.volume_linear,gain,blend)
		if gain>0.0001 and not player.playing:
			player.play()
		elif gain==0 and player.volume_linear<0.0001:
			player.stop()
			player.volume_linear=0

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
	if marks.is_empty():
		return
	trail.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for mark in marks:
		for i in [0,1,2,0,2,3]:
			trail.surface_add_vertex(mark[i])
	trail.surface_end()

func _update_dashboard(kmh: float) -> void:
	speed_needle.rotation.z = deg_to_rad(135-clampf(kmh/float(speed_needle.get_meta("maximum_kmh",140.0)),0,1)*270)
	heading_needle.rotation.z = rotation.y
	speed_readout.text = "%03d" % roundi(kmh*float(speed_readout.get_meta("unit_scale",1.0)))
