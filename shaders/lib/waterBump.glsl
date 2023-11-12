float getWaterHeightmap(vec2 posxz, float waveM, float waveZ, float iswater) { // water waves
	vec2 movement = vec2(frameTimeCounter*0.05);// *0;
	vec2 pos = posxz ;
	float caustic = 1.0;
	float weightSum = 0.0;

	float radiance = 2.39996;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

	const vec2 wave_size[3] = vec2[](
		vec2(48.,12.),
		vec2(12.,48.),
		vec2(32.)
	);

	float WavesLarge = clamp(	pow(1.0-pow(1.0-texture2D(noisetex, pos / 600.0 ).b, 5.0),5.0),0.1,1.0);
// 	float WavesLarge = pow(abs(0.5-texture2D(noisetex, pos / 600.0 ).b),2);

	for (int i = 0; i < 3; i++){
		pos = rotationMatrix * pos ;

		float Waves = texture2D(noisetex, pos / wave_size[i] + (1.0-WavesLarge)*0.5 + movement).b;

		
		caustic += exp2(pow(Waves,3.0) * -5.0);
		weightSum += exp2(-(3.0-caustic*pow(WavesLarge,2)));
	}
	return ((3.0-caustic) * weightSum / (30.0 * 3.0));
}


// float getWaterHeightmap(vec2 posxz, float waveM, float waveZ, float iswater) { // water waves
// 	vec2 movement = vec2(frameTimeCounter*0.025);
// 	vec2 pos = posxz ;
// 	float caustic = 1.0;
// 	float weightSum = 0.0;

// 	float radiance = 2.39996;
// 	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

// 	const vec2 wave_size[3] = vec2[](
// 		vec2(60.,30.),
// 		vec2(30.,60.),
// 		vec2(45.)
// 	);

// 	float WavesLarge = pow(abs(0.5-texture2D(noisetex, pos / 600.0 ).b),2);

// 	for (int i = 0; i < 3; i++){
// 		pos = rotationMatrix * pos ;

// 		float Waves = 1.0-exp(pow(abs(0.5-texture2D(noisetex, pos / (wave_size[i]  ) + movement).b),1.3) * -10) ;

// 		caustic += Waves*0.1;
// 		weightSum += exp2(-caustic*pow(WavesLarge,2));
// 	}
// 	return caustic * weightSum/ 30;
// }


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