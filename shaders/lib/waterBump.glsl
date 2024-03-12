float waterCaustics(vec3 worldPos, vec3 sunVec) {

	vec3 projectedPos = worldPos - (sunVec/sunVec.y*worldPos.y);
	vec2 pos = projectedPos.xz;

	float heightSum = 0.0;
	float movement = frameTimeCounter*0.035 * WATER_WAVE_SPEED;
	// movement = 0.0;

	float radiance = 2.39996;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));
	
	vec2 wave_size[3] = vec2[](
		vec2(48.,12.),
		vec2(12.,48.),
		vec2(32.,32.)
	);

	float WavesLarge = max(texture2D(noisetex, pos / 600.0 ).b,0.1);

	for (int i = 0; i < 3; i++){
		pos = rotationMatrix * pos;
		heightSum += pow(abs(abs(texture2D(noisetex, pos / wave_size[i] + WavesLarge*0.5 + movement).b * 2.0 - 1.0) * 2.0 - 1.0), 2.0) ;
	}

	float FinalCaustics = exp((1.0 + 5.0 * pow(WavesLarge,0.5)) * (heightSum / 3.0 - 0.5));

	return FinalCaustics;
}

float getWaterHeightmap(vec2 posxz) {
	
	vec2 pos = posxz;
	float heightSum = 0.0;
	float movement = frameTimeCounter*0.035 * WATER_WAVE_SPEED;
	// movement = 0.0;
	
	float radiance = 2.39996;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

	vec2 wave_size[3] = vec2[](
		vec2(48.,12.),
		vec2(12.,48.),
		vec2(32.,32.)
	);

	float WavesLarge = max(texture2D(noisetex, pos / 600.0 ).b,0.1);

	for (int i = 0; i < 3; i++){
		pos = rotationMatrix * pos;
		heightSum += texture2D(noisetex, pos / wave_size[i] + WavesLarge*0.5 + movement).b;
	}

	return (heightSum / 60.0) * WavesLarge;
}

vec3 getWaveNormal(vec3 posxz, bool isLOD){

	// vary the normal's "smooth" factor as distance changes, to avoid noise from too much details.
	float range = pow(clamp(1.0 - length(posxz - cameraPosition)/(32*4),0.0,1.0),2.0);
	float deltaPos = mix(0.5, 0.1, range);
	float normalMult = 10.0 * WATER_WAVE_STRENGTH;

	if(isLOD){
		normalMult = mix(5.0, normalMult, range);
		deltaPos = mix(0.9, deltaPos, range);
	}
	// added detail for snells window
	// if(isEyeInWater == 1) deltaPos = 0.025;

	#ifdef HYPER_DETAILED_WAVES
		deltaPos = 0.025;
	#endif
	
	vec2 coord = posxz.xz;// - posxz.y;

	float h0 = getWaterHeightmap(coord);
	float h1 = getWaterHeightmap(coord + vec2(deltaPos,0.0));
	float h3 = getWaterHeightmap(coord + vec2(0.0,deltaPos));


	float xDelta = ((h1-h0)/deltaPos)*normalMult;
	float yDelta = ((h3-h0)/deltaPos)*normalMult;

	vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

	return wave ;
}