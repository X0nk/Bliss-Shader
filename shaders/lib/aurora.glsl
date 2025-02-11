//Original aurora code : https://www.shadertoy.com/view/XtGGRt

float speed = AURORA_SPEED;

mat2 mm2(float a) {
	float c = cos(a), s = sin(a);
	return mat2(c,s,-s,c);
}
const mat2 m2 = mat2(0.95534, 0.29552, -0.29552, 0.95534);
float tri(float x) {
	return clamp(abs(fract(x) - 0.5), 0.01, 0.49);
}
vec2 tri2(vec2 p) {
	return vec2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));
}

float triNoise2d(vec2 pos, float speed) {
	float z = 1.8;
	float z2 = 2.5;
	float rz = 0.0;
	pos *= mm2(pos.x * 0.06);
	vec2 bp = pos;
	float sp = Time * speed / 60.0;
	mat2 rot = mm2(sp);
	for (float i = 0.0; i < 5.0; i++ ) {
		vec2 dg = tri2(bp * 1.85) * 0.75;
		dg *= rot;
		pos -= dg / z2;

		bp *= 1.3;
		z2 *= 0.45;
		z *= 0.42;
		pos *= 1.21 + (rz - 1.0) * 0.02;

		rz += tri(pos.x + tri(pos.y)) * z;
		pos *= -m2;
	}
	return clamp(1.0 / pow(rz * 29.0, 1.3), 0.0, 0.55);
}

float hash21(vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

vec4 aurora(vec3 dir, float dither) {
	vec3 upperColor = vec3(AURORA_UPPER_R, AURORA_UPPER_G, AURORA_UPPER_B);
	vec3 lowerColor = vec3(AURORA_LOWER_R, AURORA_LOWER_G, AURORA_LOWER_B);
	vec4 outerColor = vec4(0.0);
	vec4 avgColor = vec4(0.0);

	const int aurStep = AURORA_STEP;
	for (int i = 0; i < aurStep; ++i) {
		float amp = float(i) / float(aurStep - 1);
		float jitter = 0.012 * dither * clamp(smoothstep(0.0, 15.0, float(i)), 0.0, 1.0);
		float pt = ((0.8 + pow(amp * 24, 1.4) * 0.004)) / (dir.y * 2.0 + 0.4) - jitter;

		vec2 aurPos = (pt * dir).zx;
		float rzt = triNoise2d(aurPos, speed);
		vec4 innerColor = vec4(0.0, 0.0, 0.0, rzt);

		innerColor.rgb = rzt * mix(lowerColor, upperColor, smoothstep(0.0, 1.0, amp));
		avgColor =  mix(avgColor, innerColor, 0.5);
		outerColor += avgColor * exp2(-(amp * 24) * 0.065 - 2.5) * smoothstep(0.0, 5.0, (amp * 24)) * 24 / aurStep;
	}

	outerColor *= clamp(dir.y * 15.0 + 0.4, 0.0, 1.0);

	return outerColor * AURORA_BRIGHTNESS;

}
vec3 drawAurora(vec3 rayDir, float dither) {

	vec3 color = vec3(0.0);
	float fade = smoothstep(0.0, 0.1, abs(rayDir.y))*0.1+0.9;

	if (rayDir.y > 0.0) {
		vec4 aur = smoothstep(0.0, 1.5, aurora(rayDir, dither)) * fade;
		color = color * (1.0 - aur.a) + aur.rgb;
	}

	return color;
}