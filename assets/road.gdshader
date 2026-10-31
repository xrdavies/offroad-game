shader_type spatial;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 cell = floor(world_pos.xz * 3.5);
	float speck = hash(cell);
	float worn = step(0.89,hash(floor(world_pos.xz * 2.0)));
	ALBEDO = COLOR.rgb * (0.9 + speck * 0.1 + worn * 0.07);
	ROUGHNESS = 0.98;
}
