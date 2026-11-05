extends SceneTree

# Editable source for the original scenery and detailed vehicle models.
const VEHICLES := preload("res://vehicles.gd")
const OUT := "res://assets/models/"
var surface: SurfaceTool
var root_asset: Node3D
var collider: StaticBody3D
var palette := {
	"paint": Color("857b55"), "edge": Color("b5a47a"), "rust": Color("855b4c"),
	"rubber": Color("292d32"), "glass": Color("586c7c"), "steel": Color("666a65"),
	"cream": Color("c3bda3"), "dark": Color("393e3f"), "red": Color("a9594e"),
	"green": Color("73806b"), "sand": Color("978b72")
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for spec in VEHICLES.SPECS:
		_begin(spec.id.capitalize()+"Body")
		_expedition_vehicle(spec)
		_save(spec.id+"_body")
	_begin("ScoutWheel")
	_wheel(Vector3.ZERO, 0.48)
	_save("scout_wheel")
	if "--vehicles-only" in OS.get_cmdline_user_args():
		print("ASSETS_OK: ", VEHICLES.SPECS.size(), " vehicle bodies and detailed wheels baked")
		quit()
		return
	for i in 6:
		_begin("Wreck%d" % i)
		_wreck(i)
		_save("wreck_%d" % i)
	for i in 4:
		_begin("Salvage%d" % i)
		_salvage(i)
		_save("salvage_%d" % i)
	_begin("ServiceGarage")
	_garage()
	_save("garage")
	_begin("FuelPump")
	_pump()
	_save("fuel_pump")
	_begin("Container")
	_container()
	_save("container")
	_begin("Palm")
	_palm()
	_save("palm")
	_begin("UtilityPole")
	_pole()
	_save("utility_pole")
	_begin("Barrel")
	_cylinder(Vector3(0, 0.48, 0), 0.34, 0.96, palette.rust, 10)
	for y in [0.15, 0.76]:
		_cylinder(Vector3(0, y, 0), 0.355, 0.065, palette.dark, 10)
	_collision(Vector3(0, 0.48, 0), Vector3(0.68, 0.96, 0.68))
	_save("barrel")
	_begin("ConcreteBarrier")
	_box(Vector3(0, 0.28, 0), Vector3(3.2, 0.56, 0.9), palette.cream, Vector3.ZERO, true)
	_box(Vector3(0, 0.8, 0), Vector3(3.2, 0.5, 0.42), palette.sand, Vector3.ZERO, true)
	for x in [-1.1, 0.0, 1.1]:
		_box(Vector3(x, 0.8, 0.22), Vector3(0.48, 0.4, 0.035), palette.rust)
	_save("barrier")
	_begin("FencePanel")
	_fence()
	_save("fence")
	_begin("WaterTank")
	_tank()
	_save("water_tank")
	_begin("Relay")
	_relay()
	_save("relay")
	print("ASSETS_OK: original vehicle and scenery scenes baked")
	quit()

func _begin(asset_name: String) -> void:
	root_asset = Node3D.new()
	root_asset.name = asset_name
	root_asset.set_meta("model_detail", "high_precision_stylized")
	root_asset.set_meta("interior_detail", "cad_inspired")
	collider = null
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func _save(file_name: String) -> void:
	_mesh_node("Model", Vector3.ZERO)
	var scene := PackedScene.new()
	assert(scene.pack(root_asset) == OK)
	assert(ResourceSaver.save(scene, OUT + file_name + ".tscn") == OK)
	root_asset.free()

func _mesh_node(node_name: String, pos: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = pos
	visual.mesh = surface.commit()
	assert(visual.mesh.get_surface_count() == 1 and visual.mesh.get_aabb().size.length() > 0.1)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.roughness = 0.9
	visual.material_override = material
	root_asset.add_child(visual)
	visual.owner = root_asset
	return visual

func _rounded_box(pos: Vector3, size: Vector3, radius: float, color: Color, rot := Vector3.ZERO) -> void:
	assert(size.x > 0 and size.y > 0 and size.z > 0 and radius > 0)
	radius = minf(radius, minf(size.x, minf(size.y, size.z)) * 0.49)
	var half := size * 0.5
	var core := half - Vector3.ONE * radius
	var basis := Basis.from_euler(rot)
	# Project the edge strips onto a rounded cuboid, keeping broad faces flat.
	for normal in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u := Vector3.UP if absf(normal.x) > 0.5 else Vector3.RIGHT
		var v: Vector3 = u.cross(normal)
		var hu: float = half.dot(u.abs())
		var hv: float = half.dot(v.abs())
		var us := [-hu, -hu+radius*0.5, -hu+radius, hu-radius, hu-radius*0.5, hu]
		var vs := [-hv, -hv+radius*0.5, -hv+radius, hv-radius, hv-radius*0.5, hv]
		for i in range(5):
			for j in range(5):
				for corner in [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i+1,j+1), Vector2i(i,j), Vector2i(i+1,j+1), Vector2i(i,j+1)]:
					var p: Vector3 = normal * half + u * us[corner.x] + v * vs[corner.y]
					var center := p.clamp(-core, core)
					var n := (p-center).normalized()
					surface.set_normal(basis*n)
					surface.set_color(color.srgb_to_linear())
					surface.add_vertex(pos+basis*(center+n*radius))

func _ring(pos: Vector3, radius: float, tube: float, color: Color, rot := Vector3.ZERO) -> void:
	var ring_basis:=Basis.from_euler(rot)
	for i in 64:
		for j in 8:
			for corner in [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i+1,j+1), Vector2i(i,j), Vector2i(i+1,j+1), Vector2i(i,j+1)]:
				var a: float = TAU*corner.x/64.0
				var b: float = TAU*corner.y/8.0
				var radial := Vector3(sin(a),cos(a),0)
				var n := radial*cos(b)+Vector3.BACK*sin(b)
				surface.set_normal(ring_basis*n)
				surface.set_color(color.srgb_to_linear())
				surface.add_vertex(pos+ring_basis*(radial*radius+n*tube))

func _label(pos: Vector3, caption: String, height: float, color := Color("d6d5bd")) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.position = pos
	label.font_size = 48
	label.pixel_size = height/48
	label.outline_size = 0
	label.modulate = color
	root_asset.add_child(label)
	label.owner = root_asset
	return label

func _needle(pos: Vector3, radius: float, node_name: String) -> void:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = pos
	root_asset.add_child(pivot)
	pivot.owner = root_asset
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.004, radius*0.85, 0.003)
	visual.mesh = mesh
	visual.position.y = radius*0.32
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e8a06c")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	pivot.add_child(visual)
	visual.owner = root_asset

func _gauge(pos: Vector3, radius: float, speedometer: bool, mph := false) -> void:
	_cylinder(pos, radius+0.009, 0.026, Color("192823"), 48, Vector3(PI/2,0,0))
	_ring(pos+Vector3(0,0,0.017), radius, 0.006, Color("9bada2"))
	var face := pos+Vector3(0,0,0.016)
	var ticks: int=30 if mph else 28
	for i in (ticks+1 if speedometer else 32):
		var a := deg_to_rad(-135+i*270.0/ticks) if speedometer else i*TAU/32
		var major: bool=i%(5 if mph else 4)==0
		var direction := Vector3(sin(a),cos(a),0)
		_box(face+direction*radius*0.83, Vector3(0.002,0.012 if major else 0.005,0.002), Color("d6d5bd"), Vector3(0,0,-a))
		if major:
			var caption: String = str(i*2 if mph else i*5) if speedometer else ["N","E","S","W"][i/8] if i%8 == 0 else ""
			_label(face+direction*radius*0.62+Vector3(0,0,0.003), caption, radius*0.17)
	_label(face+Vector3(0,-radius*0.32,0.003), ("MPH" if mph else "KM/H") if speedometer else "HEADING", radius*0.11)
	_needle(face+Vector3(0,0,0.008), radius*0.78, "SpeedNeedle" if speedometer else "HeadingNeedle")
	_cylinder(face+Vector3(0,0,0.012), 0.009, 0.01, Color("a1afa3"), 24, Vector3(PI/2,0,0))
	if mph:
		root_asset.get_node("SpeedNeedle").set_meta("maximum_kmh",60.0*1.609344)

func _steering(spec: Dictionary) -> void:
	var body_surface := surface
	surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vintage: bool=spec.id=="wc62"
	var truck: bool=spec.id in ["unimog","eq246","hauler"]
	var radius: float=0.22 if vintage else 0.215 if truck else 0.185
	var rim := Color("383b3a")
	_ring(Vector3.ZERO,radius,0.012 if vintage else 0.022,rim)
	var angles: Array=[-90,90,180]
	if vintage:
		angles=[-90,30,150]
	elif spec.id=="unimog":
		angles=[-70,70,-145,145]
	elif spec.id=="eq246":
		angles=[-90,90]
	for degrees in angles:
		var a: float=deg_to_rad(degrees)
		var end:=Vector3(sin(a),cos(a),0)*radius
		_beam(Vector3(0,0,0.005),end,0.014 if vintage else 0.042 if truck else 0.035,rim)
		if not vintage:
			_beam(end*0.40+Vector3(0,0,0.024),end*0.90+Vector3(0,0,0.024),0.012,Color("8b8c88"))
	if vintage:
		_cylinder(Vector3(0,0,0.015),0.042,0.028,Color("636a46"),32,Vector3(PI/2,0,0))
	else:
		_rounded_box(Vector3(0,-0.007,0.026),Vector3(0.17 if truck else 0.14,0.09,0.052),0.032,rim)
		if spec.id in ["wrangler","unimog","f150","hilux"]:
			for side in [-1,1]:
				for row in 2:
					_rounded_box(Vector3(side*0.115,0.006-row*0.023,0.03),Vector3(0.028,0.016,0.01),0.004,Color("626665"))
	if spec.id=="f150":
		_rounded_box(Vector3(0,radius,0.018),Vector3(0.028,0.042,0.024),0.006,Color("be6c37"))
		for side in [-1,1]:
			_rounded_box(Vector3(side*0.135,0.04,-0.045),Vector3(0.028,0.12,0.025),0.008,Color("9da1a2"))
	var wheel:=_mesh_node("SteeringWheel",spec.seat+Vector3(0,-0.39,-0.64))
	wheel.rotation.x=-0.20 if not vintage else -0.32
	surface=body_surface

func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.set_color(color.srgb_to_linear())
		surface.add_vertex(point)

func _box(pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO, solid := false) -> void:
	var b := Basis.from_euler(rot)
	var p: Array[Vector3] = []
	for v in [Vector3(-1,-1,-1), Vector3(1,-1,-1), Vector3(1,1,-1), Vector3(-1,1,-1), Vector3(-1,-1,1), Vector3(1,-1,1), Vector3(1,1,1), Vector3(-1,1,1)]:
		p.append(pos + b * (v * size * 0.5))
	for f in [[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]]:
		_triangle(p[f[0]], p[f[1]], p[f[2]], color)
		_triangle(p[f[0]], p[f[2]], p[f[3]], color)
	if solid:
		_collision(pos, size, rot)

func _cylinder(pos: Vector3, radius: float, height: float, color: Color, segments := 10, rot := Vector3.ZERO, top_radius := -1.0) -> void:
	var b := Basis.from_euler(rot)
	var top := radius if top_radius < 0.0 else top_radius
	for i in segments:
		var a := TAU * float(i) / segments
		var z := TAU * float(i + 1) / segments
		var p0 := pos + b * Vector3(cos(a)*radius, -height/2, sin(a)*radius)
		var p1 := pos + b * Vector3(cos(z)*radius, -height/2, sin(z)*radius)
		var p2 := pos + b * Vector3(cos(z)*top, height/2, sin(z)*top)
		var p3 := pos + b * Vector3(cos(a)*top, height/2, sin(a)*top)
		_triangle(p0, p1, p2, color)
		_triangle(p0, p2, p3, color)
		_triangle(pos + b * Vector3(0, height/2, 0), p3, p2, color.lightened(0.04))
		_triangle(pos - b * Vector3(0, height/2, 0), p1, p0, color)

func _collision(pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	if not collider:
		collider = StaticBody3D.new()
		collider.name = "Collision"
		root_asset.add_child(collider)
		collider.owner = root_asset
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	shape.rotation = rot
	collider.add_child(shape)
	shape.owner = root_asset

func _beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var direction := (b-a).normalized()
	var up := Vector3.UP if absf(direction.y)<0.99 else Vector3.FORWARD
	_box((a+b)*0.5,Vector3(width,width,a.distance_to(b)),color,Basis.looking_at(direction,up).get_euler())

func _chips(pos: Vector3, size: Vector2, color: Color, seed_value: int, vertical := false) -> void:
	var random := RandomNumberGenerator.new()
	random.seed=seed_value
	var centers: Array[Vector2]=[]
	for i in 4:
		centers.append(Vector2(random.randf_range(-0.32,0.32)*size.x,random.randf_range(-0.32,0.32)*size.y))
	for i in 28:
		var center := centers[i%4]
		var u := clampf(snappedf(center.x+random.randfn(0,size.x*0.1),0.09),-size.x/2,size.x/2)
		var v := clampf(snappedf(center.y+random.randfn(0,size.y*0.1),0.09),-size.y/2,size.y/2)
		var patch := Vector3(random.randf_range(0.08,0.22),0.012,random.randf_range(0.09,0.3))
		var offset := Vector3(u,0,v)
		if vertical:
			patch=Vector3(patch.x,patch.z,patch.y)
			offset=Vector3(u,v,0)
		_box(pos+offset,patch,color.lightened(random.randf_range(-0.12,0.08)))

func _wheel(pos: Vector3, radius: float) -> void:
	_cylinder(pos, radius, 0.29, palette.rubber, 32, Vector3(0,0,PI/2))
	_cylinder(pos, radius*0.95, 0.37, palette.rubber.lightened(0.025), 32, Vector3(0,0,PI/2))
	_cylinder(pos, radius*0.55, 0.39, palette.steel, 32, Vector3(0,0,PI/2))
	_cylinder(pos, radius*0.38, 0.40, palette.dark, 32, Vector3(0,0,PI/2))
	_cylinder(pos, radius*0.18, 0.44, palette.steel, 24, Vector3(0,0,PI/2))
	for side in [-1,1]:
		for i in 8:
			var a := TAU*i/8
			_cylinder(pos+Vector3(side*0.208,sin(a)*radius*0.44,cos(a)*radius*0.44),radius*0.055,0.025,palette.cream,8,Vector3(0,0,PI/2))
		for i in 24:
			var a: float = TAU*(i+side*0.2)/24
			_box(pos+Vector3(side*0.09,sin(a)*radius,cos(a)*radius),Vector3(0.20,0.055,0.09),palette.rubber.lightened(0.06),Vector3(-a,side*0.25,0))


func _wreck(kind: int) -> void:
	var paint: Color = [Color("c7b9a0"),Color("7d9e9b"),Color("bb8c7d"),Color("c9c3a8"),Color("939a78"),Color("76645f")][kind]
	var roof_y := 1.57 if kind==3 else 1.31
	var rear := 1.45 if kind in [1,3] else 0.64
	if kind==2:
		rear=0.15
	var roof_z := (-0.36+rear)*0.5
	_box(Vector3(0,0.3,0),Vector3(1.58,0.17,3.8),palette.rust)
	_collision(Vector3(0,0.57,0),Vector3(1.82,0.65,3.85))
	_collision(Vector3(0,1.04,roof_z),Vector3(1.5,roof_y-0.7,rear+0.6))
	_box(Vector3(0,0.49,0.1),Vector3(1.5,0.12,2.8),palette.dark)
	# Empty windows and missing panels expose seats, engine and wheel arches.
	for x in [-0.88,0.88]:
		for z in [-1.22,1.22]:
			_box(Vector3(x,0.82,z),Vector3(0.16,0.14,1.04),paint)
			if not (kind==4 and x>0) and not (kind==5 and z<0):
				_wheel(Vector3(x,0.36,z),0.34)
			else:
				_cylinder(Vector3(x,0.28,z),0.13,0.14,palette.rust,8,Vector3(0,0,PI/2))
		for z in [-1.88,-0.67,0.67,1.87]:
			_box(Vector3(x,0.57,z),Vector3(0.15,0.46,0.22),paint)
		if not (kind==5 and x>0):
			var door_angle := -0.55 if kind==4 and x>0 else 0.0
			_box(Vector3(x+(0.2 if door_angle else 0.0),0.63,-0.05),Vector3(0.09,0.5,1.12),paint,Vector3(0,door_angle,0))
			_box(Vector3(x*1.06,0.8,0.18),Vector3(0.035,0.05,0.17),palette.dark)
		_box(Vector3(x,0.43,0),Vector3(0.12,0.09,1.9),palette.rust)
		_beam(Vector3(x,0.88,-0.78),Vector3(x*0.86,roof_y,-0.36),0.09,paint)
		_beam(Vector3(x*0.86,roof_y,rear),Vector3(x,0.86,rear+0.32),0.1,paint)
		if kind in [1,3]:
			_box(Vector3(x*0.91,1.1,0.5),Vector3(0.09,roof_y-0.8,0.1),paint)
		for j in 10:
			_box(Vector3(x*1.08,0.48+(j%3)*0.1,-1.75+j*0.36),Vector3(0.02,0.08,0.13),palette.rust)
		_box(Vector3(x*0.45,0.68,0.16),Vector3(0.52,0.28,0.53),Color("514d49"))
		_box(Vector3(x*0.45,0.87,0.41),Vector3(0.52,0.48,0.13),Color("645d54"),Vector3(0.12,0,0))
	if kind!=5:
		_box(Vector3(0,roof_y,roof_z),Vector3(1.57,0.1,rear+0.86),paint,Vector3(0.02,0,-0.04 if kind==4 else 0))
		_chips(Vector3(0,roof_y+0.06,roof_z),Vector2(1.3,rear+0.65),palette.rust,kind+83)
	else:
		_beam(Vector3(-0.76,roof_y,-0.36),Vector3(0.76,roof_y,-0.36),0.1,paint)
	_box(Vector3(0,0.76,-0.68),Vector3(1.6,0.2,0.2),palette.dark)
	_box(Vector3(0,0.6,-1.28),Vector3(0.85,0.4,0.65),palette.steel)
	for x in [-0.25,0,0.25]:
		_box(Vector3(x,0.83,-1.28),Vector3(0.08,0.08,0.55),palette.dark)
	if kind not in [4,5]:
		_box(Vector3(0,0.87,-1.34),Vector3(1.65,0.07,1.04),paint,Vector3(-0.07,0,0.025))
		_chips(Vector3(0,0.92,-1.3),Vector2(1.4,0.75),palette.rust,kind+39)
	elif kind==4:
		_box(Vector3(0,1.14,-0.99),Vector3(1.65,0.07,1.04),paint,Vector3(-0.7,0,-0.08))
	if kind==2:
		_box(Vector3(0,0.58,1.15),Vector3(1.6,0.07,1.4),palette.rust)
		for x in [-0.86,0.86]:
			_box(Vector3(x,0.9,1.15),Vector3(0.12,0.48,1.5),paint)
	else:
		_box(Vector3(0,0.84,1.65),Vector3(1.68,0.09,0.6),paint)
		_chips(Vector3(0,0.9,1.65),Vector2(1.4,0.4),palette.rust,kind+11)
	_box(Vector3(0,0.64,1.93),Vector3(1.76,0.4,0.1),paint)
	_box(Vector3(0,0.57,-1.94),Vector3(1.74,0.4,0.1),palette.dark)
	for x in [-0.63,0.63]:
		_box(Vector3(x,0.68,-2.01),Vector3(0.35,0.19,0.04),palette.cream if kind%2 else palette.rust)
	for x in range(-3,4):
		_box(Vector3(x*0.13,0.59,-2.01),Vector3(0.035,0.15,0.02),palette.steel)
	_box(Vector3(0,0.37,-2.02),Vector3(1.87,0.11,0.13),palette.steel,Vector3(0,0,0.06))

func _salvage(kind: int) -> void:
	if kind==0:
		# Hollow tire: the hole remains readable when piled on its side.
		for i in 12:
			var a := i*TAU/12.0
			_box(Vector3(cos(a)*0.32,0,sin(a)*0.32),Vector3(0.2,0.24,0.17),palette.rubber,Vector3(0,-a,0))
	elif kind==1:
		_box(Vector3(0,0,0),Vector3(0.85,1.15,0.65),palette.cream)
		_box(Vector3(0,0.02,0.34),Vector3(0.69,0.91,0.04),palette.dark)
		_cylinder(Vector3(0,-0.09,0.39),0.27,0.07,palette.steel,10,Vector3(PI/2,0,0))
		_cylinder(Vector3(0,-0.09,0.44),0.19,0.04,palette.dark,10,Vector3(PI/2,0,0))
		_box(Vector3(0,0.4,0.39),Vector3(0.62,0.12,0.04),palette.cream)
		_chips(Vector3(0,0.59,0),Vector2(0.7,0.5),palette.rust,36)
	elif kind==2:
		_box(Vector3(0,0,0),Vector3(1.6,0.05,0.95),Color("8b9e9b"))
		for x in range(-4,5):
			_box(Vector3(x*0.17,0.05,0),Vector3(0.07,0.06,0.95),palette.steel)
		_chips(Vector3(0,0.09,0),Vector2(1.4,0.8),palette.rust,17)
	else:
		for x in [-0.45,0.45]:
			_box(Vector3(x,0,0),Vector3(0.12,0.3,1.9),palette.rust)
		for z in [-0.8,0,0.8]:
			_box(Vector3(0,0,z),Vector3(1.02,0.26,0.12),palette.steel)

func _garage() -> void:
	_box(Vector3(0,0.13,0),Vector3(12,0.26,8),palette.sand,Vector3.ZERO,true)
	_box(Vector3(0,2,-3.7),Vector3(11.8,4,0.35),palette.cream,Vector3.ZERO,true)
	for x in [-5.7,5.7]:
		_box(Vector3(x,2,0),Vector3(0.35,4,7.4),palette.cream,Vector3.ZERO,true)
	_box(Vector3(-3.7,1.8,3.6),Vector3(4,3.6,0.32),palette.cream,Vector3.ZERO,true)
	_box(Vector3(0,4.05,0),Vector3(12.5,0.3,8.5),palette.rust,Vector3.ZERO,true)
	for x in range(-6,7):
		_box(Vector3(x,4.26,0),Vector3(0.075,0.06,8.4),palette.edge)
	_box(Vector3(-3.8,2.15,3.8),Vector3(2.8,1.1,0.05),palette.glass)
	for x in [-4.6,-3.8,-3.0]:
		_box(Vector3(x,2.15,3.86),Vector3(0.06,1.1,0.06),palette.edge)
	_box(Vector3(0,3.5,4.1),Vector3(12,0.65,1.4),palette.green)
	for x in [-5.5,5.5]:
		_box(Vector3(x,1.6,6.6),Vector3(0.18,3.2,0.18),palette.red,Vector3.ZERO,true)
	_box(Vector3(0,3.22,5.3),Vector3(12,0.16,3.6),palette.edge)
	for i in 7:
		_box(Vector3(-5.3+i*1.7,0.48,3.8),Vector3(0.8,0.3,0.05),palette.rust)
	_chips(Vector3(0,4.22,0),Vector2(11.8,7.8),palette.dark,14)
	_chips(Vector3(-3.8,1.8,3.8),Vector2(3.5,2.8),palette.sand,24,true)
	_box(Vector3(3.5,4.55,-1.9),Vector3(2.3,0.7,1.5),palette.steel)
	for x in range(10):
		_box(Vector3(2.5+x*0.22,4.93,-1.9),Vector3(0.07,0.035,1.3),palette.dark)
	for x in [1.0,3.8]:
		_box(Vector3(x,2.95,3.62),Vector3(2.5,0.65,0.15),palette.steel)
		for y in range(5):
			_box(Vector3(x,2.7+y*0.12,3.73),Vector3(2.5,0.035,0.07),palette.dark)
	_box(Vector3(-5.8,1.7,3.94),Vector3(0.12,3.4,0.13),palette.rust)
	_box(Vector3(5.85,1.6,2.4),Vector3(0.12,3.2,0.13),palette.rust)
	_box(Vector3(0,3.53,7.13),Vector3(11.8,0.32,0.12),palette.red)
	for x in range(-5,6):
		_box(Vector3(x,3.54,7.21),Vector3(0.16,0.34,0.025),palette.cream)
	_box(Vector3(5.89,0.65,0),Vector3(0.06,0.7,7.1),palette.green)
	for z in [-1.8,1.2]:
		_box(Vector3(5.91,2.4,z),Vector3(0.06,1.2,1.8),palette.glass)
		for offset in [-0.85,0,0.85]:
			_box(Vector3(5.95,2.4,z+offset),Vector3(0.08,1.24,0.065),palette.edge)
		_box(Vector3(6.02,1.77,z),Vector3(0.24,0.12,2.05),palette.sand)
	for z in [-3.45,3.45]:
		_box(Vector3(5.9,2.2,z),Vector3(0.12,3.6,0.12),palette.rust)
	for i in 13:
		_box(Vector3(5.94,0.4+(i%3)*0.11,-3.1+i*0.5),Vector3(0.04,0.13,0.24),palette.sand)

func _pump() -> void:
	_box(Vector3(0,0.12,0),Vector3(1.25,0.24,1.0),palette.cream,Vector3.ZERO,true)
	_box(Vector3(0,0.73,0),Vector3(0.83,1.1,0.65),palette.red,Vector3.ZERO,true)
	_box(Vector3(0,1.57,0),Vector3(1.0,0.65,0.72),palette.cream)
	_box(Vector3(0,1.65,0.37),Vector3(0.7,0.23,0.03),palette.dark)
	for x in [-0.2,0,0.2]:
		_box(Vector3(x,1.65,0.39),Vector3(0.08,0.12,0.02),palette.edge)
	_box(Vector3(0.62,1.1,0),Vector3(0.08,1,0.1),palette.rubber)
	_box(Vector3(0.56,0.6,0),Vector3(0.22,0.09,0.1),palette.rubber)

func _container() -> void:
	_box(Vector3(0,1.4,0),Vector3(6,2.8,2.5),Color("5e7f80"),Vector3.ZERO,true)
	for x in range(-14,15):
		for z in [-1.27,1.27]:
			_box(Vector3(x*0.2,1.4,z),Vector3(0.05,2.6,0.05),Color("78928d"))
	for y in [0.1,2.7]:
		_box(Vector3(0,y,1.3),Vector3(6,0.12,0.1),palette.dark)
	for z in [-0.55,0.55]:
		_box(Vector3(3.03,1.4,z),Vector3(0.08,2.5,0.07),palette.edge)

func _palm() -> void:
	for i in 24:
		var x := pow(i/24.0,2)*0.85
		_cylinder(Vector3(x,i*0.22+0.11,0),0.24-i*0.0035,0.23,palette.rust.lightened((i%3)*0.065),7)
	for i in 11:
		var a := i*TAU/11.0
		var forward := Vector3(cos(a),0,sin(a))
		var side := Vector3(-sin(a),0,cos(a))
		var length := 3.2+(i%3)*0.35
		var previous := Vector3(0.85,5.3,0)
		for j in range(1,10):
			var t := j/9.0
			var spine := Vector3(0.85,5.3+sin(t*PI)*0.6-t*t*1.7,0)+forward*t*length
			_beam(previous,spine,0.055,Color("9c965d"))
			for sign_value in [-1,1]:
				var tip: Vector3=spine+side*sign_value*sin(t*PI)*0.85+forward*0.4-Vector3.UP*0.26
				var c := Color("92934e").darkened((i%3)*0.09+(j%2)*0.05)
				var edge := spine-forward*0.18
				_triangle(edge,spine+forward*0.15,tip,c)
				_triangle(edge,tip,spine+forward*0.15,c.darkened(0.15))
			previous=spine
	for i in 5:
		_cylinder(Vector3(0.85+sin(i*4)*0.15,5.15,cos(i*4)*0.15),0.16,0.3,palette.dark,6)
	_collision(Vector3(0.35,2.4,0),Vector3(0.5,4.8,0.5))

func _pole() -> void:
	_cylinder(Vector3(0,4,0),0.17,8,palette.rust,6)
	_box(Vector3(0,7.45,0),Vector3(3.1,0.18,0.2),palette.dark)
	for x in [-1.35,-0.65,0.65,1.35]:
		_cylinder(Vector3(x,7.68,0),0.12,0.35,palette.cream,6)
	_collision(Vector3(0,4,0),Vector3(0.35,8,0.35))

func _fence() -> void:
	for x in [-2.5,2.5]:
		_box(Vector3(x,1.1,0),Vector3(0.12,2.2,0.12),palette.steel)
	for y in [0.35,1.15,2]:
		_box(Vector3(0,y,0),Vector3(5,0.06,0.06),palette.steel)
	for slope in [-1.0,1.0]:
		for i in range(-14,15):
			var start_x := i*0.3
			var t0 := maxf(0.0,(-2.5-start_x)*slope if slope>0 else (2.5-start_x)*slope)
			var t1 := minf(1.65,(2.5-start_x)*slope if slope>0 else (-2.5-start_x)*slope)
			if t1>t0:
				_beam(Vector3(start_x+t0*slope,0.35+t0,0),Vector3(start_x+t1*slope,0.35+t1,0),0.022,palette.cream)
	_collision(Vector3(0,1,0),Vector3(5,2,0.15))

func _tank() -> void:
	for x in [-1.4,1.4]:
		for z in [-1.4,1.4]:
			_box(Vector3(x,2,z),Vector3(0.18,4,0.18),palette.rust,Vector3.ZERO,true)
	_box(Vector3(0,3.6,0),Vector3(3.5,0.2,3.5),palette.steel)
	_cylinder(Vector3(0,5,0),1.6,2.6,palette.green,12)
	for y in [4.0,5.9]:
		_cylinder(Vector3(0,y,0),1.65,0.1,palette.dark,12)
	for y in range(1,10):
		_box(Vector3(1.7,y*0.4,0),Vector3(0.07,0.06,0.7),palette.edge)
	_collision(Vector3(0,5,0),Vector3(3.2,2.6,3.2))

func _relay() -> void:
	_box(Vector3(0,0.15,0),Vector3(5,0.3,5),palette.cream,Vector3.ZERO,true)
	_box(Vector3(0,1.6,0),Vector3(3.5,2.9,3.5),palette.green,Vector3.ZERO,true)
	_box(Vector3(0,3.1,0),Vector3(4,0.25,4),palette.edge)
	_box(Vector3(0,1.5,1.8),Vector3(1.1,2.5,0.08),palette.dark)
	for x in [-1.3,1.3]:
		_box(Vector3(x,5.5,0),Vector3(0.14,5,0.14),palette.steel)
	for y in [4.0,5.2,6.4,7.6]:
		_box(Vector3(0,y,0),Vector3(2.6,0.08,0.08),palette.steel)
	_cylinder(Vector3(0,7,0),1.2,0.12,palette.cream,12,Vector3(PI/3,0,0),0.7)
	_box(Vector3(0,8.2,0),Vector3(0.09,1.5,0.09),palette.dark)

func _cockpit(spec: Dictionary, cabin_front: float) -> void:
	var seat: Vector3 = spec.seat
	var w: float = spec.width
	var trim := Color("62684b") if spec.id in ["wc62","eq246"] else Color("45494b")
	var charcoal := Color("414344")
	var leather := Color("817859")
	if spec.id=="wrangler":
		leather=Color("6f4f3d")
	elif spec.id=="unimog":
		leather=Color("4f5b52")
	elif spec.id=="f150":
		leather=Color("343b3d")
	elif spec.id=="hilux":
		leather=Color("5e645d")
	elif spec.id=="eq246":
		leather=Color("707b54")
	elif spec.id=="wc62":
		leather=Color("6b6048")
	# Close the footwell at seat-relative height, including the taller truck cab.
	_box(Vector3(0,seat.y-0.88,seat.z-0.04),Vector3(w*0.97,0.10,1.96),charcoal)
	_box(Vector3(0,seat.y-0.69,cabin_front+0.04),Vector3(w*0.97,0.58,0.08),trim)
	for x in [-w*0.23,w*0.23]:
		_rounded_box(Vector3(x,seat.y-0.821,seat.z-0.44),Vector3(w*0.34,0.018,0.70),0.008,Color("303638"))
		for i in 9:
			_box(Vector3(x+(i-4)*0.045,seat.y-0.809,seat.z-0.44),Vector3(0.008,0.004,0.60),Color("4a5051"))
	var pedal_offsets: Array=[-0.08,0.09] if spec.id in ["f150","wrangler"] else [-0.14,0.0,0.14]
	for offset in pedal_offsets:
		var x: float=seat.x+offset
		_beam(Vector3(x,seat.y-0.55,cabin_front+0.08),Vector3(x,seat.y-0.78,seat.z-0.70),0.013,Color("81907c"))
		_rounded_box(Vector3(x,seat.y-0.78,seat.z-0.69),Vector3(0.07,0.10,0.025),0.012,charcoal,Vector3(-0.3,0,0))
		for row in 4:
			_box(Vector3(x,seat.y-0.81+row*0.02,seat.z-0.671-row*0.006),Vector3(0.051,0.004,0.004),Color("a1ac92"))
	_dashboard(spec)
	# Upholstery, piping and ribbed inserts are sized consistently across all cars.
	for x in [-w*0.23,w*0.23]:
		_rounded_box(Vector3(x,seat.y-0.76,seat.z+0.16),Vector3(w*0.30,0.18,0.65),0.065,charcoal)
		_rounded_box(Vector3(x,seat.y-0.66,seat.z+0.15),Vector3(w*0.26,0.08,0.51),0.035,leather)
		if spec.id=="wc62":
			_rounded_box(Vector3(x,seat.y-0.49,seat.z+0.43),Vector3(w*0.30,0.35,0.13),0.035,leather)
			continue
		_rounded_box(Vector3(x,seat.y-0.39,seat.z+0.5),Vector3(w*0.30,0.66,0.18),0.065,charcoal,Vector3(-0.1,0,0))
		_rounded_box(Vector3(x,seat.y-0.39,seat.z+0.39),Vector3(w*0.25,0.52,0.065),0.03,leather,Vector3(-0.1,0,0))
		for row in 6:
			_box(Vector3(x,seat.y-0.57+row*0.07,seat.z+0.354+(0.18-row*0.07)*0.1),Vector3(w*0.22,0.004,0.004),Color("b8ad83"),Vector3(-0.1,0,0))
			_box(Vector3(x,seat.y-0.618,seat.z+0.15+(row-2.5)*0.07),Vector3(w*0.22,0.003,0.003),Color("b8ad83"))
		for side in [-1,1]:
			_rounded_box(Vector3(x+side*w*0.125,seat.y-0.4,seat.z+0.36),Vector3(0.09,0.54,0.11),0.04,charcoal,Vector3(-0.1,0,0))
			_cylinder(Vector3(x+side*0.085,seat.y-0.015,seat.z+0.49),0.009,0.15,Color("a1ae97"),16)
		_rounded_box(Vector3(x,seat.y+0.07,seat.z+0.49),Vector3(0.30,0.18,0.12),0.048,leather)
	var vintage: bool=spec.id=="wc62"
	var automatic: bool=spec.id in ["f150","unimog"]
	var console_width: float=0.30 if spec.id=="f150" else 0.25 if spec.id=="unimog" else 0.18
	var console_y: float=seat.y-0.62 if automatic else seat.y-0.78
	_rounded_box(Vector3(0,console_y,seat.z-0.12),Vector3(console_width,0.18,0.72),0.035,charcoal)
	if automatic:
		for x in [-0.064,0.064]:
			_cylinder(Vector3(x,console_y+0.097,seat.z+0.07),0.043,0.008,Color("1f2425"),32)
			_ring(Vector3(x,console_y+0.105,seat.z+0.07),0.044,0.006,Color("717877"),Vector3(PI/2,0,0))
		_rounded_box(Vector3(0,console_y+0.11,seat.z+0.19),Vector3(console_width-0.025,0.05,0.13),0.02,leather)
	if spec.id!="unimog":
		for index in (1 if spec.id in ["f150","hilux"] else 2):
			var p:=Vector3(-0.035+index*0.09,console_y+0.10,seat.z-0.30+index*0.13)
			for ring in 4:
				_rounded_box(p+Vector3(0,ring*0.012,0),Vector3(0.07-ring*0.01,0.014,0.07-ring*0.01),0.005,charcoal)
			var lever_height: float=0.10 if spec.id=="f150" else 0.20
			_beam(p+Vector3(0,0.03,0),p+Vector3(0,lever_height-0.01,-0.025),0.025 if spec.id=="f150" else 0.012,Color("727778"))
			_rounded_box(p+Vector3(0,lever_height,-0.025),Vector3(0.065,0.045,0.055),0.020,charcoal)
	else:
		# U5023 uses a steering-column selector, not two floor gear levers.
		_beam(seat+Vector3(0.025,-0.40,-0.81),seat+Vector3(0.22,-0.34,-0.78),0.018,charcoal)
		_rounded_box(seat+Vector3(0.22,-0.34,-0.78),Vector3(0.07,0.038,0.035),0.012,charcoal)
	for side in [-1,1]:
		var x: float=side*(w*0.5-0.065)
		if vintage:
			# Exposed metal and canvas door strap; no modern padded door card.
			_rounded_box(Vector3(x,seat.y-0.63,seat.z+0.05),Vector3(0.035,0.22,1.12),0.012,Color("636a46"))
			_beam(Vector3(x,seat.y-0.26,seat.z-0.56),Vector3(x,seat.y-0.36,seat.z+0.45),0.028,Color("9b8e65"))
		else:
			_rounded_box(Vector3(x,seat.y-0.49,seat.z+0.05),Vector3(0.06,0.43,1.20),0.025,charcoal)
			_rounded_box(Vector3(x-side*0.033,seat.y-0.47,seat.z),Vector3(0.035,0.20,0.75),0.02,leather)
			_rounded_box(Vector3(x-side*0.067,seat.y-0.44,seat.z-0.03),Vector3(0.10,0.05,0.36),0.02,charcoal)
			_rounded_box(Vector3(x-side*0.043,seat.y-0.30,seat.z-0.35),Vector3(0.022,0.027,0.12),0.008,Color("949895"))
	# Thin wiper blades and rubber windshield seals give the aperture scale.
	for x in [-w*0.26,w*0.26]:
		_beam(Vector3(x,seat.y-0.2,cabin_front+0.045),Vector3(x-0.14,seat.y-0.11,cabin_front+0.045),0.013,charcoal)
		_rounded_box(Vector3(x-0.13,seat.y-0.11,cabin_front+0.052),Vector3(0.34,0.014,0.016),0.006,Color("1e3028"),Vector3(0,0,0.10))
	_beam(seat+Vector3(0,-0.62,-0.86),seat+Vector3(0,-0.39,-0.66),0.065,charcoal)
	_steering(spec)

func _vent(pos: Vector3, size: Vector2, round_vent := false) -> void:
	var frame:=Color("929690")
	var dark:=Color("22272a")
	if round_vent:
		_cylinder(pos,size.x/2,0.025,dark,40,Vector3(PI/2,0,0))
		_ring(pos+Vector3(0,0,0.016),size.x/2,0.007,frame)
	else:
		_rounded_box(pos,Vector3(size.x,size.y,0.03),0.013,frame)
		_rounded_box(pos+Vector3(0,0,0.018),Vector3(size.x-0.018,size.y-0.018,0.012),0.008,dark)
	for i in 5:
		var y: float=(i-2)*size.y*0.14
		var width: float=sqrt(maxf(0.0,pow(size.x/2-0.008,2)-y*y))*2 if round_vent else size.x-0.028
		_box(pos+Vector3(0,y,0.028),Vector3(width,0.004,0.012),Color("676c6d"))

func _knob(pos: Vector3, radius := 0.024) -> void:
	_cylinder(pos,radius,0.025,Color("292d2e"),32,Vector3(PI/2,0,0))
	_ring(pos+Vector3(0,0,0.014),radius-0.003,0.003,Color("9b9c94"))
	_box(pos+Vector3(0,radius*0.52,0.019),Vector3(0.003,radius*0.40,0.003),Color("dfd6be"))

func _aux_gauge(pos: Vector3, radius: float, caption: String) -> void:
	_cylinder(pos,radius,0.025,Color("232829"),32,Vector3(PI/2,0,0))
	_ring(pos+Vector3(0,0,0.015),radius,0.004,Color("898e83"))
	for i in 9:
		var a: float=deg_to_rad(-110+i*27.5)
		_box(pos+Vector3(sin(a)*radius*0.78,cos(a)*radius*0.78,0.018),Vector3(0.002,0.008,0.002),Color("dbd4bd"),Vector3(0,0,-a))
	_beam(pos+Vector3(0,0,0.02),pos+Vector3(-radius*0.24,radius*0.52,0.02),0.003,Color("d9c7a1"))
	_label(pos+Vector3(0,-radius*0.40,0.021),caption,radius*0.18)

func _screen(pos: Vector3, size: Vector2, title: String) -> void:
	_rounded_box(pos,Vector3(size.x+0.04,size.y+0.04,0.045),0.014,Color("242a2f"))
	_rounded_box(pos+Vector3(0,0,0.028),Vector3(size.x,size.y,0.01),0.006,Color("32494f"))
	_label(pos+Vector3(0,size.y*0.31,0.036),title,0.014,Color("b9d2cb"))
	for i in 4:
		_box(pos+Vector3((i-1.5)*size.x*0.22,-size.y*0.10,0.035),Vector3(size.x*0.15,size.y*0.30,0.002),Color("566e73"))

func _dashboard(spec: Dictionary) -> void:
	var seat: Vector3=spec.seat
	var w: float=spec.width
	var y: float=seat.y
	var z: float=seat.z-0.94
	var dark:=Color("41464a")
	var face:=Color("686b63")
	var vintage: bool=spec.id=="wc62"
	match spec.id:
		"wrangler": face=Color("943e35")
		"unimog": face=Color("565c5f")
		"f150": face=Color("434b53")
		"hilux": face=Color("565a5d")
		"eq246": face=Color("59634c")
		"wc62": face=Color("73784d")
		"ridge": face=Color("796450")
		"pickup": face=Color("716459")
		"hauler": face=Color("626963")
	# Every fascia has one front surface: switches and gauges sit in front of it.
	var dash_height: float=0.24 if vintage else 0.32
	_rounded_box(Vector3(0,y-0.36,z-0.10),Vector3(w*0.94,dash_height,0.20),0.015 if vintage else 0.045,face)
	if not vintage:
		_rounded_box(Vector3(0,y-0.205,z-0.12),Vector3(w*0.95,0.055,0.30),0.023,dark)
		_rounded_box(Vector3(w*0.30,y-0.43,z+0.013),Vector3(w*0.24,0.13,0.016),0.012,face.darkened(0.13))
		_rounded_box(Vector3(w*0.30,y-0.38,z+0.025),Vector3(0.075,0.016,0.016),0.005,Color("989b95"))
	var speed_pos:=Vector3(seat.x-0.095,y-0.33,z+0.04)
	if vintage:
		speed_pos=Vector3(-0.18,y-0.30,z+0.024)
	elif spec.id=="eq246":
		speed_pos=Vector3(seat.x,y-0.33,z+0.045)
	var readout_pos:=speed_pos+Vector3(0,-0.035,0.025)
	if spec.id=="f150":
		# Digital cluster, with the existing live speed needle rendered over the panel.
		_screen(Vector3(seat.x,y-0.33,z+0.02),Vector2(0.43,0.16),"P   TRAIL")
		_gauge(speed_pos,0.060,true)
		readout_pos=Vector3(seat.x+0.06,y-0.33,z+0.057)
		_label(readout_pos+Vector3(0,-0.027,0),"KM/H",0.010)
	else:
		if not vintage:
			_rounded_box(Vector3(seat.x,y-0.33,z+0.005),Vector3(0.48,0.22,0.055),0.04,dark.darkened(0.2))
		_gauge(speed_pos,0.077 if not vintage else 0.081,true,vintage)
		if spec.id not in ["wc62","eq246"]:
			_aux_gauge(Vector3(seat.x+0.10,y-0.33,z+0.04),0.068,"RPM")
	var readout:=_label(readout_pos,"000",0.018,Color("d4dec9"))
	readout.name="SpeedReadout"
	if vintage: readout.set_meta("unit_scale",1.0/1.609344)
	# One gameplay compass, kept separate from the historical vehicle instruments.
	var compass:=Vector3(w*0.34,y-0.125,z-0.06)
	_rounded_box(compass-Vector3(0,0,0.018),Vector3(0.11,0.10,0.07),0.018,dark)
	_gauge(compass,0.038,false)
	match spec.id:
		"wrangler":
			for x in [-w*0.41,-0.245,0.245,w*0.41]:
				_vent(Vector3(x,y-0.30,z+0.02),Vector2(0.12,0.12),true)
			_screen(Vector3(0,y-0.285,z+0.035),Vector2(0.28,0.17),"TRAIL / AUDIO")
			_rounded_box(Vector3(0,y-0.50,z-0.005),Vector3(0.39,0.20,0.13),0.025,dark)
			for x in [-0.115,0.0,0.115]: _knob(Vector3(x,y-0.46,z+0.075))
			for i in 4:
				_rounded_box(Vector3((i-1.5)*0.07,y-0.55,z+0.067),Vector3(0.048,0.03,0.022),0.004,dark.lightened(0.12))
			for x in [w*0.23,w*0.36]:
				_beam(Vector3(x,y-0.31,z+0.01),Vector3(x,y-0.31,z+0.10),0.032,dark)
			_beam(Vector3(w*0.23,y-0.31,z+0.10),Vector3(w*0.36,y-0.31,z+0.10),0.035,dark)
			for side in [-1,1]:
				var x: float=side*w*0.46
				for h in [-0.02,0.20]:
					_beam(Vector3(x,y+h,seat.z-0.98),Vector3(x,y+h,seat.z-0.89),0.026,dark)
				_beam(Vector3(x,y-0.02,seat.z-0.89),Vector3(x,y+0.20,seat.z-0.89),0.028,dark)
		"unimog":
			_rounded_box(Vector3(0,y-0.38,z+0.005),Vector3(0.48,0.39,0.08),0.03,Color("393f43"))
			for row in 2:
				for col in 5:
					_rounded_box(Vector3((col-2)*0.07,y-0.26-row*0.055,z+0.054),Vector3(0.05,0.035,0.016),0.005,Color("9c5349") if col==2 and row==0 else Color("646e70"))
			_vent(Vector3(-0.105,y-0.45,z+0.055),Vector2(0.13,0.09))
			_vent(Vector3(0.105,y-0.45,z+0.055),Vector2(0.13,0.09))
			for row in 3: _knob(Vector3(-0.29,y-0.29-row*0.085,z+0.04))
			for x in [-w*0.41,w*0.41]: _vent(Vector3(x,y-0.30,z+0.02),Vector2(0.11,0.17))
			_rounded_box(Vector3(w*0.28,y-0.29,z+0.008),Vector3(w*0.25,0.17,0.018),0.012,Color("3e4548"))
		"f150":
			_rounded_box(Vector3(w*0.28,y-0.29,z+0.008),Vector3(w*0.24,0.20,0.018),0.015,Color("747d80"))
			_rounded_box(Vector3(w*0.28,y-0.29,z+0.02),Vector3(w*0.23,0.17,0.012),0.012,Color("474f54"))
			_screen(Vector3(0,y-0.30,z+0.035),Vector2(0.33,0.21),"OFF ROAD / 4H")
			for x in [-0.265,0.265,-w*0.42,w*0.42]:
				_vent(Vector3(x,y-0.30,z+0.02),Vector2(0.10,0.20))
			_rounded_box(Vector3(0,y-0.49,z),Vector3(0.41,0.15,0.13),0.025,dark)
			for x in [-0.14,0.14]: _knob(Vector3(x,y-0.47,z+0.08),0.03)
			for i in 4:
				_box(Vector3((i-1.5)*0.04,y-0.47,z+0.075),Vector3(0.027,0.018,0.008),Color("818a8f"))
		"hilux":
			_screen(Vector3(0,y-0.27,z+0.03),Vector2(0.25,0.145),"AUDIO / 4WD")
			for x in [-0.085,0.085]: _vent(Vector3(x,y-0.16,z+0.015),Vector2(0.14,0.055))
			for x in [-w*0.41,w*0.41]: _vent(Vector3(x,y-0.30,z+0.015),Vector2(0.14,0.095))
			_rounded_box(Vector3(0,y-0.48,z+0.01),Vector3(0.32,0.21,0.08),0.026,Color("383d42"))
			for x in [-0.10,0.0,0.10]: _knob(Vector3(x,y-0.44,z+0.065))
			_rounded_box(Vector3(w*0.28,y-0.285,z+0.018),Vector3(w*0.22,0.13,0.012),0.015,Color("656a6b"))
			_box(Vector3(w*0.28,y-0.35,z+0.028),Vector3(w*0.24,0.012,0.01),Color("9a9e9a"))
		"eq246":
			# The series reference has a raised four-gauge pod above the switch panel.
			_rounded_box(Vector3(0.08,y-0.16,z-0.08),Vector3(0.51,0.14,0.08),0.012,dark)
			for i in 4:
				_aux_gauge(Vector3(-0.10+i*0.12,y-0.16,z-0.028),0.047,["OIL","TEMP","FUEL","AIR"][i])
			for x in [-w*0.40,w*0.40]: _vent(Vector3(x,y-0.30,z+0.024),Vector2(0.11,0.12))
			for i in 6:
				var p:=Vector3(-0.10+i*0.07,y-0.43,z+0.03)
				_rounded_box(p,Vector3(0.043,0.047,0.022),0.005,dark.darkened(0.1))
				_box(p+Vector3(0,0.008,0.016),Vector3(0.018,0.004,0.006),Color("d0bc83"))
			_label(Vector3(w*0.28,y-0.29,z+0.028),"24 V  /  6 x 6",0.018)
		"wc62":
			for i in 4:
				var x: float=[-0.42,-0.31,-0.035,0.075][i]
				_aux_gauge(Vector3(x,y-0.30,z+0.024),0.041,["AMP","OIL","FUEL","TEMP"][i])
			for x in [-0.43,-0.28,-0.13,0.02,0.17]: _knob(Vector3(x,y-0.40,z+0.032),0.018)
			for x in [w*0.20,w*0.34]:
				_rounded_box(Vector3(x,y-0.34,z+0.013),Vector3(0.21,0.12,0.012),0.005,Color("3c4438"))
				_label(Vector3(x,y-0.32,z+0.022),"GEAR / RANGE",0.012)
				_label(Vector3(x,y-0.36,z+0.022),"1  2  3  4   R",0.010)
			_label(Vector3(w*0.25,y-0.22,z+0.016),"MAX SPEED 40 MPH",0.016)
		_:
			for x in [-w*0.40,w*0.40]:
				_vent(Vector3(x,y-0.29,z+0.022),Vector2(0.13,0.10),spec.id=="ridge")
			if spec.id=="hauler":
				for i in 3: _aux_gauge(Vector3(-0.03+i*0.14,y-0.29,z+0.023),0.049,["AIR","FUEL","TEMP"][i])
			elif spec.id=="ridge":
				for i in 4:
					_rounded_box(Vector3((i-1.5)*0.065,y-0.30,z+0.022),Vector3(0.043,0.055,0.025),0.005,dark)
			else:
				_screen(Vector3(0,y-0.30,z+0.025),Vector2(0.25,0.10),"FM  /  TRAIL")
			for x in [-0.10,0.0,0.10]: _knob(Vector3(x,y-0.43,z+0.035),0.020)

func _fender(x: float, z: float, radius: float, color: Color) -> void:
	for i in 12:
		var a := -PI/2+(i+0.5)*PI/12
		_rounded_box(Vector3(x,-0.16+cos(a)*radius,z+sin(a)*radius),Vector3(0.25,0.09,radius*0.29),0.025,color,Vector3(a,0,0))

func _round_lamp(pos: Vector3, radius: float) -> void:
	_cylinder(pos,radius+0.03,0.055,palette.dark,32,Vector3(PI/2,0,0))
	_cylinder(pos+Vector3(0,0,-0.032),radius,0.015,Color("eadab4"),32,Vector3(PI/2,0,0))
	_box(pos+Vector3(0,0,-0.044),Vector3(radius*1.4,0.014,0.006),Color("fff0cd"))

func _cargo_bed(spec: Dictionary, start: float) -> void:
	var w: float=spec.width
	var rear: float=spec.length/2
	var length := rear-start
	var paint := Color(spec.color)
	var military: bool=spec.id in ["eq246","wc62"]
	var base := 0.70 if not military else 0.91
	_box(Vector3(0,base,(start+rear)/2),Vector3(w*0.91,0.1,length),palette.dark)
	for side in [-1,1]:
		_rounded_box(Vector3(side*w*0.47,base+0.25,(start+rear)/2),Vector3(0.12,0.5,length),0.045,paint)
		for j in range(1,5):
			var z := lerpf(start,rear,j/5.0)
			_box(Vector3(side*w*0.499,base+0.25,z),Vector3(0.035,0.43,0.055),paint.lightened(0.12))
		if military:
			for row in 3:
				_box(Vector3(side*w*0.465,base+0.4+row*0.17,(start+rear)/2),Vector3(0.07,0.11,length),paint.lightened(0.05*row))
	_rounded_box(Vector3(0,base+0.25,rear),Vector3(w*0.98,0.5,0.12),0.035,paint)
	_rounded_box(Vector3(0,base+0.4,rear+0.07),Vector3(0.24,0.045,0.025),0.01,palette.steel)
	for x in [-w*0.36,w*0.36]:
		_rounded_box(Vector3(x,base+0.24,rear+0.07),Vector3(0.12,0.31,0.035),0.015,palette.red)
	for x in range(-3,4):
		_box(Vector3(x*w*0.11,base+0.06,(start+rear)/2),Vector3(0.025,0.025,length-0.15),palette.steel)
	if spec.id in ["eq246","hauler","wc62"]:
		for j in 4:
			var z := lerpf(start+0.15,rear-0.12,j/3.0)
			for side in [-1,1]:
				_beam(Vector3(side*w*0.45,base+0.3,z),Vector3(side*w*0.45,2.15,z),0.045,palette.dark)
				_beam(Vector3(side*w*0.45,2.15,z),Vector3(side*w*0.32,2.45,z),0.045,palette.dark)
			_beam(Vector3(-w*0.32,2.45,z),Vector3(w*0.32,2.45,z),0.045,palette.dark)
		if spec.id=="eq246":
			_box(Vector3(0,2.47,(start+rear)/2),Vector3(w*0.66,0.08,length),Color("8e9174"))
			for side in [-1,1]:
				_box(Vector3(side*w*0.4,2.30,(start+rear)/2),Vector3(w*0.24,0.06,length),Color("85896c"),Vector3(0,0,side*0.7))
				_box(Vector3(side*w*0.455,1.92,(start+rear)/2),Vector3(0.04,0.52,length),Color("747b5f"))
				for j in 12:
					_box(Vector3(side*w*0.46,1.62,start+length*(j+0.5)/12),Vector3(0.025,0.18,0.018),palette.cream)
	if spec.id in ["pickup","f150","hilux"]:
		for side in [-1,1]:
			_beam(Vector3(side*w*0.38,base+0.13,start+0.22),Vector3(side*w*0.38,1.7,start+0.22),0.07,palette.steel)
		_beam(Vector3(-w*0.38,1.7,start+0.22),Vector3(w*0.38,1.7,start+0.22),0.07,palette.steel)

func _expedition_vehicle(spec: Dictionary) -> void:
	var w: float=spec.width
	var l: float=spec.length
	var roof: float=spec.roof
	var seat: Vector3=spec.seat
	var paint := Color(spec.color)
	var front := -l/2
	var cabin_front := seat.z-1.02
	var wagon: bool=spec.id in ["scout","wrangler"]
	var open_cab: bool=spec.id in ["ridge","wc62"]
	var cabin_back: float=l/2-0.3 if wagon else seat.z+(1.12 if spec.id in ["f150","hilux"] else 0.9)
	var cabin_length := cabin_back-cabin_front
	var sill := seat.y-0.35
	var wheel_side: float=0.56 if spec.axles.size()==3 else 0.52
	var rake: float=0.26 if spec.id in ["f150","hilux","pickup"] else 0.10 if spec.id in ["scout","unimog"] else 0.03
	var hood_y: float=seat.y-0.55 if spec.id in ["unimog","eq246"] else 0.86
	var hood_width: float=w*(0.64 if spec.id=="wc62" else 0.84 if spec.id=="wrangler" else 0.96)
	# Ladder chassis, axles, differential housings and separate curved wheel arches.
	for side in [-1,1]:
		_box(Vector3(side*w*0.30,0.02,0),Vector3(0.11,0.20,l),palette.dark)
	for z in spec.axles:
		_cylinder(Vector3(0,-0.20,z),0.065,w*1.04,palette.steel,16,Vector3(0,0,PI/2))
		_rounded_box(Vector3(0,-0.20,z),Vector3(0.3,0.24,0.25),0.075,palette.dark)
		for side in [-1,1]:
			_fender(side*w*wheel_side,z,spec.radius+0.17,palette.dark if spec.id in ["ridge","wrangler","f150"] else paint)
	_rounded_box(Vector3(0,0.22,0),Vector3(w*0.77,0.26,l*0.97),0.10,paint)
	_rounded_box(Vector3(0,hood_y-0.14,(front+cabin_front)/2),Vector3(hood_width,0.36,maxf(0.10,cabin_front-front)),0.09,paint)
	for side in [-1,1]:
		_box(Vector3(side*hood_width*0.34,hood_y+0.046,(front+cabin_front)/2),Vector3(0.035,0.018,maxf(0.08,cabin_front-front-0.2)),paint.lightened(0.18))
		_rounded_box(Vector3(side*w/2,(sill+0.42)/2,(cabin_front+cabin_back)/2),Vector3(0.09,sill-0.42,cabin_length),0.035,paint)
		for z in [cabin_front,cabin_back]:
			_rounded_box(Vector3(side*w/2,(roof+sill)/2,z+(rake/2 if z==cabin_front else 0)),Vector3(0.075,roof-sill,0.085),0.025,paint.lightened(0.12),Vector3(atan2(rake,roof-sill) if z==cabin_front else 0,0,0))
			_rounded_box(Vector3(side*w*0.48,(roof+sill)/2,z+0.015),Vector3(0.022,roof-sill,0.025),0.009,palette.dark)
		_beam(Vector3(side*w/2,seat.y-0.25,cabin_front+0.10),Vector3(side*w*0.60,seat.y-0.18,cabin_front+0.05),0.028,palette.steel)
		_rounded_box(Vector3(side*w*0.60,seat.y-0.10,cabin_front+0.04),Vector3(0.20,0.25,0.08),0.035,palette.dark)
		_rounded_box(Vector3(side*w*0.60,seat.y-0.10,cabin_front+0.086),Vector3(0.17,0.22,0.014),0.02,Color("90a8a1"))
		_rounded_box(Vector3(side*w*0.54,0.05,seat.z),Vector3(0.23,0.09,1.50),0.03,palette.steel)
		for z in ([seat.z-0.20,seat.z+0.62] if spec.id in ["f150","hilux","wrangler"] else [seat.z+0.18]):
			_box(Vector3(side*w*0.507,(sill+0.5)/2,z-0.36),Vector3(0.012,sill-0.5,0.016),paint.darkened(0.35))
			_rounded_box(Vector3(side*w*0.52,sill-0.18,z),Vector3(0.045,0.035,0.17),0.01,palette.steel)
			if spec.id=="wrangler":
				for y in [0.55,0.9]:
					_box(Vector3(side*w*0.523,y,z-0.34),Vector3(0.045,0.065,0.10),paint.lightened(0.1))
		if not open_cab:
			var window_x: float=side*w/2
			if spec.id=="wrangler":
				# JL-style removable door glazing: a short front door pane and a
				# separate rear quarter pane under the squared hardtop.
				_window_quad([Vector3(window_x,sill+0.06,cabin_front+0.08),Vector3(window_x,roof-0.06,cabin_front+rake+0.09),Vector3(window_x,roof-0.06,seat.z+0.22),Vector3(window_x,sill+0.06,seat.z+0.18)])
				_window_quad([Vector3(window_x,sill+0.06,seat.z+0.34),Vector3(window_x,roof-0.06,seat.z+0.30),Vector3(window_x,roof-0.06,cabin_back-0.06),Vector3(window_x,sill+0.06,cabin_back-0.06)])
			elif spec.id in ["f150","hilux"]:
				# Double-cab pickups use two framed panes with a pronounced B-pillar.
				_window_quad([Vector3(window_x,sill+0.06,cabin_front+0.06),Vector3(window_x,roof-0.06,cabin_front+rake+0.07),Vector3(window_x,roof-0.06,seat.z-0.08),Vector3(window_x,sill+0.06,seat.z-0.13)])
				_window_quad([Vector3(window_x,sill+0.06,seat.z+0.08),Vector3(window_x,roof-0.06,seat.z+0.03),Vector3(window_x,roof-0.06,cabin_back-0.06),Vector3(window_x,sill+0.06,cabin_back-0.06)])
			elif spec.id=="unimog":
				# The high U5023 cab has one large, nearly rectangular side pane.
				_window_quad([Vector3(window_x,sill+0.06,cabin_front+0.07),Vector3(window_x,roof-0.06,cabin_front+0.10),Vector3(window_x,roof-0.06,cabin_back-0.05),Vector3(window_x,sill+0.06,cabin_back-0.05)])
			else:
				_window_quad([Vector3(window_x,sill+0.06,cabin_front+0.05),Vector3(window_x,roof-0.06,cabin_front+rake+0.05),Vector3(window_x,roof-0.06,cabin_back-0.05),Vector3(window_x,sill+0.06,cabin_back-0.05)])
			_box(Vector3(side*w/2,(roof+sill)/2,seat.z+0.43),Vector3(0.07,roof-sill,0.07),paint)
			if spec.id in ["wrangler","f150","hilux"]:
				_box(Vector3(window_x,(roof+sill)/2,seat.z+0.02),Vector3(0.055,roof-sill-0.08,0.055),paint.darkened(0.18))
	if not open_cab:
		_rounded_box(Vector3(0,roof,(cabin_front+rake+cabin_back)/2),Vector3(w,0.12,cabin_length-rake+0.14),0.05,palette.dark if spec.id=="wrangler" else paint)
		_rounded_box(Vector3(0,roof-0.065,(cabin_front+cabin_back)/2),Vector3(w-0.14,0.035,cabin_length),0.014,Color("9a9c7b"))
	else:
		for z in [cabin_front,cabin_back]:
			_beam(Vector3(-w/2,roof,z),Vector3(w/2,roof,z),0.06,palette.dark)
		if spec.id=="ridge":
			for side in [-1,1]:
				_beam(Vector3(side*w/2,roof,cabin_front),Vector3(side*w/2,roof,cabin_back),0.07,palette.dark)
			_box(Vector3(0,roof+0.01,seat.z+0.35),Vector3(w,0.035,0.85),Color("ac9476"))
	_window_quad([Vector3(-w*0.46,sill+0.06,cabin_front),Vector3(w*0.46,sill+0.06,cabin_front),Vector3(w*0.46,roof-0.06,cabin_front+rake),Vector3(-w*0.46,roof-0.06,cabin_front+rake)])
	if spec.id in ["wc62","eq246"]:
		_box(Vector3(0,(roof+sill)/2,cabin_front-0.025),Vector3(0.035,roof-sill,0.04),paint)
	if not open_cab:
		_glass(Vector3(0,(roof+sill)/2,cabin_back),Vector3(w*0.92,roof-sill-0.12,0.025))
	_box(Vector3(0,(sill+0.5)/2,cabin_back),Vector3(w,sill-0.5,0.12),paint)
	_cockpit(spec,cabin_front)
	if spec.id in ["unimog","eq246"]:
		_rounded_box(Vector3(0,(hood_y+0.3)/2,front+0.02),Vector3(w*0.96,hood_y-0.3,0.16),0.05,paint)
	# Each front treatment has its own silhouette, lamps and grille geometry.
	var nose_y := hood_y-0.18
	_rounded_box(Vector3(0,nose_y,front-0.025),Vector3(hood_width,0.52,0.09),0.04,paint)
	if spec.id in ["wrangler","wc62","unimog"]:
		var grille_w := w*(0.42 if spec.id=="wc62" else 0.49)
		_box(Vector3(0,nose_y,front-0.08),Vector3(grille_w,0.37,0.03),palette.dark)
		for i in (7 if spec.id=="wrangler" else 9):
			var x := (float(i)/float(6 if spec.id=="wrangler" else 8)-0.5)*grille_w*0.94
			_rounded_box(Vector3(x,nose_y,front-0.103),Vector3(0.035,0.34,0.028),0.012,paint if spec.id=="wrangler" else palette.steel)
		for side in [-1,1]:
			_round_lamp(Vector3(side*w*0.36,nose_y,front-0.07),0.14 if spec.id!="unimog" else 0.17)
	elif spec.id=="f150":
		_rounded_box(Vector3(0,nose_y,front-0.08),Vector3(w*0.84,0.46,0.07),0.05,palette.dark)
		for row in 4:
			_box(Vector3(0,nose_y-0.14+row*0.09,front-0.12),Vector3(w*0.50,0.025,0.015),palette.steel)
		for side in [-1,1]:
			for y in [-0.17,0.17]:
				_box(Vector3(side*w*0.34,nose_y+y,front-0.13),Vector3(0.28,0.04,0.025),Color("e9e1bd"))
			_box(Vector3(side*w*0.41,nose_y,front-0.13),Vector3(0.04,0.36,0.025),Color("e9e1bd"))
		for x in [-0.15,0.0,0.15]:
			_box(Vector3(x,nose_y+0.25,front-0.11),Vector3(0.05,0.025,0.015),Color("cfa358"))
	elif spec.id=="hilux":
		for row in 5:
			_rounded_box(Vector3(0,nose_y-0.16+row*0.07,front-0.09),Vector3(w*(0.38+row*0.045),0.055,0.035),0.015,palette.dark)
		for side in [-1,1]:
			_rounded_box(Vector3(side*w*0.36,nose_y+0.13,front-0.095),Vector3(w*0.22,0.11,0.035),0.025,Color("ede4c7"),Vector3(0,0,-side*0.10))
			_round_lamp(Vector3(side*w*0.40,nose_y-0.23,front-0.09),0.06)
	else:
		_box(Vector3(0,nose_y,front-0.08),Vector3(w*0.58,0.32,0.03),palette.dark)
		for row in 4:
			_box(Vector3(0,nose_y-0.12+row*0.08,front-0.105),Vector3(w*0.54,0.025,0.025),palette.steel)
		for side in [-1,1]:
			if spec.id=="ridge":
				_round_lamp(Vector3(side*w*0.37,nose_y,front-0.08),0.12)
			else:
				_rounded_box(Vector3(side*w*0.38,nose_y,front-0.08),Vector3(0.28,0.18,0.045),0.03,Color("eee0b8"))
	# Reference-specific body signatures. These are deliberately structural details so the
	# silhouettes remain readable in the garage and in the chase camera at a distance.
	if spec.id=="wrangler":
		# Squared removable hardtop, exposed hinges, black arch flares and tow hooks.
		for side in [-1,1]:
			for z in [cabin_front+0.18,cabin_back-0.20]:
				_cylinder(Vector3(side*w*0.532,seat.y+0.1,z),0.055,0.11,palette.dark,12,Vector3(0,0,PI/2))
			_rounded_box(Vector3(side*w*0.56,0.37,0.02),Vector3(0.16,0.12,2.85),0.035,palette.dark)
		for x in [-0.22,0.22]:
			_box(Vector3(x,hood_y+0.19,front+0.33),Vector3(0.06,0.045,0.18),palette.dark,Vector3(0,0.12,0))
		for side in [-1,1]:
			_cylinder(Vector3(side*w*0.31,0.23,front-0.23),0.045,0.32,palette.red,12,Vector3(PI/2,0,0))
			_beam(Vector3(side*w*0.55,0.42,front+0.2),Vector3(side*w*0.55,0.42,front+1.0),0.055,palette.dark)
	elif spec.id=="unimog":
		# Tall cab-over proportions: portal hubs, visor, split glass and wide expedition steps.
		for z in spec.axles:
			for side in [-1,1]:
				_cylinder(Vector3(side*w*0.57,-0.20,z),0.19,0.10,palette.steel,16,Vector3(0,0,PI/2))
				_cylinder(Vector3(side*w*0.57,-0.20,z),0.08,0.112,palette.dark,12,Vector3(0,0,PI/2))
		_beam(Vector3(-w*0.39,roof+0.16,cabin_front-0.05),Vector3(w*0.39,roof+0.16,cabin_front-0.05),0.075,palette.dark)
		_box(Vector3(0,roof+0.10,cabin_front-0.13),Vector3(w*0.82,0.12,0.28),paint)
		for side in [-1,1]:
			_beam(Vector3(side*w*0.52,seat.y+0.12,cabin_front+0.18),Vector3(side*w*0.70,seat.y+0.15,cabin_front+0.18),0.035,palette.dark)
			_rounded_box(Vector3(side*w*0.72,seat.y+0.18,cabin_front+0.18),Vector3(0.20,0.24,0.07),0.025,palette.glass)
			_rounded_box(Vector3(side*w*0.53,0.22,seat.z+0.18),Vector3(0.30,0.13,0.72),0.035,palette.dark)
	elif spec.id=="f150":
		# Wide crew-cab shoulders, raised centre bonnet, squared flares and a sports bed.
		_rounded_box(Vector3(0,hood_y+0.12,front+0.42),Vector3(w*0.43,0.13,0.72),0.045,paint.lightened(0.08))
		for side in [-1,1]:
			_fender(side*w*0.55,spec.axles[0],spec.radius+0.22,Color("27343d"))
			_fender(side*w*0.55,spec.axles[1],spec.radius+0.22,Color("27343d"))
			_rounded_box(Vector3(side*w*0.56,0.68,seat.z-0.03),Vector3(0.14,0.16,1.9),0.035,Color("27343d"))
			_rounded_box(Vector3(side*w*0.52,seat.y+0.18,cabin_front+0.24),Vector3(0.20,0.12,0.07),0.025,palette.dark)
		for row in 2:
			_box(Vector3(0,hood_y+0.20+row*0.055,front+0.42),Vector3(0.12,0.018,0.38),palette.dark)
	elif spec.id=="hilux":
		# Narrower Japanese utility silhouette: snorkel, bull bar, slanted lamps and bed hoop.
		_beam(Vector3(w*0.39,0.70,front+0.16),Vector3(w*0.39,1.50,front+0.16),0.055,palette.dark)
		_beam(Vector3(w*0.39,1.50,front+0.16),Vector3(w*0.42,1.68,front+0.16),0.055,palette.dark)
		for side in [-1,1]:
			_beam(Vector3(side*w*0.48,0.38,front-0.18),Vector3(side*w*0.48,0.58,front+0.42),0.045,palette.dark)
			_rounded_box(Vector3(side*w*0.53,0.56,seat.z),Vector3(0.11,0.13,1.78),0.03,palette.dark)
		for x in [-w*0.36,w*0.36]:
			_beam(Vector3(x,0.79,cabin_back+0.16),Vector3(x,1.64,cabin_back+0.16),0.055,palette.dark)
		_beam(Vector3(-w*0.36,1.64,cabin_back+0.16),Vector3(w*0.36,1.64,cabin_back+0.16),0.055,palette.dark)
	elif spec.id=="eq246":
		# Tall military cab-over: split windscreen, corner markers, mirrors and recovery bar.
		for side in [-1,1]:
			_box(Vector3(side*w*0.42,nose_y+0.22,front-0.13),Vector3(0.09,0.22,0.035),Color("e7bd65"))
			_beam(Vector3(side*w*0.48,seat.y+0.20,cabin_front+0.15),Vector3(side*w*0.70,seat.y+0.24,cabin_front+0.15),0.04,palette.dark)
			_rounded_box(Vector3(side*w*0.72,seat.y+0.28,cabin_front+0.15),Vector3(0.20,0.24,0.08),0.02,palette.glass)
		_beam(Vector3(-w*0.45,0.42,front-0.22),Vector3(w*0.45,0.42,front-0.22),0.075,palette.dark)
		for side in [-1,1]:
			_cylinder(Vector3(side*w*0.31,0.18,front-0.27),0.05,0.30,palette.red,12,Vector3(PI/2,0,0))
	elif spec.id=="wc62":
		# Open-cab 6x6 profile: long bonnet, canvas hoops, wood slat sides and round lamps.
		for side in [-1,1]:
			_beam(Vector3(side*w*0.49,0.42,cabin_front+0.08),Vector3(side*w*0.49,1.66,cabin_front+0.08),0.055,palette.dark)
			_rounded_box(Vector3(side*w*0.53,0.38,seat.z),Vector3(0.13,0.14,1.7),0.03,palette.dark)
		for z in [cabin_front+0.18,cabin_front+0.58]:
			_beam(Vector3(-w*0.47,roof-0.03,z),Vector3(w*0.47,roof-0.03,z),0.05,palette.dark)
		for side in [-1,1]:
			for z in [cabin_back+0.2,cabin_back+0.85,cabin_back+1.5]:
				_box(Vector3(side*w*0.505,1.23,z),Vector3(0.04,0.62,0.07),Color("765c42"))
		for side in [-1,1]:
			_cylinder(Vector3(side*w*0.36,nose_y+0.02,front-0.10),0.13,0.065,Color("e0c98f"),24,Vector3(PI/2,0,0))
	for z in [front-0.12,l/2+0.09]:
		_rounded_box(Vector3(0,0.19,z),Vector3(w+0.12,0.22,0.23),0.055,palette.dark)
		for x in [-w*0.3,w*0.3]:
			_rounded_box(Vector3(x,0.17,z+(-0.12 if z<0 else 0.12)),Vector3(0.10,0.10,0.06),0.035,palette.red)
	_rounded_box(Vector3(0,0.36,front-0.17),Vector3(0.45,0.13,0.20),0.035,palette.steel)
	if wagon or spec.id=="ridge":
		_cylinder(Vector3(0,0.9,l/2+0.12),spec.radius,0.28,palette.rubber,32,Vector3(PI/2,0,0))
		_cylinder(Vector3(0,0.9,l/2+0.27),spec.radius*0.5,0.04,palette.steel,24,Vector3(PI/2,0,0))
		for side in [-1,1]:
			_rounded_box(Vector3(side*w*0.38,0.75,l/2),Vector3(0.16,0.22,0.06),0.025,palette.red)
		if spec.id=="scout":
			for side in [-1,1]:
				_box(Vector3(side*w*0.42,roof+0.14,seat.z+0.4),Vector3(0.06,0.18,1.7),palette.dark)
			for z in [-0.4,0.3,1.0]:
				_box(Vector3(0,roof+0.1,z),Vector3(w*0.85,0.05,0.06),palette.dark)
			_rounded_box(Vector3(0.25,roof+0.3,0.55),Vector3(0.6,0.32,0.75),0.04,palette.sand)
	elif spec.id=="unimog":
		var length := l/2-cabin_back-0.17
		var center := (cabin_back+0.17+l/2)/2
		_rounded_box(Vector3(0,1.62,center),Vector3(w*0.92,2.0,length),0.12,Color("cec6aa"))
		for side in [-1,1]:
			_rounded_box(Vector3(side*w*0.468,1.95,center),Vector3(0.025,0.52,length*0.45),0.01,palette.dark)
			_glass(Vector3(side*w*0.48,1.95,center),Vector3(0.02,0.44,length*0.40))
			for y in [0.78,2.48]:
				_box(Vector3(side*w*0.466,y,center),Vector3(0.025,0.05,length-0.16),palette.steel)
		for y in [0.75,1.0,1.25,1.5,1.75,2.0]:
			_box(Vector3(w*0.32,y,l/2+0.10),Vector3(0.40,0.035,0.035),palette.steel)
		for x in [w*0.23,w*0.41]:
			_box(Vector3(x,1.4,l/2+0.10),Vector3(0.035,1.55,0.035),palette.steel)
	else:
		_cargo_bed(spec,cabin_back+0.12)
	_precision_detail_pass(spec,front,cabin_front,cabin_back)
	if spec.id in ["scout","wrangler","unimog","eq246","hilux"]:
		_rounded_box(Vector3(w*0.48,roof-0.47,cabin_front-0.10),Vector3(0.075,1.25,0.075),0.03,palette.dark)
		_rounded_box(Vector3(w*0.48,roof+0.12,cabin_front-0.11),Vector3(0.14,0.09,0.16),0.03,palette.dark)
	for side in [-1,1]:
		for z in spec.axles:
			_box(Vector3(side*w*wheel_side,-0.12,z+spec.radius+0.17),Vector3(0.34,0.34,0.045),palette.rubber)
	if spec.id=="eq246":
		for side in [-1,1]:
			for y in [0.13,0.43,0.73]:
				_box(Vector3(side*w*0.54,y,seat.z),Vector3(0.22,0.06,0.55),palette.steel)
	if spec.id=="ridge":
		for x in [-0.45,-0.15,0.15,0.45]:
			_round_lamp(Vector3(x,roof+0.13,cabin_front),0.07)

func _precision_detail_pass(spec: Dictionary, front: float, cabin_front: float, cabin_back: float) -> void:
	# Small, structural seams and hardware give the generated blockout a readable CAD-like finish.
	var w: float=spec.width
	var seat: Vector3=spec.seat
	var paint:=Color(spec.color)
	var dark:=Color("252b2d")
	var trim:=Color("8d9189")
	for side in [-1,1]:
		var x: float=side*w*0.505
		# Door shut line, handle, hinge barrels and lower sill cap.
		_beam(Vector3(x,seat.y-0.40,cabin_front+0.18),Vector3(x,seat.y-0.40,cabin_back-0.14),0.010,dark)
		_rounded_box(Vector3(x+side*0.012,seat.y-0.26,seat.z+0.12),Vector3(0.035,0.028,0.17),0.008,trim)
		for z in [cabin_front+0.18,cabin_back-0.18]:
			_cylinder(Vector3(x+side*0.014,seat.y-0.18,z),0.018,0.055,dark,12,Vector3(0,0,PI/2))
		_rounded_box(Vector3(x,0.46,seat.z+0.01),Vector3(0.07,0.07,cabin_back-cabin_front-0.15),0.018,paint.darkened(0.14))
		# Belt anchors and a visible shoulder belt edge in the cabin.
		_rounded_box(Vector3(side*w*0.38,seat.y-0.12,seat.z+0.48),Vector3(0.05,0.04,0.06),0.012,trim)
		_beam(Vector3(side*w*0.38,seat.y-0.10,seat.z+0.46),Vector3(side*w*0.27,seat.y-0.52,seat.z+0.18),0.012,Color("a7a899"))
	# Dashboard top stitch, defroster slots and a centered VIN-style plate.
	_beam(Vector3(-w*0.43,seat.y-0.18,seat.z-0.97),Vector3(w*0.43,seat.y-0.18,seat.z-0.97),0.010,trim)
	for x in [-w*0.30,-w*0.15,0.0,w*0.15,w*0.30]:
		_rounded_box(Vector3(x,seat.y-0.20,seat.z-0.98),Vector3(0.075,0.018,0.025),0.006,dark)
	_rounded_box(Vector3(0,seat.y-0.42,seat.z-0.995),Vector3(0.18,0.035,0.012),0.004,trim)
	# Underbody skid plate and front recovery points reinforce the off-road silhouette.
	_rounded_box(Vector3(0,0.08,front+0.18),Vector3(w*0.66,0.16,0.34),0.045,Color("444b4a"))
	for side in [-1,1]:
		_cylinder(Vector3(side*w*0.30,0.26,front-0.17),0.035,0.18,Color("bd6b46"),12,Vector3(PI/2,0,0))
		_rounded_box(Vector3(side*w*0.42,0.44,front+0.32),Vector3(0.08,0.12,0.12),0.018,dark)

func _glass(pos: Vector3, size: Vector3) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	visual.position=pos
	visual.layers=2
	var material := StandardMaterial3D.new()
	material.albedo_color=Color("738997")
	material.roughness=0.32
	material.metallic=0.25
	visual.material_override=material
	root_asset.add_child(visual)
	visual.owner=root_asset

func _window_quad(points: Array[Vector3]) -> void:
	var visual := MeshInstance3D.new()
	var glass_surface := SurfaceTool.new()
	glass_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0,1,2,0,2,3]:
		glass_surface.add_vertex(points[i])
	glass_surface.generate_normals()
	visual.mesh=glass_surface.commit()
	visual.layers=2
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color("738997")
	mat.roughness=0.32
	mat.metallic=0.25
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	visual.material_override=mat
	root_asset.add_child(visual)
	visual.owner=root_asset
