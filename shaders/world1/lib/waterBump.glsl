
float getWaterHeightmap(vec2 posxz, float waveM, float waveZ, float iswater) {
  vec2 pos = posxz*4.0;
  float moving = clamp(iswater*2.-1.0,0.0,1.0);
	vec2 movement = vec2(-0.02*frameTimeCounter*moving);
	float caustic = 0.0;
	float weightSum = 0.0;
	float radiance =  2.39996;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));
	for (int i = 0; i < 4; i++){
		vec2 displ = texture2D(noisetex, pos/32.0/1.74/1.74 + movement).bb*2.0-1.0;
		pos = rotationMatrix * pos;
		caustic += sin(dot((pos+vec2(moving*frameTimeCounter))/1.74/1.74 * exp2(0.8*i) + displ*2.0,vec2(0.5)))*exp2(-0.8*i);
		weightSum += exp2(-i);
	}
	return caustic * weightSum / 300.;
}
vec3 getWaveHeight(vec2 posxz, float iswater){

	vec2 coord = posxz;

		float deltaPos = 0.25;

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
