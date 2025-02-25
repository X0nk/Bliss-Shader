//Original ripple code : https://www.shadertoy.com/view/ldfyzl , optimised

uniform float rainStrength;
uniform float noPuddleAreas;
varying vec4 lmtexcoord;

float lightmap = clamp((lmtexcoord.w-0.9) * 10.0,0.,1.);
float isRain = rainStrength * noPuddleAreas;
float applyRipple = isRain * lightmap;

// Maximum number of cells a ripple can cross.
#define MAX_RADIUS 2

float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * .1031);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx+19.19);
	return fract((p3.xx+p3.yz)*p3.zy);
}

vec3 drawRipples(vec2 uv, float time) {
	vec2 p0 = floor(uv);
	vec2 circles = vec2(0.);
	for (int j = -MAX_RADIUS; j < MAX_RADIUS; ++j) {
		for (int i = -MAX_RADIUS; i < MAX_RADIUS; ++i) {
			vec2 pi = p0 + vec2(i, j);
			vec2 p = pi + hash22(pi);

			float t = fract(0.6*time + hash12(pi));
			vec2 v = p - uv;
			float d = length(v) - (float(MAX_RADIUS) + 1.)*t;

			float carrier = cos(8.*radians(180.) *d);
			float x = clamp(3.*d + 1., -1., 1.); 
			float energy = 1.-x * x * (3. - 2.*abs(x));
			circles += 16.* normalize(v) * carrier * energy * pow(1. - t, 2.);
		}
	}
	circles /= float((MAX_RADIUS*2+1)*(MAX_RADIUS*2+1));

	vec3 n = vec3(circles, sqrt(1. - dot(circles, circles)));
	return n;
}