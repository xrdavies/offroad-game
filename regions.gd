extends RefCounted

const SIZE := preload("res://maps.gd").SIZE
const ORIGINAL_ZONES := [
	{"id":"forest", "name":"PINEWOOD TRAIL", "center":Vector2(-265,-130), "radius":110.0, "color":Color("74806a"), "surface":"forest"},
	{"id":"mountain", "name":"HIGH RIDGE PASS", "center":Vector2(-225,-280), "radius":105.0, "color":Color("95918b"), "surface":"rock"},
	{"id":"desert", "name":"AMBER DUNES", "center":Vector2(265,-165), "radius":150.0, "color":Color("c4a378"), "surface":"sand"},
	{"id":"grassland", "name":"WINDGRASS PLAINS", "center":Vector2(-260,220), "radius":135.0, "color":Color("929b63"), "surface":"grass"},
	{"id":"mud", "name":"RUTTED BASIN", "center":Vector2(-80,210), "radius":72.0, "color":Color("6f6051"), "surface":"mud"},
	{"id":"swamp", "name":"CYPRESS MARSH", "center":Vector2(195,205), "radius":110.0, "color":Color("6c7b64"), "surface":"swamp"}
]
const ORIGINAL_TRAILS := [
	[Vector2(-38,-28),Vector2(-95,-80),Vector2(-175,-120),Vector2(-265,-130),Vector2(-285,-210),Vector2(-250,-245),Vector2(-225,-280)],
	[Vector2(-12,40),Vector2(-50,100),Vector2(-80,155),Vector2(-80,210),Vector2(-170,230),Vector2(-260,220)],
	[Vector2(62,10),Vector2(115,85),Vector2(155,150),Vector2(195,205),Vector2(260,250)],
	[Vector2(65,-30),Vector2(135,-80),Vector2(210,-120),Vector2(265,-165),Vector2(340,-210)],
	[Vector2(-260,220),Vector2(-340,130),Vector2(-345,20),Vector2(-320,-65),Vector2(-265,-130)]
]

var map_index := 0
var ZONES: Array = ORIGINAL_ZONES.duplicate(true)
var TRAILS: Array = ORIGINAL_TRAILS.duplicate(true)
var lakes: Array = []

func _zone(id: String, title: String, center: Vector2, radius: float, color: String, surface: String) -> Dictionary:
	return {"id":id,"name":title,"center":center,"radius":radius,"color":Color(color),"surface":surface}

func configure(index: int) -> void:
	map_index=index
	ZONES=ORIGINAL_ZONES.duplicate(true)
	TRAILS=ORIGINAL_TRAILS.duplicate(true)
	lakes=[]
	match index:
		0:
			ZONES.append_array([
				_zone("gobi","STONEWIND PLATEAU",Vector2(490,310),150,"a69a7e","gobi"),
				_zone("ruins","LOST CITY",Vector2(-520,80),110,"8c8d84","dirt"),
				_zone("crawl","GRANITE GATE",Vector2(-490,-340),110,"93968c","rock")])
			lakes=[{"center":Vector2(-445,400),"radius":Vector2(85,60),"name":"REED LAKE","frozen":false}]
			TRAILS.append_array([
				[Vector2(-265,-130),Vector2(-390,-185),Vector2(-490,-340)],
				[Vector2(-345,20),Vector2(-440,75),Vector2(-520,80),Vector2(-535,250),Vector2(-445,310),Vector2(-260,220)],
				[Vector2(260,250),Vector2(390,285),Vector2(490,310),Vector2(560,95),Vector2(340,-210)]])
		1:
			ZONES=[
				_zone("ruins","SILENT HARBOR",Vector2(-260,-210),145,"999b91","dirt"),
				_zone("beach","SHELL COAST",Vector2(-460,80),125,"c8ba91","sand"),
				_zone("desert","SUNFALL DUNES",Vector2(290,-260),210,"c9aa78","sand"),
				_zone("gobi","RED STONE FLATS",Vector2(380,220),170,"a4947c","gobi"),
				_zone("swamp","TIDAL MARSH",Vector2(-190,330),130,"7a8966","swamp"),
				_zone("grassland","COASTAL MEADOW",Vector2(20,150),140,"8d9b6c","grass")]
			lakes=[{"center":Vector2(150,390),"radius":Vector2(80,55),"name":"OASIS LAKE","frozen":false}]
			TRAILS=[
				[Vector2(0,70),Vector2(-120,40),Vector2(-380,55),Vector2(-460,80),Vector2(-405,-100),Vector2(-260,-210),Vector2(-80,-280)],
				[Vector2(0,70),Vector2(110,-60),Vector2(290,-260),Vector2(490,-170),Vector2(510,60),Vector2(380,220),Vector2(240,300),Vector2(20,150),Vector2(0,70)],
				[Vector2(-380,55),Vector2(-350,200),Vector2(-190,330),Vector2(-20,330),Vector2(20,150)]]
		2:
			ZONES=[
				_zone("forest","FROST PINE VALLEY",Vector2(-270,80),190,"7e9584","forest"),
				_zone("grassland","HIGH MEADOW",Vector2(180,310),190,"9da57e","grass"),
				_zone("mountain","EAGLE PASS",Vector2(30,-180),150,"9eaaa7","rock"),
				_zone("snow","WHITE CROWN",Vector2(130,-400),195,"e2e8df","snow"),
				_zone("crawl","BROKEN RIDGE",Vector2(-310,-270),130,"9ca49d","rock"),
				_zone("ice","BLUE MIRROR",Vector2(330,-20),110,"a1c5d1","ice")]
			lakes=[{"center":Vector2(-400,370),"radius":Vector2(100,65),"name":"GLACIER LAKE","frozen":false}, {"center":Vector2(330,-20),"radius":Vector2(80,60),"name":"FROZEN LAKE","frozen":true}]
			TRAILS=[
				[Vector2(-80,160),Vector2(-270,80),Vector2(-380,-70),Vector2(-310,-270),Vector2(-140,-250),Vector2(30,-180)],
				[Vector2(30,-180),Vector2(0,-300),Vector2(130,-400),Vector2(270,-300),Vector2(390,-170),Vector2(330,-20),Vector2(270,150),Vector2(180,310),Vector2(-80,160)],
				[Vector2(-270,80),Vector2(-370,200),Vector2(-400,270),Vector2(-230,340),Vector2(-80,160)]]

func zone_at(p: Vector2) -> Dictionary:
	var best := 1.0
	var result: Dictionary={}
	for zone in ZONES:
		var distance: float=p.distance_to(zone.center)/zone.radius
		if distance<best:
			best=distance
			result=zone
	return result

func weight(p: Vector2, zone: Dictionary) -> float:
	return 1.0-smoothstep(0.45,1.15,p.distance_to(zone.center)/zone.radius)

func height(x: float,z: float,base: float) -> float:
	var p := Vector2(x,z)
	var original := (smoothstep(125,175,absf(x)) if absf(z)<105 else maxf(smoothstep(105,155,absf(z)),smoothstep(125,175,absf(x)))) if map_index==0 else 1.0
	var h := base
	for zone in ZONES:
		var blend := weight(p,zone)*original
		if blend<=0:
			continue
		var target := base
		match zone.id:
			"forest": target=3.5+sin(x*0.035)*cos(z*0.025)*2.2
			"mountain": target=5+26*exp(-pow((x-zone.center.x)/65,2)-pow((z-zone.center.y)/65,2))+sin(x*0.07+z*0.025)*1.4
			"desert": target=4+pow(0.5+0.5*sin(x*0.055+sin(z*0.022)*2),2)*6+sin(z*0.03)*1.2
			"grassland": target=3+sin(x*0.025)*cos(z*0.027)*2
			"mud": target=1.7+sin(x*0.8)*cos(z*0.11)*0.11+sin(z*0.07)*0.25
			"swamp": target=0.42+sin(x*0.055)*cos(z*0.05)*0.45
			"gobi": target=5+sin(x*0.023)*cos(z*0.018)*2.5+sin(x*0.45+z*0.27)*0.12
			"beach": target=1.4+sin(z*0.04)*0.2
			"ruins": target=3.0+sin(x*0.01)*0.15
			"crawl": target=7+sin((x-zone.center.x)*0.09)*0.9+sin(z*0.13)*0.5
			"snow": target=24+32*exp(-pow((x-zone.center.x)/120,2)-pow((z-zone.center.y)/130,2))+sin(x*0.04+z*0.03)*1.4
			"ice": target=1.0+sin(x*0.04)*0.12
		h=lerpf(h,target,blend)
	return h

func trail_distance(p: Vector2) -> float:
	var distance := INF
	for trail in TRAILS:
		for i in range(trail.size()-1):
			distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,trail[i],trail[i+1])))
	return distance

func build(world: Node3D) -> void:
	_build_trails(world)
	var trunks: Array[Transform3D]=[]
	var crowns: Array[Transform3D]=[]
	var crown_colors: Array[Color]=[]
	var rocks: Array[Transform3D]=[]
	var grasses: Array[Transform3D]=[]
	var grass_colors: Array[Color]=[]
	var rng: RandomNumberGenerator=world.rng
	var rock_mesh := _rock_mesh()
	var rock_shape := rock_mesh.create_convex_shape()
	for zone in ZONES:
		for i in (550 if zone.id=="forest" and zone.radius>150 else 230):
			var p: Vector2=zone.center+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))*zone.radius
			if p.distance_to(zone.center)>zone.radius or trail_distance(p)<5 or p.distance_to(zone.center)<9:
				continue
			var y: float=world.height_at(p.x,p.y)
			if zone.id in ["forest","swamp"] or (zone.id=="grassland" and i%15==0) or (zone.id=="snow" and i%5==0):
				var h := rng.randf_range(4,8)
				trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.38,h,0.38)),Vector3(p.x,y+h/2,p.y)))
				for layer in 4:
					var wide := (4-layer*0.55)*(0.7+h/12)
					crowns.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(wide,2.4,wide)),Vector3(p.x,y+h-2+layer*0.65,p.y)))
					crown_colors.append(Color("dce3d8") if map_index==2 and (zone.id=="snow" or layer>=2) else Color("526953") if zone.id=="forest" else Color("7e8e69"))
				var body := StaticBody3D.new()
				var shape := CollisionShape3D.new()
				var cylinder := CylinderShape3D.new()
				cylinder.radius=0.25
				cylinder.height=h
				shape.shape=cylinder
				body.add_child(shape)
				world.add_child(body)
				body.position=Vector3(p.x,y+h/2,p.y)
			elif zone.id in ["mountain","desert","gobi","crawl","snow","beach"]:
				var s := rng.randf_range(0.5,2.2)
				var basis := Basis(Vector3.UP,rng.randf()*TAU)
				rocks.append(Transform3D(basis.scaled(Vector3(s*1.4,s,s)),Vector3(p.x,y+s*0.3,p.y)))
				var body := StaticBody3D.new()
				var collision := CollisionShape3D.new()
				collision.shape=rock_shape
				body.add_child(collision)
				world.add_child(body)
				body.transform=Transform3D(basis.scaled(Vector3(s*1.4,s,s)),Vector3(p.x,y+s*0.3,p.y))
		for i in (0 if zone.id=="ice" else 1500 if zone.id in ["snow","ruins","beach"] else 12000):
			var p: Vector2=zone.center+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))*zone.radius
			if p.distance_to(zone.center)>zone.radius or trail_distance(p)<3 or p.distance_to(zone.center)<7:
				continue
			if zone.id in ["desert","mountain","gobi","crawl"] and i%12!=0:
				continue
			var scale_value := rng.randf_range(0.7,1.7)
			var y: float=world.height_at(p.x,p.y)
			if y<world.WATER_LEVEL and zone.id!="swamp":
				continue
			grasses.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(scale_value,scale_value*(2 if zone.id=="swamp" else 1),scale_value)),Vector3(p.x,y,p.y)))
			grass_colors.append(Color("8e9e5e") if zone.id=="grassland" else Color("a5a16e"))
		var c: Vector2=zone.center
		world._asset("container" if zone.id in ["forest","desert"] else "utility_pole",Vector3(c.x+9,0,c.y+4),0.3)
		world._asset("barrel",Vector3(c.x+6,0,c.y+6))
		world._box(Vector3(c.x+5,world.height_at(c.x+5,c.y)+1.8,c.y),Vector3(0.12,3.6,0.12),Color("65695a"),true)
		world._box(Vector3(c.x+5,world.height_at(c.x+5,c.y)+3.5,c.y),Vector3(5,0.85,0.14),Color("596456"))
		world._label(zone.name,Vector3(c.x+5,world.height_at(c.x+5,c.y)+3.5,c.y+0.09),0.011)
		if zone.id=="ruins":
			_build_ruins(world,c)
		if zone.id=="crawl":
			_build_crawl(world,c)
		if zone.id=="forest":
			for pile in 3:
				for j in range(3-pile):
					world._box(Vector3(c.x-12+j*0.8+pile*0.3,world.height_at(c.x-12,c.y+7)+0.4+pile*0.7,c.y+7),Vector3(0.7,0.65,6),Color("82715b"),true)
			world._asset("wreck_3",Vector3(c.x-13,0,c.y+15),0.8)
		if zone.id=="desert":
			world._asset("water_tank",Vector3(c.x+17,0,c.y-15))
			world._asset("wreck_2",Vector3(c.x-14,0,c.y+11),1.5)
			for j in 5:
				var p := Vector2(c.x+18+j*4,c.y+14)
				var panel: Node3D=world._box(Vector3(p.x,world.height_at(p.x,p.y)+1.6,p.y),Vector3(3,0.14,2),Color("516371"),true)
				panel.rotation.x=0.35
				world._box(Vector3(p.x,world.height_at(p.x,p.y)+0.8,p.y),Vector3(0.16,1.6,0.16),Color("73756a"))
		if zone.id=="grassland":
			world._asset("garage",Vector3(c.x+22,0,c.y-14),-0.4)
			for j in 3:
				world._asset("fence",Vector3(c.x+10+j*5,0,c.y+14))
		if zone.id=="mud":
			world._asset("wreck_4",Vector3(c.x+13,-0.35,c.y+10),0.3)
			for j in 4:
				world._asset("barrier",Vector3(c.x-10,0,c.y-8+j*5),PI/2)
		if zone.id=="mountain":
			world._asset("relay",Vector3(c.x+13,0,c.y-8))
		if zone.id=="swamp":
			for j in 9:
				world._box(Vector3(c.x+8+j*1.2,1.05,c.y+10),Vector3(1.15,0.22,3),Color("a29677"),true)
	var foliage := SurfaceTool.new()
	foliage.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var block := BoxMesh.new()
		block.size=Vector3(0.55,0.3,0.55)
		foliage.append_from(block,0,Transform3D(Basis(Vector3.UP,sin(i*3.4)*0.12),Vector3(sin(i*2.4)*0.3,sin(i*2.1)*0.2,cos(i*3.1)*0.3)))
	var canopy: Mesh = foliage.commit()
	world._multimesh(trunks,BoxMesh.new(),Color("706653"),true)
	if map_index==2:
		var cone := CylinderMesh.new()
		cone.top_radius=0.03
		cone.bottom_radius=0.55
		cone.height=1.0
		cone.radial_segments=8
		canopy=cone
	world._multimesh(crowns,canopy,Color.WHITE,true,crown_colors)
	world._multimesh(rocks,rock_mesh,Color("a8b4b2") if map_index==2 else Color("918a78"),true)
	world._multimesh(grasses,world.grass_mesh,Color.WHITE,true,grass_colors)
	_build_lakes(world)
	# Rocky steps and alternating log humps provide deliberate suspension obstacles.
	for i in (8 if map_index==0 else 0):
		var p := Vector2(-145-i*4,230)
		world._box(Vector3(p.x,world.height_at(p.x,p.y)+0.1,p.y),Vector3(0.5,0.2+(i%3)*0.06,5),Color("7e735d"),true)

func _build_trails(world: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for trail in TRAILS:
		for i in range(trail.size()-1):
			var a: Vector2=trail[i]
			var b: Vector2=trail[i+1]
			var side := (b-a).normalized().orthogonal()
			var segments := ceili(a.distance_to(b)/2)
			for j in segments:
				var p := a.lerp(b,float(j)/segments)
				var q := a.lerp(b,float(j+1)/segments)
				for offset in [-1.05,1.05]:
					var points: Array[Vector3]=[]
					for v in [p+side*(offset-0.34),p+side*(offset+0.34),q+side*(offset+0.34),q+side*(offset-0.34)]:
						points.append(Vector3(v.x,world.height_at(v.x,v.y)+0.055,v.y))
					var surface: String=zone_at(p).get("surface","")
					var color := Color("b8c6c7") if surface=="ice" else Color("c2c9c4") if surface=="snow" else Color("786c56")
					world._tri(st,points[0],points[1],points[2],color)
					world._tri(st,points[0],points[2],points[3],color)
			if i>0:
				world._asset("barrel",Vector3(a.x+side.x*4,0,a.y+side.y*4))
	var mesh := MeshInstance3D.new()
	mesh.mesh=st.commit()
	var material := ShaderMaterial.new()
	material.shader=load("res://assets/ground.gdshader")
	mesh.material_override=material
	world.add_child(mesh)

func _rock_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius=0.5
	sphere.height=1
	sphere.radial_segments=9
	sphere.rings=5
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var p := vertices[i]
		vertices[i]*=1+0.14*sin(p.x*19+p.y*13+p.z*17)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface := SurfaceTool.new()
	surface.create_from(mesh,0)
	surface.generate_normals()
	return surface.commit()

func _build_crawl(world: Node3D, center: Vector2) -> void:
	# A marked two-lane course: shallow steps alongside offset articulation humps.
	for i in 14:
		var p := center+Vector2((i-7)*3.5,0)
		var height := 0.16+(i%4)*0.055
		world._box(Vector3(p.x,world.height_at(p.x,p.y)+height/2,p.y),Vector3(1.2,height,4.8),Color("94998e"),true)
		p.y+=8
		world._box(Vector3(p.x,world.height_at(p.x,p.y)+0.16,p.y+(0.7 if i%2 else -0.7)),Vector3(1.4,0.32,1.3),Color("9a9c8e"),true)
	for x in [-30,30]:
		world._asset("barrel",Vector3(center.x+x,0,center.y-4))
	world._label("ROCK CRAWL  /  LOW RANGE",Vector3(center.x-29,world.height_at(center.x-29,center.y)+2.5,center.y-4),0.013)

func _build_ruins(world: Node3D, center: Vector2) -> void:
	for i in 8:
		var p := center+Vector2(-27 if i%2==0 else 27,(i/2-1.5)*25)
		var floor_y: float=world.height_at(p.x,p.y)
		var floors := 2+i%3
		var concrete := Color("9b9e95").darkened(i*0.012)
		world._box(Vector3(p.x,floor_y+0.15,p.y),Vector3(14,0.3,16),concrete,true)
		for level in floors:
			var y := floor_y+level*3.6
			for side in [-1,1]:
				for z in [-7.0,0.0,7.0]:
					world._box(Vector3(p.x+side*6.5,y+1.8,p.y+z),Vector3(0.55,3.6,0.55),concrete,true)
				world._box(Vector3(p.x+side*6.5,y+3.4,p.y),Vector3(0.65,0.35,15),concrete,true)
				world._box(Vector3(p.x+side*6.5,y+0.65,p.y-3.0),Vector3(0.35,1.3,7),Color("947e6a"),true)
			world._box(Vector3(p.x,y+3.4,p.y-7),Vector3(13.5,0.35,0.6),concrete,true)
			world._box(Vector3(p.x-3,y+3.5,p.y+2),Vector3(6,0.25,10),concrete,true)
		# Surviving window walls and broken slabs interrupt the exposed frame.
		for level in floors-1:
			var y := floor_y+level*3.6
			world._box(Vector3(p.x+3,y+0.7,p.y-7),Vector3(5,1.4,0.38),Color("9d8a76"),true)
			for x in [1.0,3.6,5.3]:
				world._box(Vector3(p.x+x,y+2.2,p.y-7),Vector3(0.5,1.6,0.38),Color("9d8a76"),true)
			world._box(Vector3(p.x+3.2,y+3.0,p.y-7),Vector3(5,0.35,0.38),concrete,true)
		var fallen: Node3D=world._box(Vector3(p.x-4,floor_y+1.2,p.y+7),Vector3(5,0.3,5),concrete,true)
		fallen.rotation=Vector3(0.45,0.2*i,0.16)
		for j in 4:
			world._box(Vector3(p.x-5+j*0.4,floor_y+floors*3.6+0.35,p.y-7),Vector3(0.045,1.0,0.045),Color("626b66"))
		for j in 4:
			var rubble: Node3D=world._box(Vector3(p.x-3+j*2,floor_y+0.25,p.y+9),Vector3(2.3,0.4,1.5),concrete,true)
			rubble.rotation=Vector3(0.1*j,0.4*j,0.15)
		if i%2==0:
			world._asset("wreck_%d"%(i%6),Vector3(center.x-8,0,p.y+3),0.3)
	for z in range(-70,71,12):
		var p := center+Vector2(0,z)
		world._box(Vector3(p.x,world.height_at(p.x,p.y)+0.035,p.y),Vector3(12,0.04,11.5),Color("686f71"))
		world._box(Vector3(p.x,world.height_at(p.x,p.y)+0.06,p.y),Vector3(0.15,0.02,4),Color("b4b29a"))
	world._asset("container",Vector3(center.x+45,0,center.y+60),0.25)
	if map_index==1:
		var x: float=world.coast_x(center.y)-12
		world._box(Vector3(x,1.2,center.y),Vector3(9,3,27),Color("796e62"),true)
		world._box(Vector3(x,3.3,center.y+6),Vector3(5,1.4,5),Color("a09f8e"),true)
		world._box(Vector3(x,5,center.y+6),Vector3(0.15,4.8,0.15),Color("646f6d"))

func _build_lakes(world: Node3D) -> void:
	for lake in lakes:
		var center: Vector2=lake.center
		if lake.frozen:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 48:
				var a: Vector2=Vector2(cos(i*TAU/48),sin(i*TAU/48))*lake.radius*0.65
				var b: Vector2=Vector2(cos((i+1)*TAU/48),sin((i+1)*TAU/48))*lake.radius*0.65
				world._tri(st,Vector3(center.x,0.94,center.y),Vector3(center.x+a.x,0.94,center.y+a.y),Vector3(center.x+b.x,0.94,center.y+b.y),Color("9dc5d1"))
			var ice := MeshInstance3D.new()
			ice.mesh=st.commit()
			var mat := StandardMaterial3D.new()
			mat.albedo_color=Color("75adbf")
			mat.roughness=0.23
			mat.metallic=0.18
			ice.material_override=mat
			world.add_child(ice)
			for j in 7:
				var a := Vector3(center.x-30+j*9,0.95,center.y-25)
				world._beam(a,a+Vector3(sin(j*2)*15,0,48),0.045,Color("92b5c0"))
		else:
			var reeds: Array[Transform3D]=[]
			for i in 1000:
				var angle: float=world.rng.randf()*TAU
				var point: Vector2=center+Vector2(cos(angle),sin(angle))*lake.radius*world.rng.randf_range(0.87,1.22)
				var y: float=world.height_at(point.x,point.y)
				if y<world.WATER_LEVEL-0.2 or y>2.2 or absf(point.x-center.x)<4:
					continue
				reeds.append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3(1.5,3.5,1.5)),Vector3(point.x,y,point.y)))
			world._multimesh(reeds,world.grass_mesh,Color("87966c"),true)
			for j in 14:
				var z: float=center.y-lake.radius.y*1.07+j*1.4
				world._box(Vector3(center.x,1.2,z),Vector3(4,0.20,1.32),Color("9b957b"),true)
				if j%3==0:
					for side in [-1,1]:
						world._box(Vector3(center.x+side*1.8,0.1,z),Vector3(0.16,2.6,0.16),Color("777d6c"),true)
		var sign := center-Vector2(0,lake.radius.y+20)
		world._asset("utility_pole",Vector3(sign.x+7,0,sign.y))
		world._label(lake.name,Vector3(sign.x,world.height_at(sign.x,sign.y)+3,sign.y),0.016)
