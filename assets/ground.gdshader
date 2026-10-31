shader_type spatial;
varying vec3 world_pos;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float grain = hash(floor(world_pos.xz * 4.0));
	float patch = hash(floor(world_pos.xz * 0.6));
	float chip = step(0.94, grain) * 0.16;
	ALBEDO = COLOR.rgb * (0.88 + patch * 0.15 + grain * 0.1 + chip);
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
