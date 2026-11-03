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
var wheels: Array[Node3D] = []
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

func _ready() -> void:
	spec=VEHICLES.SPECS[vehicle_index]
	wheel_points=VEHICLES.wheel_points(spec)
	radius=spec.radius
	rest=spec.travel
	mass=spec.mass
	linear_damp=0.12
	angular_damp=2.2
	continuous_cd=true
	center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass=spec.get("center_of_mass",Vector3(0,-0.38,0.05))
	max_steer_angle=deg_to_rad(float(spec.get("max_steer_deg",30.0)))
	wheelbase=absf(float(spec.axles[spec.axles.size()-1])-float(spec.axles[0]))
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

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if pending_reset:
		state.transform=Transform3D(Basis(Vector3.UP,reset_yaw),reset_position)
		state.linear_velocity=Vector3.ZERO
		state.angular_velocity=Vector3.ZERO
		pending_reset=false
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

func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis("reverse","accelerate")
	var steering := Input.get_axis("left","right")
	var braking := Input.is_action_pressed("handbrake")
	current_steer_angle=steering*max_steer_angle
	var forward := -global_basis.z
	var right := global_basis.x
	var speed := linear_velocity.dot(forward)
	grounded_wheels=0
	contact_surfaces.clear()
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
				contact_surfaces[surface]=contact_surfaces.get(surface,0)+1
				var normal := ray.get_collision_normal()
				var offset := ray.global_position-global_position
				var point_velocity := linear_velocity+angular_velocity.cross(offset)
				var load_scale := mass/850.0*4.0/rays.size()
				var spring := ((rest-travel)*28000.0-point_velocity.dot(normal)*3200.0)*load_scale
				apply_force(normal*clampf(spring,0,22000*load_scale),offset)
		wheels[i].position=wheel_points[i]-Vector3.UP*clampf(travel,0.05,rest)
		wheels[i].rotation.y=lerp_angle(wheels[i].rotation.y,-current_steer_angle if i<2 else 0.0,delta*float(spec.get("steer_response",1.0))*8.0)
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
		var desired_yaw: float=-tan(current_steer_angle)*speed/maxf(wheelbase,1.0)
		desired_yaw=clampf(desired_yaw,-1.9,1.9)*float(spec.get("steer_response",1.0))
		apply_torque(Vector3.UP*(desired_yaw-angular_velocity.y)*mass*2.4*contact)
		# Keep a small, vehicle-specific stability assist; suspension and gravity still decide rollover.
		apply_torque(global_basis.y.cross(Vector3.UP)*mass*float(spec.get("stability_assist",0.5))*contact)
	roll_angle_degrees=rad_to_deg(atan2(global_basis.x.y,global_basis.y.y))
	max_roll_angle_degrees=maxf(max_roll_angle_degrees,absf(roll_angle_degrees))
	tipped=absf(roll_angle_degrees)>75.0
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
