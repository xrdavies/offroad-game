extends Node3D

const ROUTE_PATH := "res://assets/world/route.json"
const WATER_LEVEL := 0.72
const SIZE := Vector2(150,130)
var layout: Dictionary
var landmarks: Array = []
var road_points := PackedVector3Array()
var rng := RandomNumberGenerator.new()
var terrain_mesh: ArrayMesh
var models: Dictionary = {}

func _ready() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH))
	landmarks = layout.landmarks
	rng.seed = int(layout.seed)
	_build_road_curve()
	_build_terrain()
	_build_road()
	_build_river()
	_build_places()
	_build_scrap()
	_build_vegetation()
	_build_cliffs()
	_build_boundary()

func river_x(z: float) -> float:
	return 32.0 + 7.0 * sin(z * 0.025)

func height_at(x: float, z: float) -> float:
	var base := 2.1 + sin(x*0.065)*cos(z*0.052)*0.48
	base += 5.0 * exp(-pow((x-96.0)/33.0,2)-pow((z-8.0)/40.0,2))
	base += 3.5 * exp(-pow((x+15.0)/40.0,2)-pow((z+98.0)/27.0,2))
	var bank := smoothstep(3.5,12.0,abs(x-river_x(z)))
	base = lerpf(0.12,base,bank)
	var workshop := 1.0 - smoothstep(10.0,21.0,Vector2(x+14,z-5).length())
	base = lerpf(base,2.1,workshop)
	return base

func road_distance(point: Vector2) -> float:
	var result := INF
	for i in range(road_points.size()-1):
		var a := Vector2(road_points[i].x, road_points[i].z)
		var b := Vector2(road_points[i+1].x, road_points[i+1].z)
		result = minf(result,point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b)))
	return result

func surface_at(point: Vector3) -> String:
	if absf(point.x-river_x(point.z)) < 8.0 and point.y < WATER_LEVEL+1.0:
		return "water"
	if road_distance(Vector2(point.x,point.z)) < 3.5:
		return "road"
	return "dirt"

func _build_road_curve() -> void:
	var curve := Curve3D.new()
	var path: Array = layout.road
	for i in path.size():
		var p := Vector3(path[i][0],0,path[i][1])
		var before: Array = path[maxi(0,i-1)]
		var after: Array = path[mini(path.size()-1,i+1)]
		if i==0 or i==path.size()-1:
			before=path[path.size()-2]
			after=path[1]
		var tangent := Vector3(after[0]-before[0],0,after[1]-before[1])*0.17
		curve.add_point(p,-tangent,tangent)
	curve.bake_interval = 2.0
	road_points = curve.get_baked_points()

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-130,130,2):
		for x in range(-150,150,2):
			var a := Vector3(x,height_at(x,z),z)
			var b := Vector3(x+2,height_at(x+2,z),z)
			var c := Vector3(x+2,height_at(x+2,z+2),z+2)
			var d := Vector3(x,height_at(x,z+2),z+2)
			var color := Color("918970").lerp(Color("9b9076"),rng.randf()*0.45)
			if absf(x-river_x(z))<12:
				color = Color("6b7771").lerp(Color("8b8c78"),rng.randf())
			if x>77:
				color = color.lerp(Color("9f7662"),0.5)
			_tri(st,a,b,c,color)
			_tri(st,a,c,d,color)
	terrain_mesh = st.commit()
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = terrain_mesh
	var ground_material := ShaderMaterial.new()
	ground_material.shader=load("res://assets/ground.gdshader")
	terrain.material_override = ground_material
	add_child(terrain)
	terrain.create_trimesh_collision()

func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(road_points.size()-1):
		var p := road_points[i]
		var q := road_points[i+1]
		var right := _road_right(i)
		var next_right := _road_right(i+1)
		var a := p-right*3.8
		var b := p+right*3.8
		var c := q+next_right*3.8
		var d := q-next_right*3.8
		a.y=height_at(a.x,a.z)+0.09
		b.y=height_at(b.x,b.z)+0.09
		c.y=height_at(c.x,c.z)+0.09
		d.y=height_at(d.x,d.z)+0.09
		var color := Color("686c66").lightened(rng.randf()*0.045)
		_tri(st,a,d,c,color)
		_tri(st,a,c,b,color)
		if i%4==0 and absf(p.x-river_x(p.z))>12:
			var marking := _box(Vector3(p.x,height_at(p.x,p.z)+0.1,p.z),Vector3(0.12,0.02,1.6),Color("c2bda4"))
			marking.rotation.y = atan2(right.z,-right.x)
	var visual := MeshInstance3D.new()
	visual.mesh=st.commit()
	var road_material := ShaderMaterial.new()
	road_material.shader=load("res://assets/road.gdshader")
	visual.material_override=road_material
	add_child(visual)
	# Two river crossings keep the loop connected; the shallow ford is drivable.
	_build_bridge(Vector3(river_x(-57),2.36,-57),-0.34)
	_build_bridge(Vector3(river_x(36),2.36,36),0.04)

func _road_right(index: int) -> Vector3:
	var count := road_points.size()-1
	return (road_points[(index+1)%count]-road_points[posmod(index-1,count)]).normalized().cross(Vector3.UP)

func _build_bridge(center: Vector3, angle: float) -> void:
	var bridge := Node3D.new()
	bridge.position=center
	bridge.rotation.y=angle
	bridge.name="Bridge"
	add_child(bridge)
	for x in range(-16,17,4):
		_box(Vector3(x,-0.25,0),Vector3(4,0.5,8.0),Color("848782"),true,bridge)
		_box(Vector3(x,0.02,0),Vector3(1.7,0.02,0.12),Color("c2bda4"),false,bridge)
	for z in [-4.15,4.15]:
		_box(Vector3(0,0.4,z),Vector3(36,0.8,0.3),Color("b9b9a8"),true,bridge)
		for x in range(-16,17,4):
			_box(Vector3(x,0.9,z),Vector3(0.18,0.3,0.35),Color("777e77"),false,bridge)
	for x in [-8,0,8]:
		_box(Vector3(x,-1.5,0),Vector3(1,2.5,6.5),Color("757970"),true,bridge)
	for x in [-19.0,19.0]:
		var ramp := _box(Vector3(x,-0.34,0),Vector3(4,0.5,8),Color("848782"),true,bridge)
		ramp.rotation.z=-signf(x)*0.05

func _build_river() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-130,130,2):
		var a := Vector3(river_x(z)-7.4,WATER_LEVEL,z)
		var b := Vector3(river_x(z)+7.4,WATER_LEVEL,z)
		var c := Vector3(river_x(z+2)+7.4,WATER_LEVEL,z+2)
		var d := Vector3(river_x(z+2)-7.4,WATER_LEVEL,z+2)
		_tri(st,a,b,c,Color("426d6c"))
		_tri(st,a,c,d,Color("426d6c"))
	var water := MeshInstance3D.new()
	water.mesh=st.commit()
	var material := ShaderMaterial.new()
	material.shader=load("res://assets/water.gdshader")
	water.material_override=material
	add_child(water)
	var foam: Array[Transform3D]=[]
	for i in 550:
		var z := rng.randf_range(-128,128)
		var x := river_x(z)+rng.randf_range(-7.3,7.3)
		if height_at(x,z)>WATER_LEVEL-0.1:
			continue
		foam.append(Transform3D(Basis.IDENTITY.scaled(Vector3(rng.randf_range(0.2,1.3),0.015,0.07)),Vector3(x,WATER_LEVEL+0.025,z)))
	_multimesh(foam,BoxMesh.new(),Color("9db7a8"))

func _build_places() -> void:
	for data in landmarks:
		var pos := Vector3(data.position[0],0,data.position[1])
		_asset(data.model,pos,data.rotation)
	for x in [-20.0,-16.0]:
		_asset("fuel_pump",Vector3(x,0,14))
	for pos in [Vector3(-24,0,0),Vector3(-23,0,-2),Vector3(-21,0,-1),Vector3(-8,0,-2)]:
		_asset("barrel",pos)
	for pos in [Vector3(-7,0,12),Vector3(-6,0,13),Vector3(-24,0,13)]:
		_asset("barrel",pos)
	_asset("wreck_2",Vector3(-6,0,19),-0.3)
	for x in [-27.0,-24.0]:
		_asset("barrier",Vector3(x,0,19))
	# A freestanding enamel sign remains legible above the service canopy.
	_box(Vector3(-24,4.1,10),Vector3(0.16,4,0.16),Color("5c625a"),true)
	_box(Vector3(-24,6.2,10),Vector3(3.1,1.5,0.16),Color("7a4f43"))
	_label("FUEL\n& REPAIR",Vector3(-24,6.2,10.1),0.018)
	_asset("container",Vector3(-30,0,-9),0.1)
	_asset("container",Vector3(-67,0,-47),1.6)
	for x in range(-36,-3,5):
		_asset("fence",Vector3(x,0,-11))
	for x in range(-80,-45,5):
		_asset("fence",Vector3(x,0,-44))
	for z in range(-35,60,20):
		_asset("utility_pole",Vector3(-45,0,z))
		if z<45:
			for dx in [-1.35,1.35]:
				var prev := Vector3(-45+dx,height_at(-45,z)+7.65,z)
				for j in range(1,11):
					var t := j/10.0
					var next := Vector3(-45+dx,lerpf(height_at(-45,z),height_at(-45,z+20),t)+7.65-sin(t*PI)*0.8,z+t*20)
					_beam(prev,next,0.025,Color("494e4b"))
					prev=next
	for z in range(-36,16,6):
		_asset("barrier",Vector3(75,0,z),PI/2)
	_label("DUSTLINE  /  SERVICE",Vector3(-14,5.65,9.86),0.019)
	_label("MOTOR YARD",Vector3(-63,height_at(-63,-44)+3,-44),0.03)

func _build_scrap() -> void:
	for i in 63:
		var x := -82.0+(i%7)*5.3+rng.randf_range(-0.3,0.3)
		var z := -38.0+floori(i/7.0)*6.2+rng.randf_range(-0.35,0.35)
		if absf(x+65)<3 or absf(z+12)<3:
			continue
		var wreck := _asset("wreck_%d"%(i%3),Vector3(x,0,z),rng.randf_range(-0.18,0.18)+PI/2)
		wreck.rotation.z=rng.randf_range(-0.07,0.07)
	for p in [Vector3(-30,0,23),Vector3(12,0,-70),Vector3(66,0,-44),Vector3(48,0,48),Vector3(-9,0,-35)]:
		_asset("wreck_1",p,rng.randf_range(0,TAU))
	var scrap: Array[Transform3D]=[]
	for i in 3400:
		var center: Vector2 = [Vector2(-88,-24),Vector2(-61,29),Vector2(77,-73)][i%3]
		var offset := Vector2(rng.randfn(0,8.0),rng.randfn(0,9.0))
		var p := center+offset
		var h := maxf(0,3.4-offset.length()*0.18)*rng.randf()
		var basis := Basis.from_euler(Vector3(rng.randf(),rng.randf()*TAU,rng.randf()))
		basis=basis.scaled(Vector3(rng.randf_range(0.15,0.9),rng.randf_range(0.1,0.55),rng.randf_range(0.15,1.2)))
		scrap.append(Transform3D(basis,Vector3(p.x,height_at(p.x,p.y)+h,p.y)))
	_multimesh(scrap,BoxMesh.new(),Color("87867b"),true,[Color("9e9e91"),Color("7c9390"),Color("936d5d"),Color("b2a68a"),Color("606c69"),Color("a2a59e")])
	for p in [Vector3(-88,0,-24),Vector3(-61,0,29),Vector3(77,0,-73)]:
		var body := StaticBody3D.new()
		body.position=Vector3(p.x,height_at(p.x,p.z)-1,p.z)
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius=6.0
		shape.shape=sphere
		body.add_child(shape)
		add_child(body)

func _build_vegetation() -> void:
	var grass: Array[Transform3D]=[]
	var pebbles: Array[Transform3D]=[]
	for i in 58000:
		var x := rng.randf_range(-140,140)
		var z := rng.randf_range(-120,120)
		var y := height_at(x,z)
		if y<WATER_LEVEL or road_distance(Vector2(x,z))<4.5 or Vector2(x+14,z-5).length()<12:
			continue
		if i%3==0:
			pebbles.append(Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled(Vector3(rng.randf_range(0.08,0.4),0.06,rng.randf_range(0.08,0.4))),Vector3(x,y+0.02,z)))
		else:
			var s := rng.randf_range(0.4,1.1)
			grass.append(Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled(Vector3(s,s,s)),Vector3(x,y,z)))
	var tuft := SurfaceTool.new()
	tuft.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var x := sin(i*4.3)*0.22
		var z := cos(i*3.1)*0.22
		var a := Vector3(x-0.04,0,z)
		var b := Vector3(x+0.05,0,z)
		var c := Vector3(x+sin(i)*0.17,0.3+(i%3)*0.12,z+0.12)
		_tri(tuft,a,b,c,Color.WHITE)
	_multimesh(grass,tuft.commit(),Color("b1a46e"),true)
	_multimesh(pebbles,BoxMesh.new(),Color("b4ad94"),true)
	for i in 55:
		var x := rng.randf_range(-100,110)
		var z := rng.randf_range(-110,100)
		if road_distance(Vector2(x,z))<9 or height_at(x,z)<WATER_LEVEL or Vector2(x+14,z-5).length()<18:
			continue
		var palm := _asset("palm",Vector3(x,0,z),rng.randf()*TAU)
		palm.scale=Vector3.ONE*rng.randf_range(0.75,1.2)

func _build_cliffs() -> void:
	for data in [[Vector2(-115,-54),Vector2(15,18),7],[Vector2(100,-35),Vector2(16,12),8],[Vector2(-40,-104),Vector2(14,10),7],[Vector2(87,44),Vector2(20,14),8]]:
		var center: Vector2=data[0]
		var extent: Vector2=data[1]
		for level in int(data[2]):
			var mesh := CylinderMesh.new()
			mesh.radial_segments=7
			mesh.top_radius=1.0-level*0.065
			mesh.bottom_radius=1.06-level*0.065
			mesh.height=0.9
			var visual := MeshInstance3D.new()
			visual.mesh=mesh
			visual.scale=Vector3(extent.x,1,extent.y)
			visual.position=Vector3(center.x,height_at(center.x,center.y)+level*0.85,center.y)
			visual.material_override=_material(Color("827d6b").lightened((level%3)*0.06))
			add_child(visual)
			visual.create_trimesh_collision()

func _build_boundary() -> void:
	# Visible stepped escarpments explain the edge of the drivable survey area.
	for x in [-148,148]:
		for z in range(-130,131,13):
			var y := height_at(x,z)
			_box(Vector3(x,y+2.5,z),Vector3(7,5,13.2),Color("797c69"),true)
			_box(Vector3(x,y+6,z),Vector3(5,2+rng.randf(),12.8),Color("93917b"),true)
	for z in [-128,128]:
		for x in range(-145,146,13):
			var y := height_at(x,z)
			_box(Vector3(x,y+2.5,z),Vector3(13.2,5,7),Color("797c69"),true)
			_box(Vector3(x,y+6,z),Vector3(12.8,2+rng.randf(),5),Color("93917b"),true)

func _asset(id: String, pos: Vector3, angle := 0.0) -> Node3D:
	if not models.has(id):
		models[id]=load("res://assets/models/"+id+".tscn")
	var instance: Node3D=models[id].instantiate()
	instance.position=Vector3(pos.x,height_at(pos.x,pos.z)+pos.y,pos.z)
	instance.rotation.y=angle
	add_child(instance)
	return instance

func _box(pos: Vector3, size: Vector3, color: Color, solid := false, parent: Node3D = self) -> Node3D:
	var node := Node3D.new()
	node.position=pos
	parent.add_child(node)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	visual.material_override=_material(color)
	node.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size=size
		shape.shape=box
		body.add_child(shape)
		node.add_child(body)
	return node

func _beam(a: Vector3,b: Vector3,width: float,color: Color) -> void:
	var beam := _box((a+b)*0.5,Vector3(width,width,a.distance_to(b)),color)
	beam.look_at(b)

func _label(words: String,pos: Vector3,pixel_size: float) -> void:
	var label := Label3D.new()
	label.text=words
	label.font_size=38
	label.pixel_size=pixel_size
	label.modulate=Color("ece2bf")
	label.outline_modulate=Color("303f3d")
	label.outline_size=7
	label.position=pos
	add_child(label)

func _multimesh(transforms: Array[Transform3D], mesh: Mesh, color: Color, varied := false, colors: Array[Color]=[]) -> void:
	var batch := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=mesh
	multi.instance_count=transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i,transforms[i])
		var tint := colors[i%colors.size()] if not colors.is_empty() else color
		multi.set_instance_color(i,(tint.lightened(rng.randf_range(-0.15,0.12)) if varied else tint).srgb_to_linear())
	batch.multimesh=multi
	batch.material_override=_vertex_material()
	batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)

func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	for point in [a,b,c]:
		st.set_normal(normal)
		st.set_color(color.srgb_to_linear())
		st.add_vertex(point)

func _vertex_material() -> StandardMaterial3D:
	var material := _material(Color.WHITE)
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=false
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	return material

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.92
	return material
