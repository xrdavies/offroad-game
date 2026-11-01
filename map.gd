extends Control
signal destination_selected(point: Vector2)
var waypoint := Vector2.INF
var world: Node3D
var car: Node3D
var journal: Array[String]

func _point(pos: Vector2) -> Vector2:
	return (pos/(world.SIZE*2)+Vector2(0.5,0.5))*size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("343f38"))
	for x in range(0,301,20):
		draw_line(Vector2(x/300.0*size.x,0),Vector2(x/300.0*size.x,size.y),Color(0.7,0.7,0.5,0.08))
	for z in range(0,261,20):
		draw_line(Vector2(0,z/260.0*size.y),Vector2(size.x,z/260.0*size.y),Color(0.7,0.7,0.5,0.08))
	for zone in world.REGIONS.ZONES:
		draw_circle(_point(zone.center),zone.radius/(world.SIZE.x*2)*size.x,Color(zone.color,0.3))
	var water := PackedVector2Array()
	for z in range(-int(world.SIZE.y),int(world.SIZE.y)+1,5):
		water.append(_point(Vector2(world.river_x(z)-6.5-world.river_widening(z),z)))
	for z in range(int(world.SIZE.y),-int(world.SIZE.y)-1,-5):
		water.append(_point(Vector2(world.river_x(z)+6.5+world.river_widening(z),z)))
	draw_colored_polygon(water,Color("658681"))
	if world.map_index==1:
		var sea := PackedVector2Array([Vector2.ZERO,Vector2(0,size.y)])
		for z in range(int(world.SIZE.y),-int(world.SIZE.y)-1,-10):
			sea.append(_point(Vector2(world.coast_x(z),z)))
		draw_colored_polygon(sea,Color("567c87"))
	for lake in world.REGIONS.lakes:
		var outline := PackedVector2Array()
		for i in 64:
			var point: Vector2=lake.center+Vector2(cos(i*TAU/64),sin(i*TAU/64))*lake.radius*0.9
			outline.append(_point(point))
		draw_colored_polygon(outline,Color("acced6") if lake.frozen else Color("658681"))
	var road := PackedVector2Array()
	for p in world.road_points:
		road.append(_point(Vector2(p.x,p.z)))
	draw_polyline(road,Color("b6b093"),3,true)
	for zone in world.REGIONS.ZONES:
		draw_string(ThemeDB.fallback_font,_point(zone.center)+Vector2(-35,20),zone.id.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("d3d2b8"))
	for trail in world.REGIONS.TRAILS:
		for i in range(trail.size()-1):
			draw_dashed_line(_point(trail[i]),_point(trail[i+1]),Color("a5a17c"),1.5,4)
	if waypoint!=Vector2.INF:
		draw_circle(_point(waypoint),8,Color("e8ac66"),false,2)
		draw_line(_point(waypoint)-Vector2(11,0),_point(waypoint)+Vector2(11,0),Color("e8ac66"),1)
	for place in world.landmarks:
		var p := _point(Vector2(place.position[0],place.position[1]))
		var found := journal.has(place.id)
		draw_circle(p,5,Color("e5cf8a") if found else Color("7e897b"))
		if found:
			draw_string(ThemeDB.fallback_font,p+Vector2(8,-6),place.name,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e0dac1"))
	var player := _point(Vector2(car.global_position.x,car.global_position.z))
	var facing := Vector2(-sin(car.rotation.y),-cos(car.rotation.y))
	var side := facing.orthogonal()
	draw_colored_polygon(PackedVector2Array([player+facing*9,player-facing*6+side*5,player-facing*6-side*5]),Color("faf0c9"))
	draw_string(ThemeDB.fallback_font,Vector2(size.x-40,24),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e0dac1"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		destination_selected.emit((event.position/size-Vector2(0.5,0.5))*world.SIZE*2)
		accept_event()
