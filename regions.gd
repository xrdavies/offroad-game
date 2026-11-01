extends RefCounted

const SIZE := Vector2(450,390)
const ZONES := [
	{"id":"forest", "name":"PINEWOOD TRAIL", "center":Vector2(-265,-130), "radius":110.0, "color":Color("74806a"), "surface":"forest"},
	{"id":"mountain", "name":"HIGH RIDGE PASS", "center":Vector2(-225,-280), "radius":105.0, "color":Color("95918b"), "surface":"rock"},
	{"id":"desert", "name":"AMBER DUNES", "center":Vector2(265,-165), "radius":150.0, "color":Color("c4a378"), "surface":"sand"},
	{"id":"grassland", "name":"WINDGRASS PLAINS", "center":Vector2(-260,220), "radius":135.0, "color":Color("929b63"), "surface":"grass"},
	{"id":"mud", "name":"RUTTED BASIN", "center":Vector2(-80,210), "radius":72.0, "color":Color("6f6051"), "surface":"mud"},
	{"id":"swamp", "name":"CYPRESS MARSH", "center":Vector2(195,205), "radius":110.0, "color":Color("6c7b64"), "surface":"swamp"}
]
const TRAILS := [
	[Vector2(-38,-28),Vector2(-95,-80),Vector2(-175,-120),Vector2(-265,-130),Vector2(-285,-210),Vector2(-250,-245),Vector2(-225,-280)],
	[Vector2(-12,40),Vector2(-50,100),Vector2(-80,155),Vector2(-80,210),Vector2(-170,230),Vector2(-260,220)],
	[Vector2(62,10),Vector2(115,85),Vector2(155,150),Vector2(195,205),Vector2(260,250)],
	[Vector2(65,-30),Vector2(135,-80),Vector2(210,-120),Vector2(265,-165),Vector2(340,-210)],
	[Vector2(-260,220),Vector2(-340,130),Vector2(-345,20),Vector2(-320,-65),Vector2(-265,-130)]
]

static func zone_at(p: Vector2) -> Dictionary:
	var best := 1.0
	var result: Dictionary={}
	for zone in ZONES:
		var distance: float=p.distance_to(zone.center)/zone.radius
		if distance<best:
			best=distance
			result=zone
	return result

static func weight(p: Vector2, zone: Dictionary) -> float:
	return 1.0-smoothstep(0.45,1.15,p.distance_to(zone.center)/zone.radius)

static func height(x: float,z: float,base: float) -> float:
	var p := Vector2(x,z)
	var original := smoothstep(125,175,absf(x))*1.0 if absf(z)<105 else maxf(smoothstep(105,155,absf(z)),smoothstep(125,175,absf(x)))
	var h := base
	for zone in ZONES:
		var blend := weight(p,zone)*original
		if blend<=0:
			continue
		var target := base
		match zone.id:
			"forest": target=3.5+sin(x*0.035)*cos(z*0.025)*2.2
			"mountain": target=5+26*exp(-pow((x+225)/65,2)-pow((z+280)/65,2))+sin(x*0.07+z*0.025)*1.4
			"desert": target=4+pow(0.5+0.5*sin(x*0.055+sin(z*0.022)*2),2)*6+sin(z*0.03)*1.2
			"grassland": target=3+sin(x*0.025)*cos(z*0.027)*2
			"mud": target=1.7+sin(x*0.8)*cos(z*0.11)*0.11+sin(z*0.07)*0.25
			"swamp": target=0.42+sin(x*0.055)*cos(z*0.05)*0.45
		h=lerpf(h,target,blend)
	return h

static func trail_distance(p: Vector2) -> float:
	var distance := INF
	for trail in TRAILS:
		for i in range(trail.size()-1):
			distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,trail[i],trail[i+1])))
	return distance

static func build(world: Node3D) -> void:
	_build_trails(world)
	var trunks: Array[Transform3D]=[]
	var crowns: Array[Transform3D]=[]
	var crown_colors: Array[Color]=[]
	var rocks: Array[Transform3D]=[]
	var grasses: Array[Transform3D]=[]
	var grass_colors: Array[Color]=[]
	var rng: RandomNumberGenerator=world.rng
	for zone in ZONES:
		for i in 230:
			var p: Vector2=zone.center+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))*zone.radius
			if p.distance_to(zone.center)>zone.radius or trail_distance(p)<5 or p.distance_to(zone.center)<9:
				continue
			var y: float=world.height_at(p.x,p.y)
			if zone.id in ["forest","swamp"] or (zone.id=="grassland" and i%15==0):
				var h := rng.randf_range(4,8)
				trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.38,h,0.38)),Vector3(p.x,y+h/2,p.y)))
				for layer in 4:
					var wide := (4-layer*0.55)*(0.7+h/12)
					crowns.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(wide,2.4,wide)),Vector3(p.x,y+h-2+layer*0.65,p.y)))
					crown_colors.append(Color("526953") if zone.id=="forest" else Color("7e8e69"))
				var body := StaticBody3D.new()
				var shape := CollisionShape3D.new()
				var cylinder := CylinderShape3D.new()
				cylinder.radius=0.25
				cylinder.height=h
				shape.shape=cylinder
				body.add_child(shape)
				world.add_child(body)
				body.position=Vector3(p.x,y+h/2,p.y)
			elif zone.id in ["mountain","desert"]:
				var s := rng.randf_range(0.5,2.2)
				var basis := Basis(Vector3.UP,rng.randf()*TAU)
				rocks.append(Transform3D(basis.scaled(Vector3(s*1.4,s,s)),Vector3(p.x,y+s*0.3,p.y)))
				var body := StaticBody3D.new()
				var collision := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size=Vector3(s*1.4,s,s)
				collision.shape=shape
				body.add_child(collision)
				world.add_child(body)
				body.transform=Transform3D(basis,Vector3(p.x,y+s*0.3,p.y))
		for i in 12000:
			var p: Vector2=zone.center+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))*zone.radius
			if p.distance_to(zone.center)>zone.radius or trail_distance(p)<3 or p.distance_to(zone.center)<7:
				continue
			if zone.id in ["desert","mountain"] and i%12!=0:
				continue
			var scale_value := rng.randf_range(0.7,1.7)
			var y: float=world.height_at(p.x,p.y)
			grasses.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(scale_value,scale_value*(2 if zone.id=="swamp" else 1),scale_value)),Vector3(p.x,y,p.y)))
			grass_colors.append(Color("8e9e5e") if zone.id=="grassland" else Color("a5a16e"))
		var c: Vector2=zone.center
		world._asset("container" if zone.id in ["forest","desert"] else "utility_pole",Vector3(c.x+9,0,c.y+4),0.3)
		world._asset("barrel",Vector3(c.x+6,0,c.y+6))
		world._box(Vector3(c.x+5,world.height_at(c.x+5,c.y)+1.8,c.y),Vector3(0.12,3.6,0.12),Color("65695a"),true)
		world._box(Vector3(c.x+5,world.height_at(c.x+5,c.y)+3.5,c.y),Vector3(5,0.85,0.14),Color("596456"))
		world._label(zone.name,Vector3(c.x+5,world.height_at(c.x+5,c.y)+3.5,c.y+0.09),0.011)
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
	var canopy := foliage.commit()
	world._multimesh(trunks,BoxMesh.new(),Color("706653"),true)
	world._multimesh(crowns,canopy,Color.WHITE,true,crown_colors)
	world._multimesh(rocks,BoxMesh.new(),Color("918a78"),true)
	world._multimesh(grasses,world.grass_mesh,Color.WHITE,true,grass_colors)
	# Rocky steps and alternating log humps provide deliberate suspension obstacles.
	for i in 8:
		var p := Vector2(-145-i*4,230)
		world._box(Vector3(p.x,world.height_at(p.x,p.y)+0.1,p.y),Vector3(0.5,0.2+(i%3)*0.06,5),Color("7e735d"),true)

static func _build_trails(world: Node3D) -> void:
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
					world._tri(st,points[0],points[1],points[2],Color("786c56"))
					world._tri(st,points[0],points[2],points[3],Color("786c56"))
			if i>0:
				world._asset("barrel",Vector3(a.x+side.x*4,0,a.y+side.y*4))
	var mesh := MeshInstance3D.new()
	mesh.mesh=st.commit()
	var material := ShaderMaterial.new()
	material.shader=load("res://assets/ground.gdshader")
	mesh.material_override=material
	world.add_child(mesh)
