
//#define Vanilla_like_water // vanilla water texture along with shader water stuff


float getWaterHeightmap(vec2 posxz, float waveM, float waveZ, float iswater) { // water waves
	vec2 pos = posxz;
	float moving = clamp(iswater*2.-1.0,0.0,1.0);
	vec2 movement = vec2(-0.035*frameTimeCounter*moving);
	float caustic = 0.0;
	float weightSum = 0.0;
	float radiance =  2.39996;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

	const vec2 wave_size[4] = vec2[](
		vec2(600.),
		vec2(32.,16.),
		vec2(16.,32.),
		vec2(48.)
	);

	for (int i = 0; i < 4; i++){
		pos = rotationMatrix * pos;

		vec2 speed = movement;
		float waveStrength = 1.0;

		if( i == 0) {
			speed *= 0.15;
			waveStrength = 7.0;
		}

		float small_wave = texture2D(noisetex, pos / wave_size[i] + speed ).b * waveStrength;

		caustic += small_wave;
		weightSum -= exp2(caustic);
	}
	return caustic / weightSum;
}

vec3 getWaveHeight(vec2 posxz, float iswater){

		vec2 coord = posxz;

		float deltaPos =  0.25;

		float waveZ = mix(20.0,0.25,iswater);
		float waveM = mix(0.0,4.0,iswater);

		float h0 = getWaterHeightmap(coord, waveM, waveZ, iswater);
		float h1 = getWaterHeightmap(coord + vec2(deltaPos,0.0), waveM, waveZ, iswater);
		float h3 = getWaterHeightmap(coord + vec2(0.0,deltaPos), waveM, waveZ, iswater);


		float xDelta = ((h1-h0))/deltaPos*2.;
		float yDelta = ((h3-h0))/deltaPos*2.;

		vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

		return wave;
}
