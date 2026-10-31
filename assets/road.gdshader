shader_type spatial;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p = world_pos.xz;
	float speck = hash(floor(p * 5.0));
	float worn = step(0.86,hash(floor(p * 1.8)));
	float edge = smoothstep(0.85,1.0,abs(UV.x)+speck*0.09);
	float stripe = (1.0-smoothstep(0.012,0.027,abs(abs(UV.x)-0.84)))*step(0.22,speck);
	vec2 fissure = fract(p*0.7+sin(p.yx*1.9)*0.14);
	float crack = (1.0-step(0.018,min(fissure.x,fissure.y)))*step(0.72,hash(floor(p*0.7)));
	vec3 asphalt = COLOR.rgb * (0.9+speck*0.1+worn*0.06-crack*0.45);
	ALBEDO = mix(mix(asphalt,vec3(0.51,0.47,0.34),stripe*0.8),vec3(0.27,0.23,0.18),edge*0.8);
	ROUGHNESS = 0.98;
}
