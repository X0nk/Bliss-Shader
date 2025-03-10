float waterCaustics(vec3 worldPos, vec3 sunVec) {

	vec3 projectedPos = worldPos - (sunVec/sunVec.y*worldPos.y);
	vec2 pos = projectedPos.xz;

	float movement = frameTimeCounter * 0.035 * WATER_WAVE_SPEED;

	float radiance = 2.39996;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

 	vec2 wave_size[3] = vec2[](
		vec2(48.,12.),
		vec2(12.,48.),
		vec2(32.,32.)
	);

	float largeWaves = texture2D(noisetex, pos / 600.0 ).b;
	float largeWavesCurved = pow(1.0-pow(1.0-largeWaves,2.5),4.5);

	float heightSum = 0.0;
	for (int i = 0; i < 3; i++){
		pos = rotationMatrix * pos;
		heightSum += pow(abs(abs(texture2D(noisetex, pos / wave_size[i] + largeWavesCurved * 0.5 + movement).b * 2.0 - 1.0) * 2.0 - 1.0), 1.0+largeWavesCurved) ;
	}

	return exp((1.0 + 5.0 * sqrt(largeWavesCurved)) * (heightSum / 3.0 - 0.5));

}

float getWaterHeightmap(vec2 posxz, in float largeWaves, in float largeWavesCurved) {
	vec2 pos = posxz;

	float movement = frameTimeCounter * 0.035 * WATER_WAVE_SPEED;

	float radiance = 2.39996;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

 	vec2 wave_size[3] = vec2[](
		vec2(48.,12.),
		vec2(12.,48.),
		vec2(32.,32.)
	);


	float heightSum = 0.0;
	for (int i = 0; i < 3; i++){

		pos = rotationMatrix * pos;
		heightSum += texture2D(noisetex, pos / wave_size[i] + largeWavesCurved * 0.5 + movement).b;
	}

	return (heightSum/4.5) * max(largeWavesCurved,0.3);
}

vec3 getWaveNormal(vec3 waterPos, vec3 playerpos, bool isLOD){
	
	float largeWaves = texture2D(noisetex, waterPos.xy / 600.0 ).b;
	float largeWavesCurved = pow(1.0-pow(1.0-largeWaves,2.5),4.5);
	
	#ifdef HYPER_DETAILED_WAVES
		float deltaPos = mix(1.0, 0.05, largeWavesCurved);
	#else
		float deltaPos = mix(1.0, 0.15, largeWavesCurved);
		// reduce high frequency detail as distance increases. reduces noise on waves. why have more details than pixels?
		float range = min(length(playerpos) / (16.0*24.0), 3.0);
		deltaPos += range;
	#endif

	vec2 coord = waterPos.xy;

	float h0 = getWaterHeightmap(coord, largeWaves, largeWavesCurved);
	float h1 = getWaterHeightmap(coord + vec2(deltaPos,0.0), largeWaves,largeWavesCurved);
	float h3 = getWaterHeightmap(coord + vec2(0.0,deltaPos), largeWaves,largeWavesCurved);

	float xDelta = (h1-h0)/deltaPos;
	float yDelta = (h3-h0)/deltaPos;

	vec3 wave = normalize(vec3(xDelta, yDelta, 1.0-pow(abs(xDelta+yDelta),2.0)));

	return wave;
}
