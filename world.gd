extends Node3D

const ROUTE_PATH := "res://assets/world/route.json"
const WATER_LEVEL := 0.72
const REGIONS := preload("res://regions.gd")
const SIZE := REGIONS.SIZE
const SCRAP_CENTERS := [Vector2(-88,-24),Vector2(-61,29),Vector2(77,-73)]
var layout: Dictionary
var landmarks: Array = []
var road_points := PackedVector3Array()
var rng := RandomNumberGenerator.new()
var terrain_mesh: ArrayMesh
var grass_mesh: ArrayMesh
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
	REGIONS.build(self)
	_build_boundary()

func river_x(z: float) -> float:
	return 32.0+7.0*sin(z*0.025)+2.2*sin(z*0.11)

func river_widening(z: float) -> float:
	return 3.8*exp(-pow((z+15.0)/21.0,2))+0.55*sin(z*0.43)+0.3*cos(z*0.71)

func height_at(x: float, z: float) -> float:
	var base := 2.1 + sin(x*0.065)*cos(z*0.052)*0.48
	base += 5.0 * exp(-pow((x-96.0)/33.0,2)-pow((z-8.0)/40.0,2))
	base += 3.5 * exp(-pow((x+15.0)/40.0,2)-pow((z+98.0)/27.0,2))
	base += scrap_height_at(x,z)
	base=REGIONS.height(x,z,base)
	var widening := river_widening(z)
	var bank := smoothstep(3.5+widening,12.0+widening,abs(x-river_x(z)))
	base = lerpf(0.12,base,bank)
	var workshop := 1.0 - smoothstep(10.0,21.0,Vector2(x+14,z-5).length())
	base = lerpf(base,2.1,workshop)
	return base

func scrap_height_at(x: float,z: float) -> float:
	var height := 0.0
	for center in SCRAP_CENTERS:
		height += 6.5*exp(-pow((x-center.x)/10.0,2)-pow((z-center.y)/12.0,2))
	return height

func road_distance(point: Vector2) -> float:
	var result := INF
	for i in range(road_points.size()-1):
		var a := Vector2(road_points[i].x, road_points[i].z)
		var b := Vector2(road_points[i+1].x, road_points[i+1].z)
		result = minf(result,point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b)))
	return result

func surface_at(point: Vector3) -> String:
	if height_at(point.x,point.z) < WATER_LEVEL and point.y < WATER_LEVEL+1.0:
		return "swamp" if REGIONS.zone_at(Vector2(point.x,point.z)).get("id","")=="swamp" else "water"
	if road_distance(Vector2(point.x,point.z)) < 3.5:
		return "road"
	return REGIONS.zone_at(Vector2(point.x,point.z)).get("surface","dirt")

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
	for z in range(-390,390,2):
		for x in range(-450,450,2):
			var a := Vector3(x,height_at(x,z),z)
			var b := Vector3(x+2,height_at(x+2,z),z)
			var c := Vector3(x+2,height_at(x+2,z+2),z+2)
			var d := Vector3(x,height_at(x,z+2),z+2)
			var patch := sin(x*0.12+sin(z*0.09)*2.0)*cos(z*0.11)
			var color := Color("8c8075").lerp(Color("a39973"),patch*0.5+0.5)
			color=color.lightened(rng.randf_range(-0.008,0.008))
			if x < -45 and z > -42 and z < 19:
				color=color.lerp(Color("887b7c"),0.5)
			if scrap_height_at(x,z)>0.6:
				color=color.lerp(Color("696760"),0.65)
			var shore := 1.0-smoothstep(8.0+river_widening(z),14.0+river_widening(z),absf(x-river_x(z)))
			color=color.lerp(Color("7e887c"),shore*0.8)
			if x>77:
				color = color.lerp(Color("9f7662"),0.5)
			for zone in REGIONS.ZONES:
				color=color.lerp(zone.color,REGIONS.weight(Vector2(x,z),zone))
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
		var color := Color("60626a").lightened(rng.randf()*0.025)
		_tri(st,a,d,c,color,[Vector2(-1,i),Vector2(-1,i+1),Vector2(1,i+1)])
		_tri(st,a,c,b,color,[Vector2(-1,i),Vector2(1,i+1),Vector2(1,i)])
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
	# Shared height samples clip both the river and marsh water to their actual beds.
	for z in range(-390,390,4):
		for x in range(-450,450,4):
			var points: Array[Vector3]=[Vector3(x,WATER_LEVEL,z),Vector3(x+4,WATER_LEVEL,z),Vector3(x+4,WATER_LEVEL,z+4),Vector3(x,WATER_LEVEL,z+4)]
			var depths: Array[Vector2]=[]
			var wet := false
			for p in points:
				var depth: float=WATER_LEVEL-height_at(p.x,p.z)
				depths.append(Vector2(depth,0))
				wet=wet or depth>0
			if not wet:
				continue
			_tri(st,points[0],points[1],points[2],Color.WHITE,[depths[0],depths[1],depths[2]])
			_tri(st,points[0],points[2],points[3],Color.WHITE,[depths[0],depths[2],depths[3]])
	var water := MeshInstance3D.new()
	water.mesh=st.commit()
	var material := ShaderMaterial.new()
	material.shader=load("res://assets/water.gdshader")
	water.material_override=material
	add_child(water)

func _build_places() -> void:
	for data in landmarks:
		var pos := Vector3(data.position[0],0,data.position[1])
		if not data.model.is_empty():
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
	_label("OFF ROAD RIDER  /  SERVICE",Vector3(-14,5.65,9.86),0.019)
	_label("MOTOR YARD",Vector3(-63,height_at(-63,-44)+3,-44),0.03)

func _build_scrap() -> void:
	for i in 63:
		var x := -82.0+(i%7)*5.3+rng.randf_range(-0.8,0.8)
		var z := -38.0+floori(i/7.0)*6.2+rng.randf_range(-0.9,0.9)
		if absf(x+65)<3 or absf(z+12)<3:
			continue
		var wreck := _asset("wreck_%d"%(i%6),Vector3(x,-0.04,z),rng.randf_range(-0.45,0.45)+PI/2+(PI if i%4==0 else 0.0))
		wreck.rotation.z=rng.randf_range(-0.1,0.1)
		if i%9==0:
			_asset("wreck_5",Vector3(x,1.2,z),wreck.rotation.y+0.14)
	for p in [Vector3(-30,0,23),Vector3(12,0,-70),Vector3(66,0,-44),Vector3(48,0,48),Vector3(-9,0,-35)]:
		_asset("wreck_1",p,rng.randf_range(0,TAU))
	# Terrain and its collision form the heap; debris sits on that shared surface.
	for kind in 4:
		var scrap: Array[Transform3D]=[]
		for i in [3600,1200,3600,2400][kind]:
			var center: Vector2=SCRAP_CENTERS[i%3]
			var p := center+Vector2(rng.randfn(0,7.4),rng.randfn(0,8.8))
			if road_distance(p)<5.5:
				continue
			var scale_value := rng.randf_range(0.45,1.0)
			var basis := Basis.from_euler(Vector3(rng.randf_range(-1,1),rng.randf()*TAU,rng.randf_range(-1,1))).scaled(Vector3.ONE*scale_value)
			scrap.append(Transform3D(basis,Vector3(p.x,height_at(p.x,p.y)+0.13,p.y)))
		var id := "salvage_%d"%kind
		models[id]=load("res://assets/models/"+id+".tscn")
		var source: Node3D=models[id].instantiate()
		_multimesh(scrap,source.get_node("Model").mesh,Color.WHITE,true)
		source.free()
	for p in [Vector3(-76,0,-18),Vector3(-54,0,0),Vector3(-70,0,12),Vector3(-23,0,15)]:
		for j in 4:
			_asset("salvage_0",p+Vector3(0,0.15+j*0.25,0),j*0.3)

func _build_vegetation() -> void:
	var grass: Array[Transform3D]=[]
	var grass_colors: Array[Color]=[]
	var pebbles: Array[Transform3D]=[]
	var field := FastNoiseLite.new()
	field.seed=int(layout.seed)
	field.frequency=0.065
	field.fractal_octaves=2
	for i in 180000:
		var x := rng.randf_range(-140,140)
		var z := rng.randf_range(-120,120)
		var y := height_at(x,z)
		var density := field.get_noise_2d(x,z)
		if density < -0.12 or y<WATER_LEVEL or scrap_height_at(x,z)>0.8 or Vector2(x+14,z-5).length()<12:
			continue
		if x < -45 and x > -86 and z > -42 and z < 19 and (absf(x+65)<2 or absf(z+12)<2):
			continue
		if road_distance(Vector2(x,z))<4.2:
			continue
		var s := rng.randf_range(0.65,1.15)*(0.6+maxf(0,density)*0.9)
		grass.append(Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled(Vector3(s,s,s)),Vector3(x,y,z)))
		var color := Color("b8af6e").lerp(Color("8d9654"),clampf(density*2,0,1))
		if x < -45 and z > -42 and z < 19:
			color=color.lerp(Color("b27667"),smoothstep(0.05,0.3,field.get_noise_2d(x+80,z)))
		grass_colors.append(color)
		if i%8==0:
			pebbles.append(Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled(Vector3(rng.randf_range(0.06,0.2),0.035,rng.randf_range(0.06,0.3))),Vector3(x,y+0.01,z)))
	var tuft := SurfaceTool.new()
	tuft.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var x := sin(i*4.3)*0.33
		var z := cos(i*3.1)*0.33
		var a := Vector3(x-0.045,0,z)
		var b := Vector3(x+0.045,0,z)
		var c := Vector3(x+0.08,0.27+(i%3)*0.12,z+0.07)
		var d := c-Vector3(0.06,-0.04,0)
		_tri(tuft,a,b,c,Color("c1be96"))
		_tri(tuft,a,c,d,Color.WHITE)
	grass_mesh=tuft.commit()
	_multimesh(grass,grass_mesh,Color.WHITE,true,grass_colors)
	_multimesh(pebbles,BoxMesh.new(),Color("a69c8d"),true)
	for i in 55:
		var x := rng.randf_range(-100,110)
		var z := rng.randf_range(-110,100)
		if road_distance(Vector2(x,z))<9 or height_at(x,z)<WATER_LEVEL or Vector2(x+14,z-5).length()<18 or scrap_height_at(x,z)>0.8:
			continue
		var palm := _asset("palm",Vector3(x,0,z),rng.randf()*TAU)
		palm.scale=Vector3.ONE*rng.randf_range(0.75,1.2)

func _build_cliffs() -> void:
	for data in [[Vector2(-115,-54),Vector2(15,18),7],[Vector2(100,-35),Vector2(16,12),8],[Vector2(-40,-104),Vector2(14,10),7],[Vector2(87,44),Vector2(20,14),8]]:
		var center: Vector2=data[0]
		var extent: Vector2=data[1]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var origin := Vector3(center.x,height_at(center.x,center.y)-0.4,center.y)
		var outline: Array[Vector3]=[]
		for i in 44:
			var angle := i*TAU/44.0
			var radial := 1.0+sin(i*2.87)*0.065+cos(i*1.07)*0.09
			outline.append(Vector3(cos(angle)*extent.x,0,sin(angle)*extent.y)*radial)
		for level in int(data[2]):
			var bottom := 1.0-level*0.055
			var top := bottom-0.015
			var drift := Vector3(sin(level*1.7)*0.38,level*0.88,cos(level*1.3)*0.3)
			for i in outline.size():
				var next := (i+1)%outline.size()
				var jag := sin(i*3.7+level*2.3)*0.028
				var next_jag := sin(next*3.7+level*2.3)*0.028
				var a := origin+drift+outline[i]*(bottom+jag)
				var b := origin+drift+outline[next]*(bottom+next_jag)
				var c := origin+drift+outline[next]*(top+next_jag)+Vector3.UP*0.88
				var d := origin+drift+outline[i]*(top+jag)+Vector3.UP*0.88
				var color := Color("89877b").lightened(rng.randf_range(-0.08,0.07)+(level%3)*0.025)
				_tri(st,a,b,c,color)
				_tri(st,a,c,d,color)
				_tri(st,origin+drift+Vector3.UP*0.88,d,c,Color("a39b7f"))
		var visual := MeshInstance3D.new()
		visual.mesh=st.commit()
		var rock_material := ShaderMaterial.new()
		rock_material.shader=load("res://assets/rock.gdshader")
		visual.material_override=rock_material
		add_child(visual)
		visual.create_trimesh_collision()
		var plateau: Array[Transform3D]=[]
		var plateau_y := origin.y+int(data[2])*0.88
		for i in 380:
			var p := Vector2(rng.randf_range(-0.4,0.4),rng.randf_range(-0.4,0.4))
			if p.length()>0.4 or sin(p.x*23)*cos(p.y*19)<-0.2:
				continue
			var scale_value := rng.randf_range(0.6,1.2)
			plateau.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),Vector3(center.x+p.x*extent.x,plateau_y,center.y+p.y*extent.y)))
		_multimesh(plateau,grass_mesh,Color("aaa86a"),true)

func _build_boundary() -> void:
	# Visible stepped escarpments explain the edge of the drivable survey area.
	for x in [-448,448]:
		for z in range(-390,391,13):
			var y := height_at(x,z)
			_box(Vector3(x,y+2.5,z),Vector3(7,5,13.2),Color("797c69"),true)
			_box(Vector3(x,y+6,z),Vector3(5,2+rng.randf(),12.8),Color("93917b"),true)
	for z in [-388,388]:
		for x in range(-445,446,13):
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
	if absf(pos.x)>420 or absf(pos.z)>360:
		visual.visibility_range_end=180
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
	assert(colors.is_empty() or colors.size()==transforms.size())
	# Spatial batches let the renderer skip offscreen grass and distant scrap heaps.
	var chunks: Dictionary={}
	for i in transforms.size():
		var p := transforms[i].origin
		var cell := Vector2i(floori(p.x/32.0),floori(p.z/32.0))
		if not chunks.has(cell):
			chunks[cell]=[]
		chunks[cell].append(i)
	var material := _vertex_material()
	for indices in chunks.values():
		var batch := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.use_colors=true
		multi.mesh=mesh
		multi.instance_count=indices.size()
		for j in indices.size():
			var i: int=indices[j]
			multi.set_instance_transform(j,transforms[i])
			var tint := colors[i] if not colors.is_empty() else color
			multi.set_instance_color(j,(tint.lightened(rng.randf_range(-0.12,0.1)) if varied else tint).srgb_to_linear())
		batch.multimesh=multi
		batch.material_override=material
		batch.visibility_range_end=150 if mesh==grass_mesh else 260
		batch.visibility_range_end_margin=20
		batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)

func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color,uv: Array[Vector2]=[]) -> void:
	var normal := (c-a).cross(b-a).normalized()
	var points := [a,b,c]
	for i in 3:
		st.set_normal(normal)
		st.set_color(color.srgb_to_linear())
		if not uv.is_empty():
			st.set_uv(uv[i])
		st.add_vertex(points[i])

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
