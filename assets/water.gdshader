shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p=world_pos.xz;
	if (UV.x < 0.0) { discard; }
	vec2 pixel = floor(p*9.0)/9.0;
	float grain=hash(floor(p*9.0));
	float waves=sin(pixel.x*2.8+pixel.y*1.5+sin(pixel.y*2.0)+TIME*1.2);
	float broken=step(0.77,hash(floor(p*vec2(2.5,1.4))));
	float ripple=smoothstep(0.93,1.0,waves)*broken;
	float foam=(1.0-smoothstep(0.035,0.15,UV.x+grain*0.055))*step(0.12,grain);
	vec3 water=mix(vec3(0.025,0.09,0.08),vec3(0.09,0.15,0.135),clamp(1.0-UV.x*2.0,0.0,1.0));
	ALBEDO=mix(water,vec3(0.7,0.77,0.68),max(foam,ripple*0.5));
	ROUGHNESS=0.72;
	SPECULAR=0.15;
}
