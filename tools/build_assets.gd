extends SceneTree

# Editable source for all original voxel models; bake with Godot --headless --script.
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
	_begin("ScoutBody")
	_vehicle()
	_save("scout_body")
	_begin("ScoutWheel")
	_wheel(Vector3.ZERO, 0.48)
	_save("scout_wheel")
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
	print("ASSETS_OK: 22 original reusable model scenes baked")
	quit()

func _begin(asset_name: String) -> void:
	root_asset = Node3D.new()
	root_asset.name = asset_name
	collider = null
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func _save(file_name: String) -> void:
	var visual := MeshInstance3D.new()
	visual.name = "Model"
	visual.mesh = surface.commit()
	assert(visual.mesh.get_surface_count() == 1 and visual.mesh.get_aabb().size.length() > 0.1)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.roughness = 0.9
	visual.material_override = material
	root_asset.add_child(visual)
	visual.owner = root_asset
	var scene := PackedScene.new()
	assert(scene.pack(root_asset) == OK)
	assert(ResourceSaver.save(scene, OUT + file_name + ".tscn") == OK)
	root_asset.free()

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
	_cylinder(pos, radius, 0.38, palette.rubber, 12, Vector3(0,0,PI/2))
	_cylinder(pos, radius * 0.53, 0.405, palette.steel, 8, Vector3(0,0,PI/2))
	_cylinder(pos, radius * 0.2, 0.43, palette.dark, 8, Vector3(0,0,PI/2))
	for i in 12:
		var a := TAU * i / 12.0
		_box(pos + Vector3(0, sin(a), cos(a)) * radius, Vector3(0.41,0.11,0.15), palette.rubber.lightened(0.06), Vector3(-a,0,0))

func _vehicle() -> void:
	_box(Vector3(0, 0, 0), Vector3(1.65,0.22,3.7), palette.dark)
	_box(Vector3(0,0.35,0), Vector3(1.86,0.62,3.7), palette.paint)
	_box(Vector3(0,0.7,-1.25), Vector3(1.8,0.16,1.15), palette.edge)
	_box(Vector3(0,0.86,0.22), Vector3(1.7,0.7,1.82), palette.glass)
	_box(Vector3(0,1.24,0.25), Vector3(1.86,0.16,2.05), palette.paint)
	_box(Vector3(0,0.86,1.3), Vector3(1.86,0.72,0.7), palette.paint)
	for x in [-0.88,0.88]:
		for z in [-0.65,0.35,1.09]:
			_box(Vector3(x,0.88,z), Vector3(0.1,0.72,0.1), palette.edge)
		_box(Vector3(x,0.37,0.05), Vector3(0.065,0.42,1.7), palette.edge)
		_box(Vector3(x*1.07,0.58,0.3), Vector3(0.075,0.055,0.22), palette.dark)
		_box(Vector3(x*1.18,0.9,-0.56), Vector3(0.22,0.18,0.18), palette.dark)
		_box(Vector3(x*1.12,-0.07,0), Vector3(0.25,0.13,1.7), palette.steel)
		for z in [-1.25,1.28]:
			_box(Vector3(x,0.28,z), Vector3(0.35,0.19,1.18), palette.dark)
	_box(Vector3(0,0.24,-1.91), Vector3(1.86,0.34,0.12), palette.dark)
	for x in range(-4,5):
		_box(Vector3(x*0.13,0.25,-1.99), Vector3(0.055,0.27,0.045), palette.steel)
	for x in [-0.73,0.73]:
		_box(Vector3(x,0.43,-1.97), Vector3(0.27,0.22,0.06), Color("eed5a0"))
		_box(Vector3(x,0.35,1.88), Vector3(0.23,0.25,0.06), palette.red)
	for z in [-2.0,1.96]:
		_box(Vector3(0,-0.03,z), Vector3(2.05,0.18,0.18), palette.steel)
	# Open rack and visible strapped cargo establish the expedition silhouette.
	for x in [-0.77,0.77]:
		_box(Vector3(x,1.48,0.3), Vector3(0.09,0.29,1.96), palette.dark)
	for z in [-0.66,-0.3,0.1,0.5,0.9,1.2]:
		_box(Vector3(0,1.36,z), Vector3(1.6,0.07,0.07), palette.dark)
	_box(Vector3(-0.33,1.57,0.5), Vector3(0.66,0.38,0.85), palette.rust)
	_box(Vector3(0.38,1.51,0.55), Vector3(0.56,0.27,0.74), palette.cream)
	for x in [-0.47,0.4]:
		_box(Vector3(x,1.78,0.5), Vector3(0.055,0.045,0.87), palette.dark)
	_cylinder(Vector3(0,0.76,1.98),0.43,0.32,palette.rubber,12,Vector3(PI/2,0,0))
	_cylinder(Vector3(0,0.76,2.16),0.22,0.04,palette.steel,8,Vector3(PI/2,0,0))
	_box(Vector3(0.94,1.28,-0.85),Vector3(0.09,1.6,0.1),palette.dark)
	_box(Vector3(-0.76,0.9,1.92),Vector3(0.38,0.6,0.22),palette.green)
	for x in [-0.4,0.4]:
		_box(Vector3(x,0.94,-0.698),Vector3(0.68,0.43,0.025),Color("8495b1"))
		_beam(Vector3(x-0.2,0.76,-0.72),Vector3(x+0.1,0.88,-0.72),0.025,palette.dark)
		_box(Vector3(x,0.03,-2.14),Vector3(0.14,0.14,0.12),palette.red)
	for x in [-0.96,0.96]:
		for z in [-0.43,0.43]:
			_box(Vector3(x,0.37,z),Vector3(0.025,0.3,0.025),palette.paint.darkened(0.2))
		for z in [-1.0,-1.15,-1.3]:
			_box(Vector3(x,0.52,z),Vector3(0.025,0.055,0.09),palette.dark)
		_box(Vector3(x,0.18,0.1),Vector3(0.03,0.1,1.45),palette.sand)
	_box(Vector3(0,0.24,2.07),Vector3(0.4,0.13,0.025),palette.cream)
	_chips(Vector3(0,0.79,-1.25),Vector2(1.6,0.9),palette.paint,71)

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
