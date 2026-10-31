extends RigidBody3D

const BODY := preload("res://assets/models/scout_body.tscn")
const WHEEL := preload("res://assets/models/scout_wheel.tscn")
const ENGINE := preload("res://assets/audio/engine.wav")
const GRAVEL := preload("res://assets/audio/gravel.wav")
const WATER := preload("res://assets/audio/water.wav")
const IMPACT := preload("res://assets/audio/impact.wav")
const WHEEL_POINTS := [Vector3(-0.99,0.32,-1.25),Vector3(0.99,0.32,-1.25),Vector3(-0.99,0.32,1.28),Vector3(0.99,0.32,1.28)]
const RADIUS := 0.48
const REST := 0.65

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
	mass=850.0
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
	box.size=Vector3(1.65,0.7,3.6)
	collision.shape=box
	collision.position.y=0.25
	add_child(collision)
	var cabin_collision := CollisionShape3D.new()
	var cabin_box := BoxShape3D.new()
	cabin_box.size=Vector3(1.65,1.3,1.95)
	cabin_collision.shape=cabin_box
	cabin_collision.position=Vector3(0,0.94,0.3)
	add_child(cabin_collision)
	add_child(BODY.instantiate())
	for point in WHEEL_POINTS:
		var ray := RayCast3D.new()
		ray.position=point
		ray.target_position=Vector3(0,-REST-RADIUS-0.2,0)
		ray.exclude_parent=true
		ray.enabled=true
		add_child(ray)
		rays.append(ray)
		var pivot := Node3D.new()
		pivot.position=point-Vector3.UP*REST
		add_child(pivot)
		pivot.add_child(WHEEL.instantiate())
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
	add_child(visual)
	visual.global_transform=Transform3D.IDENTITY

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if pending_reset:
		state.transform=Transform3D(Basis(Vector3.UP,reset_yaw),reset_position)
		state.linear_velocity=Vector3.ZERO
		state.angular_velocity=Vector3.ZERO
		pending_reset=false

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
	for i in rays.size():
		var ray := rays[i]
		ray.force_raycast_update()
		var travel := REST
		if ray.is_colliding():
			travel=ray.global_position.distance_to(ray.get_collision_point())-RADIUS
			if travel < REST:
				grounded_wheels+=1
				var normal := ray.get_collision_normal()
				var offset := ray.global_position-global_position
				var point_velocity := linear_velocity+angular_velocity.cross(offset)
				var spring := (REST-travel)*28000.0-point_velocity.dot(normal)*3200.0
				apply_force(normal*clampf(spring,0,22000),offset)
		wheels[i].position=WHEEL_POINTS[i]-Vector3.UP*clampf(travel,0.05,REST)
		wheels[i].rotation.y=lerp_angle(wheels[i].rotation.y,-steering*0.48 if i<2 else 0.0,delta*9)
		wheels[i].get_child(0).rotation.x=-wheel_spin
	surface_kind=world.surface_at(global_position) if is_instance_valid(world) else "dirt"
	var contact := grounded_wheels/4.0
	if grounded_wheels>0:
		var drive := 9800.0 if surface_kind!="water" else 5600.0
		var max_speed := 24.0 if throttle>=0 else 9.0
		if absf(speed)<max_speed or signf(speed)!=signf(throttle):
			apply_central_force(forward*throttle*drive*contact)
		var grip := 5.2 if surface_kind=="road" else 3.5
		if braking:
			grip*=0.3
		apply_central_force(-right*linear_velocity.dot(right)*mass*grip*contact)
		apply_central_force(-forward*speed*mass*(2.8 if braking else 0.11)*contact)
		if surface_kind=="water":
			apply_central_force(-linear_velocity*mass*0.65)
		var desired_yaw := -steering*1.25*clampf(speed/7.0,-1,1)
		apply_torque(Vector3.UP*(desired_yaw-angular_velocity.y)*mass*2.4*contact)
		# Gentle roll recovery keeps the arcade car controllable without steering in mid-air.
		apply_torque(global_basis.y.cross(Vector3.UP)*mass*3.0)
	wheel_spin+=speed*delta/RADIUS
	var speed_ratio := clampf(absf(speed)/24,0,1)
	engine_audio.pitch_scale=lerpf(engine_audio.pitch_scale,0.72+speed_ratio*1.25+absf(throttle)*0.16,delta*4)
	engine_audio.volume_db=lerpf(-25,-15,maxf(speed_ratio,absf(throttle)*0.45))
	gravel_audio.volume_db=lerpf(gravel_audio.volume_db,-25+speed_ratio*9 if grounded_wheels>0 and absf(speed)>1 and surface_kind=="dirt" else -65,delta*5)
	water_audio.volume_db=lerpf(water_audio.volume_db,-20+speed_ratio*6 if grounded_wheels>0 and absf(speed)>1 and surface_kind=="water" else -65,delta*5)
	dust.emitting=grounded_wheels>0 and absf(speed)>2 and surface_kind=="dirt"
	spray.emitting=grounded_wheels>0 and absf(speed)>1 and surface_kind=="water"
	impact_cooldown=maxf(0,impact_cooldown-delta)
	if (linear_velocity-previous_velocity).length()>3.5 and get_contact_count()>0 and impact_cooldown==0:
		impact_audio.volume_db=-14
		impact_audio.play()
		impact_cooldown=0.35
	previous_velocity=linear_velocity
	if grounded_wheels>1 and surface_kind=="dirt" and global_position.distance_to(last_mark)>0.65:
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
	for index in [2,3]:
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
