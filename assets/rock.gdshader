shader_type spatial;
varying vec3 world_pos;
varying vec3 face_normal;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() {
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	face_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment() {
	float top=step(0.8,abs(face_normal.y));
	vec2 wall=vec2(abs(face_normal.x)>abs(face_normal.z) ? world_pos.z : world_pos.x,world_pos.y);
	vec2 p=mix(wall,world_pos.xz,top);
	float grain=hash(floor(p*5.0));
	float stone=hash(floor(p*1.8));
	float fracture=(1.0-step(0.035,fract(p.x*0.55+hash(vec2(0.0,floor(p.y*0.8)))*0.16)))*(1.0-top);
	float strata=(1.0-smoothstep(0.015,0.065,fract(world_pos.y*2.3)))*(1.0-top);
	vec3 rock=COLOR.rgb*(0.79+grain*0.1+stone*0.17-fracture*0.25-strata*0.15);
	float moss=smoothstep(0.55,0.85,sin(p.x*0.7+sin(p.y*0.4))*0.5+0.5)*top;
	ALBEDO=mix(rock,vec3(0.21,0.22,0.115),moss*0.38);
	ROUGHNESS=1.0;
	SPECULAR=0.05;
}
