extends RefCounted

# Original fictional vehicles. Dimensions are shared by art, suspension and cameras.
const SPECS := [
	{"id":"scout", "name":"SCOUT 4×4", "description":"Balanced expedition wagon · 4 driven wheels", "mass":1250.0, "drive":14000.0, "speed":27.0, "length":3.9, "width":1.9, "axles":[-1.28,1.3], "radius":0.48, "travel":0.65, "steer":1.2, "color":"8e9061", "roof":1.95, "seat":Vector3(-0.43,1.48,0.0)},
	{"id":"ridge", "name":"RIDGE SPORT", "description":"Short wheelbase · agile on narrow mountain trails", "mass":1000.0, "drive":12500.0, "speed":30.0, "length":3.3, "width":1.8, "axles":[-1.05,1.06], "radius":0.5, "travel":0.72, "steer":1.45, "color":"bc7659", "roof":1.92, "seat":Vector3(-0.4,1.46,0.05)},
	{"id":"pickup", "name":"RANGER PICKUP", "description":"Long wheelbase · stable touring with an open cargo bed", "mass":1750.0, "drive":19000.0, "speed":28.0, "length":5.1, "width":2.05, "axles":[-1.65,1.6], "radius":0.53, "travel":0.7, "steer":1.0, "color":"7598a0", "roof":2.05, "seat":Vector3(-0.47,1.57,-0.65)},
	{"id":"hauler", "name":"ATLAS 6×6", "description":"Six driven wheels · heavy crawler with high ground clearance", "mass":4200.0, "drive":49000.0, "speed":21.0, "length":6.2, "width":2.4, "axles":[-2.0,0.9,2.05], "radius":0.66, "travel":0.85, "steer":0.8, "color":"c5a86c", "roof":2.65, "seat":Vector3(-0.57,2.12,-1.4)}
]

# grip, rolling resistance, delivered torque. Applied at the wheel contacts.
const SURFACES := {
	"road":Vector3(5.2,0.11,1.0), "dirt":Vector3(3.5,0.15,0.95),
	"grass":Vector3(2.8,0.22,0.85), "forest":Vector3(3.2,0.24,0.9),
	"rock":Vector3(4.4,0.19,0.95), "sand":Vector3(2.0,0.6,0.68),
	"mud":Vector3(1.55,0.95,0.56), "swamp":Vector3(1.2,1.3,0.48),
	"water":Vector3(2.3,0.8,0.64)
}

static func wheel_points(spec: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	for z in spec.axles:
		for side in [-1,1]:
			points.append(Vector3(side*float(spec.width)*0.52,0.32,z))
	return points
