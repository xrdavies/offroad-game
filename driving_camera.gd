extends Camera3D

const MODES := ["SURVEY", "COCKPIT", "CHASE", "SIDE TRACK", "DRONE"]
var car: RigidBody3D
var world: Node3D
var mode := 0
var zoom := 24.0
var look := Vector2.ZERO
var snap := true
var director := false
var director_time := 0.0
var allow_look := true

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	near=0.07
	far=650
	current=true

func set_mode(value: int) -> void:
	mode=posmod(value,MODES.size())
	look=Vector2.ZERO
	snap=true

func _unhandled_input(event: InputEvent) -> void:
	if not allow_look or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		look.x=clampf(look.x-event.relative.x*0.003,-1.45,1.45)
		look.y=clampf(look.y-event.relative.y*0.003,-0.45,0.5)

func _process(delta: float) -> void:
	if not is_instance_valid(car) or get_tree().paused:
		return
	if director:
		director_time+=delta
		var next: int=[2,3,4][int(director_time/8)%3]
		if next!=mode:
			set_mode(next)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		look=look.lerp(Vector2.ZERO,1-exp(-delta*4))
	var tr := car.get_global_transform_interpolated()
	set_cull_mask_value(2,mode!=1)
	if mode==1:
		projection=Camera3D.PROJECTION_PERSPECTIVE
		fov=78
		global_transform=tr*Transform3D(Basis.from_euler(Vector3(look.y-0.12,look.x,0)),car.spec.seat)
		snap=false
		return
	var target := tr.origin+Vector3.UP*0.9
	var desired: Vector3
	projection=Camera3D.PROJECTION_ORTHOGONAL if mode==0 else Camera3D.PROJECTION_PERSPECTIVE
	fov=62 if mode==3 else 68
	size=zoom
	match mode:
		0: desired=target+Vector3(30,34,33)
		2: desired=target+tr.basis*Vector3(sin(look.x)*8,3.4+look.y*3,car.spec.length*1.05+4)
		3: desired=target+tr.basis*Vector3(9,2.7,1)
		_: desired=target+Vector3(18,25,18)
	var blend := 1.0 if snap else 1-exp(-delta*6)
	var candidate := global_position.lerp(desired,blend)
	if mode!=0:
		candidate.y=maxf(candidate.y,world.height_at(candidate.x,candidate.z)+1.2)
		var query := PhysicsRayQueryParameters3D.create(target,candidate,1,[car.get_rid()])
		var hit := car.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			candidate=hit.position+hit.normal*0.35
	global_position=candidate
	look_at(target if mode!=0 else global_position-Vector3(30,34,33))
	snap=false
