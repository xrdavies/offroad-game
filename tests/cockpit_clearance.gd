extends SceneTree

const VEHICLES := preload("res://vehicles.gd")
var failures: Array[String]=[]

func blocked(faces: PackedVector3Array, a: Vector3, b: Vector3) -> bool:
	var lower:=a.min(b)-Vector3.ONE*0.001
	var upper:=a.max(b)+Vector3.ONE*0.001
	for i in range(0,faces.size(),3):
		var p:=faces[i]
		var q:=faces[i+1]
		var r:=faces[i+2]
		var lo:=p.min(q).min(r)
		var hi:=p.max(q).max(r)
		if hi.x<lower.x or hi.y<lower.y or hi.z<lower.z or lo.x>upper.x or lo.y>upper.y or lo.z>upper.z:
			continue
		if Geometry3D.segment_intersects_triangle(a,b,p,q,r)!=null:
			return true
	return false

func _initialize() -> void:
	for spec in VEHICLES.SPECS:
		var body: Node3D=load("res://assets/models/"+spec.id+"_body.tscn").instantiate()
		var faces: PackedVector3Array=body.get_node("Model").mesh.get_faces()
		for name in ["SpeedNeedle","HeadingNeedle","SpeedReadout"]:
			if body.find_children(name+"*","",false,false).size()!=1:
				failures.append(spec.id+": duplicate live instrument "+name)
		var target: Vector3=body.get_node("SpeedReadout").position+Vector3(0,0,0.002)
		if blocked(faces,spec.seat,target):
			failures.append(spec.id+": fascia blocks speed readout")
		var wheel: MeshInstance3D=body.get_node("SteeringWheel")
		var inverse:=wheel.transform.affine_inverse()
		if blocked(wheel.mesh.get_faces(),inverse*spec.seat,inverse*target):
			failures.append(spec.id+": neutral steering wheel blocks speed readout")
		var radius: float=0.22 if spec.id=="wc62" else 0.215 if spec.id in ["unimog","eq246","hauler"] else 0.185
		for turn in [-1.5,0.0,1.5]:
			wheel.rotation.z=turn
			for i in 24:
				var a: float=i*TAU/24
				var p:=Vector3(sin(a),cos(a),0)*radius
				if blocked(faces,wheel.transform*(p-Vector3.BACK*0.022),wheel.transform*(p+Vector3.BACK*0.022)):
					failures.append(spec.id+": steering rim intersects static cabin")
		body.free()
	print("COCKPIT_CLEARANCE: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
