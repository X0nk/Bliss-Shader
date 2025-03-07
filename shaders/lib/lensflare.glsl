vec3 lensflare(vec2 uv, vec2 pos) {
	uv -= 0.5;
	pos -= 0.5;
	uv.x *= aspectRatio;
	pos.x *= aspectRatio;

	vec2 main = uv - pos;

	float ang = atan(main.y, main.x);
	float dist = length(main); 
	dist = pow(dist, 0.1);
	float n = texture2D(colortex6, vec2((ang - frameTimeCounter / 9.0) * 0.05, dist * 0.1)).x;

	float f0 = 1.0 / (length(main) * 16.0 + 1.0) * 0.2;
	f0 += f0 * (sin((ang + frameTimeCounter / 20.0 + n * 0.4) * 16.0) * 0.1 + dist * 0.1 + 0.8);

	vec2 uvd = uv * length(uv) * 16.0;
	float f1r = max(1.0/(1.0 + 16.0 * pow(length(uvd + 0.8 * pos),1.6)), 0.0) * 0.5;
	float f1g = max(1.0/(1.0 + 16.0 * pow(length(uvd + 0.85 * pos),1.6)), 0.0) * 0.46;
	float f1b = max(1.0/(1.0 + 16.0 * pow(length(uvd + 0.9 * pos),1.6)), 0.0) * 0.42;

	vec2 uvx = mix(uv,uvd,-0.4);
	float f2r = max(0.02 - pow(length(uvx + 0.4 * pos),1.2),.0) * 3.0;
	float f2g = max(0.02 - pow(length(uvx + 0.45 * pos),1.2),.0) * 2.5;
	float f2b = max(0.02 - pow(length(uvx + 0.5 * pos),1.2),.0) * 1.5;

	uvx = mix(uv,uvd,-0.15);
	float f3r = max(0.01 - pow(length(uvx - 0.3 * pos),1.4),.0) * 3.0;
	float f3g = max(0.01 - pow(length(uvx - 0.325 * pos),1.4),.0) * 2.5;
	float f3b = max(0.01 - pow(length(uvx - 0.35 * pos),1.4),.0) * 1.5;

	vec3 c = vec3(0.0);
	c.r += f1r + f2r + f3r;
	c.g += f1g + f2g + f3g;
	c.b += f1b + f2b + f3b;
	c += vec3(f0);

	return c * vec3(1.4, 1.2, 1.0);
}