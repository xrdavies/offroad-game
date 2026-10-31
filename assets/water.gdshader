shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p=world_pos.xz;
	float waves=sin(p.x*2.8+p.y*1.5+sin(p.y*2.0)+TIME*1.2);
	float broken=step(0.7,hash(floor(p*vec2(2.5,1.4))));
	float ripple=smoothstep(0.7,1.0,waves)*broken*0.09;
	float bank=abs(p.x-(32.0+7.0*sin(p.y*0.025)));
	float foam=smoothstep(5.2,6.2,bank)*step(0.35,hash(floor(p*4.0)));
	ALBEDO=mix(vec3(0.027,0.095,0.083)+ripple,vec3(0.52,0.59,0.49),foam*0.7);
	ROUGHNESS=0.65;
	SPECULAR=0.15;
}
