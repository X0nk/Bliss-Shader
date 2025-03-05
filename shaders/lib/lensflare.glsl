vec3 lensflare(vec2 uv, vec2 pos, sampler2D noiseTex, float time) {
	vec2 main = uv - pos;
	vec2 uvd = uv * (length(uv));

	float ang = atan(main.y, main.x);
	float dist = length(main);
	dist = pow(dist, 0.1);

	float n = texture2D(noiseTex, vec2((ang - time / 9.0) * 16.0, dist * 32.0) / 512.0).x;

	float f0 = 1.0 / (length(uv - pos) * 16.0 + 1.0);
	f0 = f0 + f0 * (sin((ang + time / 18.0 + noise(abs(ang) + n / 2.0) * 2.0) * 12.0) * 0.1 + dist * 0.1 + 0.8);

	float f2 = max(1.0 / (1.0 + 32.0 * pow(length(uvd + 0.8 * pos), 2.0)), 0.0) * 0.25;
	float f22 = max(1.0 / (1.0 + 32.0 * pow(length(uvd + 0.85 * pos), 2.0)), 0.0) * 0.23;
	float f23 = max(1.0 / (1.0 + 32.0 * pow(length(uvd + 0.9 * pos), 2.0)), 0.0) * 0.21;

	vec2 uvx = mix(uv, uvd, -0.5);

	float f4 = max(0.01 - pow(length(uvx + 0.4 * pos), 2.4), 0.0) * 6.0;
	float f42 = max(0.01 - pow(length(uvx + 0.45 * pos), 2.4), 0.0) * 5.0;
	float f43 = max(0.01 - pow(length(uvx + 0.5 * pos), 2.4), 0.0) * 3.0;

	uvx = mix(uv, uvd, -0.4);

	float f5 = max(0.01 - pow(length(uvx + 0.2 * pos), 5.5), 0.0) * 2.0;
	float f52 = max(0.01 - pow(length(uvx + 0.4 * pos), 5.5), 0.0) * 2.0;
	float f53 = max(0.01 - pow(length(uvx + 0.6 * pos), 5.5), 0.0) * 2.0;

	uvx = mix(uv, uvd, -0.5);

	float f6 = max(0.01 - pow(length(uvx - 0.3 * pos), 1.6), 0.0) * 6.0;
	float f62 = max(0.01 - pow(length(uvx - 0.325 * pos), 1.6), 0.0) * 3.0;
	float f63 = max(0.01 - pow(length(uvx - 0.35 * pos), 1.6), 0.0) * 5.0;

	vec3 c = vec3(0.0);
	c.r += f2 + f4 + f5 + f6;
	c.g += f22 + f42 + f52 + f62;
	c.b += f23 + f43 + f53 + f63;
	c += vec3(f0);

	return c * 0.15;
}