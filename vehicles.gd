extends RefCounted

# Original models, including six real-vehicle appearance references. Specs are gameplay tuning.
# Dimensions are shared by art, suspension and cameras.
const SPECS := [
	{"id":"scout", "name":"SCOUT 4×4", "description":"Balanced expedition wagon · 4 driven wheels", "mass":1250.0, "drive":14000.0, "speed":27.0, "length":3.9, "width":1.9, "axles":[-1.28,1.3], "radius":0.48, "travel":0.65, "steer":1.2, "color":"8e9061", "roof":1.8, "seat":Vector3(-0.43,1.33,0.0)},
	{"id":"ridge", "name":"RIDGE SPORT", "description":"Short wheelbase · agile on narrow mountain trails", "mass":1000.0, "drive":12500.0, "speed":30.0, "length":3.3, "width":1.8, "axles":[-1.05,1.06], "radius":0.5, "travel":0.72, "steer":1.45, "color":"bc7659", "roof":1.77, "seat":Vector3(-0.4,1.31,0.05)},
	{"id":"pickup", "name":"RANGER PICKUP", "description":"Long wheelbase · stable touring with an open cargo bed", "mass":1750.0, "drive":19000.0, "speed":28.0, "length":5.1, "width":2.05, "axles":[-1.65,1.6], "radius":0.53, "travel":0.7, "steer":1.0, "color":"7598a0", "roof":1.9, "seat":Vector3(-0.47,1.42,-0.65)},
	{"id":"hauler", "name":"ATLAS 6×6", "description":"Six driven wheels · heavy crawler with high ground clearance", "mass":4200.0, "drive":49000.0, "speed":21.0, "length":6.2, "width":2.4, "axles":[-2.0,0.9,2.05], "radius":0.66, "travel":0.85, "steer":0.8, "color":"c5a86c", "roof":2.5, "seat":Vector3(-0.57,1.97,-1.4)},
	{"id":"wrangler", "name":"WRANGLER TRAIL", "description":"Wrangler reference · upright grille, exposed arches · 4×4", "mass":1800.0, "drive":21000.0, "speed":28.0, "length":4.4, "width":1.95, "axles":[-1.35,1.35], "radius":0.51, "travel":0.70, "steer":1.2, "color":"c89b50", "roof":1.73, "seat":Vector3(-0.44,1.25,0.0)},
	{"id":"unimog", "name":"UNIMOG EXPEDITION", "description":"Unimog U5023 reference · high cab, large wheels · 4×4", "mass":4800.0, "drive":56000.0, "speed":24.0, "length":6.0, "width":2.48, "axles":[-1.9,1.95], "radius":0.67, "travel":0.85, "steer":0.82, "color":"c8874a", "roof":2.52, "seat":Vector3(-0.60,1.98,-1.66)},
	{"id":"f150", "name":"F-150 DESERT", "description":"Ford F-150 reference · wide crew cab, C lamps · pickup", "mass":2400.0, "drive":28500.0, "speed":31.0, "length":5.9, "width":2.20, "axles":[-1.8,1.8], "radius":0.56, "travel":0.76, "steer":0.95, "color":"547e9a", "roof":1.84, "seat":Vector3(-0.50,1.35,-0.45)},
	{"id":"hilux", "name":"HILUX TRAIL", "description":"Toyota Hilux reference · slim lamps, tapered grille · pickup", "mass":2050.0, "drive":23500.0, "speed":28.0, "length":5.35, "width":1.92, "axles":[-1.55,1.53], "radius":0.50, "travel":0.70, "steer":1.05, "color":"c6c6b6", "roof":1.75, "seat":Vector3(-0.43,1.28,-0.40)},
	{"id":"eq246", "name":"EQ246 TRANSPORT", "description":"Dongfeng EQ246 reference · cab-over, canvas cargo · 6×6", "mass":6300.0, "drive":74000.0, "speed":22.0, "length":7.2, "width":2.50, "axles":[-2.4,1.22,2.52], "radius":0.68, "travel":0.86, "steer":0.72, "color":"697c59", "roof":2.52, "seat":Vector3(-0.60,2.0,-2.45)},
	{"id":"wc62", "name":"WC-62 CLASSIC", "description":"Dodge WC-62 reference · open cab, narrow bonnet · 6×6", "mass":3200.0, "drive":38000.0, "speed":22.0, "length":5.5, "width":2.10, "axles":[-1.65,0.95,1.95], "radius":0.57, "travel":0.72, "steer":0.95, "color":"8a8b60", "roof":1.69, "seat":Vector3(-0.50,1.22,-0.55)}
]

# grip, rolling resistance, delivered torque. Applied at the wheel contacts.
const SURFACES := {
	"road":Vector3(5.2,0.11,1.0), "dirt":Vector3(3.5,0.15,0.95),
	"grass":Vector3(2.8,0.22,0.85), "forest":Vector3(3.2,0.24,0.9),
	"rock":Vector3(4.4,0.19,0.95), "sand":Vector3(2.0,0.6,0.68),
	"mud":Vector3(1.55,0.95,0.56), "swamp":Vector3(1.2,1.3,0.48),
	"water":Vector3(2.3,0.8,0.64), "gobi":Vector3(3.8,0.28,0.88),
	"snow":Vector3(2.0,0.58,0.70), "ice":Vector3(0.65,0.08,0.85)
}

static func wheel_points(spec: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	for z in spec.axles:
		for side in [-1,1]:
			points.append(Vector3(side*float(spec.width)*0.52,0.32,z))
	return points
