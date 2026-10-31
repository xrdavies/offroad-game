extends Control
var world: Node3D
var car: Node3D
var journal: Array[String]

func _point(pos: Vector2) -> Vector2:
	return (pos/Vector2(300,260)+Vector2(0.5,0.5))*size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("343f38"))
	for x in range(0,301,20):
		draw_line(Vector2(x/300.0*size.x,0),Vector2(x/300.0*size.x,size.y),Color(0.7,0.7,0.5,0.08))
	for z in range(0,261,20):
		draw_line(Vector2(0,z/260.0*size.y),Vector2(size.x,z/260.0*size.y),Color(0.7,0.7,0.5,0.08))
	var water := PackedVector2Array()
	for z in range(-130,131,5):
		water.append(_point(Vector2(world.river_x(z)-6.5-world.river_widening(z),z)))
	for z in range(130,-131,-5):
		water.append(_point(Vector2(world.river_x(z)+6.5+world.river_widening(z),z)))
	draw_colored_polygon(water,Color("658681"))
	var road := PackedVector2Array()
	for p in world.road_points:
		road.append(_point(Vector2(p.x,p.z)))
	draw_polyline(road,Color("b6b093"),3,true)
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
