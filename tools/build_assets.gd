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
	for i in 3:
		_begin("Wreck%d" % i)
		_wreck(i)
		_save("wreck_%d" % i)
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
	print("ASSETS_OK: 15 original reusable model scenes baked")
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

func _wreck(kind: int) -> void:
	var paint: Color = [Color("a7a69a"), Color("79928c"), Color("ad8273")][kind]
	_box(Vector3(0,0.55,0),Vector3(1.85,0.55,3.9),paint,Vector3(0,0,0.03),true)
	_box(Vector3(0,1.0,0.1),Vector3(1.55,0.55,1.65),palette.dark)
	_box(Vector3(0,1.3,0.18),Vector3(1.65,0.13,1.85),paint.darkened(0.08),Vector3(0,0,-0.06))
	for x in [-0.78,0.78]:
		for z in [-0.72,0.35,0.95]:
			_box(Vector3(x,1,z),Vector3(0.11,0.58,0.1),paint)
		for z in [-1.25,1.25]:
			_wheel(Vector3(x*1.15,0.35,z),0.34)
		_box(Vector3(x*1.2,0.72,0.2),Vector3(0.04,0.15,0.4),palette.rust)
	_box(Vector3(0,0.8,-1.3),Vector3(1.7,0.08,1.1),paint.lightened(0.12),Vector3(-0.08,0,0))
	_box(Vector3(0,0.42,-2),Vector3(1.85,0.13,0.12),palette.steel)
	for x in [-0.6,0.6]:
		_box(Vector3(x,0.67,-1.98),Vector3(0.33,0.18,0.04),palette.cream)
	for i in 9:
		_box(Vector3(sin(i*5.3)*0.7,0.84,cos(i*4.7)*1.5),Vector3(0.2,0.02,0.16),palette.rust)

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
	for i in 12:
		var x := pow(i/12.0,2)*0.85
		_cylinder(Vector3(x,i*0.44+0.22,0),0.24-i*0.007,0.46,palette.rust.lightened((i%2)*0.09),6)
	for i in 9:
		var a := i*TAU/9.0
		for j in 4:
			var d := 0.4+j*0.65
			_box(Vector3(0.85+cos(a)*d,5.5-j*j*0.11,sin(a)*d),Vector3(0.85,0.1,0.48-j*0.07),Color("85865a").darkened((i%3)*0.09),Vector3(0,-a,j*0.16))
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
	for i in 24:
		_box(Vector3(-2.4+i*0.2,1.15,0),Vector3(0.025,1.7,0.025),palette.steel)
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
