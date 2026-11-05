extends Node

# Curated routes use the same controls and physics as manual driving.
const ROUTES := [
	{"name":"AMBER DUNES", "map":0, "vehicle":"f150", "speed":10.0, "low":false, "points":[Vector2(265,-165),Vector2(300,-186),Vector2(340,-210)]},
	{"name":"PINEWOOD TRAIL", "map":0, "vehicle":"scout", "speed":6.0, "low":false, "points":[Vector2(-267.5,-140),Vector2(-275,-170),Vector2(-283.5,-204)]},
	{"name":"RUTTED BASIN", "map":0, "vehicle":"eq246", "speed":4.5, "low":true, "points":[Vector2(-80,145),Vector2(-80,175),Vector2(-80,205)]},
	{"name":"GRANITE GATE", "map":0, "vehicle":"wrangler", "speed":4.0, "low":true, "points":[Vector2(-521,-345),Vector2(-490,-345),Vector2(-460,-345)]},
	{"name":"CYPRESS MARSH", "map":0, "vehicle":"wc62", "speed":4.8, "low":true, "points":[Vector2(155,150),Vector2(177,180),Vector2(192,201)]},
	{"name":"SHELL COAST", "map":1, "vehicle":"pickup", "speed":9.0, "low":false, "points":[Vector2(-454,60),Vector2(-435,0),Vector2(-415,-65)]},
	{"name":"SILENT HARBOR", "map":1, "vehicle":"ridge", "speed":7.0, "low":false, "points":[Vector2(-260,-270),Vector2(-260,-210),Vector2(-260,-150)]},
	{"name":"WHITE CROWN", "map":2, "vehicle":"unimog", "speed":7.0, "low":true, "points":[Vector2(30,-323),Vector2(70,-354),Vector2(118,-390)]},
	{"name":"BLUE MIRROR", "map":2, "vehicle":"hauler", "speed":6.0, "low":false, "points":[Vector2(315,25),Vector2(330,-20),Vector2(350,-70)]},
	{"name":"HIGH MEADOW", "map":2, "vehicle":"hilux", "speed":10.0, "low":false, "points":[Vector2(235,212),Vector2(180,310),Vector2(95,260)]}
]
const CAMERA_SEQUENCE := [2,3,1,4]
var game: Node3D
var active := false
var transitioning := false
var route_index := -1
var point_index := 1
var elapsed := 0.0
var stuck_time := 0.0
var camera_index := -1
var completed_routes := 0
var recoveries := 0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	process_physics_priority=-1

func start() -> void:
	if active or transitioning:
		return
	active=true
	route_index=-1
	completed_routes=0
	recoveries=0
	advance()

func stop() -> void:
	active=false
	if is_instance_valid(game.car):
		game.car.autopilot_enabled=false
		game.car.autopilot_input=Vector2.ZERO
	game.demo_label.hide()
	game.demo_button.text="Start fullscreen driving demo"

func advance() -> void:
	if not active or transitioning:
		return
	transitioning=true
	game.car.autopilot_input=Vector2.ZERO
	route_index=(route_index+1)%ROUTES.size()
	var route: Dictionary=ROUTES[route_index]
	if game.map_index!=route.map:
		if not await game.switch_map(route.map):
			transitioning=false
			stop()
			return
	if not active or game.quitting:
		transitioning=false
		return
	for i in game.VEHICLES.SPECS.size():
		if game.VEHICLES.SPECS[i].id==route.vehicle:
			game.switch_vehicle(i)
			break
	var p: Vector2=route.points[0]
	var direction: Vector2=route.points[1]-p
	game.car.reset_to_start(Vector3(p.x,game.world.height_at(p.x,p.y)+1.8,p.y))
	game.car.reset_yaw=atan2(-direction.x,-direction.y)
	game.car.low_range=route.low
	game.car.autopilot_enabled=true
	point_index=1
	elapsed=0
	stuck_time=0
	camera_index=-1
	game.camera.set_mode(2)
	game.demo_label.text="AUTO TOUR  %02d / %02d  ·  %s\nF8 / WASD Take over  ·  C View  ·  F11 Fullscreen"%[route_index+1,ROUTES.size(),route.name]
	game.demo_label.visible=not game.hud_hidden
	game.demo_button.text="Stop demo and drive yourself"
	transitioning=false
	print("DEMO_ROUTE ",route_index+1," ",route.name," ",route.vehicle)

func _physics_process(delta: float) -> void:
	if not active or transitioning or game.changing_map or game.quitting:
		return
	elapsed+=delta
	var car: RigidBody3D=game.car
	if elapsed<1.5:
		return
	var route: Dictionary=ROUTES[route_index]
	var points: Array=route.points
	var p:=Vector2(car.position.x,car.position.z)
	if p.distance_to(points[point_index])<5.0:
		point_index+=1
		if point_index>=points.size():
			completed_routes+=1
			advance()
			return
	var speed: float=car.linear_velocity.dot(-car.global_basis.z)
	stuck_time=stuck_time+delta if absf(speed)<0.6 or car.global_basis.y.y<0.35 else 0.0
	if stuck_time>5.0 or elapsed>65.0:
		print("DEMO_RECOVERY ",route.name," position=",p," next=",points[point_index]," speed=",speed," elapsed=",elapsed)
		recoveries+=1
		advance()
		return
	var a: Vector2=points[point_index-1]
	var b: Vector2=points[point_index]
	var along:=Geometry2D.get_closest_point_to_segment(p,a,b)
	var lookahead:=clampf(absf(speed)*0.9,5.0,12.0)
	var target:=along.move_toward(b,lookahead)
	var offset:=target-p
	var forward:=Vector2(-car.global_basis.z.x,-car.global_basis.z.z).normalized()
	var angle:=atan2(forward.cross(offset),forward.dot(offset))
	var steer: float=atan(2.0*car.wheelbase*sin(angle)/maxf(offset.length(),2.0))/car.max_steer_angle
	steer=clampf(steer,-1,1)
	var target_speed: float=route.speed*clampf(1.0-absf(steer)*0.55,0.4,1.0)
	if point_index<points.size()-1:
		target_speed=minf(target_speed,lerpf(3.5,float(route.speed),clampf(p.distance_to(b)/20.0,0,1)))
	car.autopilot_input=Vector2(steer,clampf((target_speed-speed)*0.5,-0.5,1.0))
	var next_camera:=int((elapsed-1.5)/7.0)%CAMERA_SEQUENCE.size()
	if camera_index!=next_camera:
		camera_index=next_camera
		game.camera.set_mode(CAMERA_SEQUENCE[camera_index])
