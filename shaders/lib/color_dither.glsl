//using white noise for color dithering : gives a somewhat more "filmic" look when noise is visible
float nrand( vec2 n )
{
	return fract(sin(dot(n.xy, vec2(12.9898, 78.233)))* 43758.5453);
}

float triangWhiteNoise( vec2 n )
{

	float t = fract( frameTimeCounter );
	float rnd = nrand( n + 0.07*t );

    float center = rnd*2.0-1.0;
    rnd = center*inversesqrt(abs(center));
    rnd = max(-1.0,rnd); 
    return rnd-sign(center);
}

vec3 fp10Dither(vec3 color,vec2 tc01){
	float dither = triangWhiteNoise(tc01);
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}

vec3 fp16Dither(vec3 color,vec2 tc01){
	float dither = triangWhiteNoise(tc01);
	const vec3 mantissaBits = vec3(10.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}

vec3 int8Dither(vec3 color,vec2 tc01){
	float dither = triangWhiteNoise(tc01);
	return color + dither*exp2(-8.0);
}

vec3 int10Dither(vec3 color,vec2 tc01){
	float dither = triangWhiteNoise(tc01);
	return color + dither*exp2(-10.0);
}

vec3 int16Dither(vec3 color,vec2 tc01){
	float dither = triangWhiteNoise(tc01);
	return color + dither*exp2(-16.0);
}