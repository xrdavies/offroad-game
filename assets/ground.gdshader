shader_type spatial;
varying vec3 world_pos;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float grain = hash(floor(world_pos.xz * 5.0));
	float patch = 0.5+0.5*sin(world_pos.x*0.6+sin(world_pos.z*0.31))*sin(world_pos.z*0.4);
	float chip = step(0.97, grain) * 0.24;
	ALBEDO = COLOR.rgb * (0.82 + patch * 0.16 + grain * 0.12 + chip);
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
