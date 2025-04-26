vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}

vec3 cosineHemisphereSample(vec2 Xi){
    float theta = 2.0 * 3.14159265359 * Xi.y;

    float r = sqrt(Xi.x);
    float x = r * cos(theta);
    float y = r * sin(theta);

    return vec3(x, y, sqrt(clamp(1.0 - Xi.x,0.,1.)));
}

vec3 TangentToWorld(vec3 N, vec3 H){
    vec3 UpVector = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(UpVector, N));
    vec3 B = cross(N, T);

    return vec3((T * H.x) + (B * H.y) + (N * H.z));
}
vec2 SpiralSample(
	int samples, int totalSamples, float rotation, float Xi
){
	Xi = max(Xi,0.0015);
	
    float alpha = float(samples + Xi) * (1.0 / float(totalSamples));
	
    float theta = (2.0 *3.14159265359) * alpha * rotation;

    float r = sqrt(Xi);
	float x = r * sin(theta);
	float y = r * cos(theta);

    return vec2(x, y);
}

////////////////////////////////////////////////////////////////
/////////////////////////////	SSAO 	////////////////////////
////////////////////////////////////////////////////////////////

vec4 BilateralUpscale_SSAO(sampler2D tex, sampler2D depth, vec2 coord, float referenceDepth){
	ivec2 scaling = ivec2(1.0);
	ivec2 posDepth  = ivec2(coord) * scaling;
	ivec2 posColor  = ivec2(coord);
  	ivec2 pos = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 getRadius[4] = ivec2[](
   	 	ivec2(-2,-2),
	  	ivec2(-2, 0),
		ivec2( 0, 0),
		ivec2( 0,-2)
  	);
	// ivec2 getRadius3x3[8] = ivec2[](
   	// 	ivec2(-2,-2),
	// 	ivec2(-2, 0),
	// 	ivec2( 0, 0),
	// 	ivec2( 0,-2),
    // 	ivec2(-2,-1),
	// 	ivec2(-1,-2),
	// 	ivec2(0,-1),
	// 	ivec2(-1,0)
	// );
	#ifdef DISTANT_HORIZONS
		float diffThreshold = 0.0005 ;
	#else
		float diffThreshold = 0.005;
	#endif

	vec4 RESULT = vec4(0.0);
	float SUM = 0.0;

	for (int i = 0; i < 4; i++) {
		
		ivec2 radius = getRadius[i];
		#ifdef DISTANT_HORIZONS
			float offsetDepth = sqrt(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling,0).a/65000.0);
		#else
			float offsetDepth = ld(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling, 0).r);
		#endif

		float EDGES = abs(offsetDepth - referenceDepth) < diffThreshold ? 1.0 : 1e-5;
		
		RESULT += texelFetch2D(tex, posColor + radius + pos, 0) * EDGES;
		
		SUM += EDGES;
	}

	// return vec4(1,1,1,1) * SUM/4;

	return RESULT / SUM;
}

////////////////////////////////////////////////////////////////////
/////////////////////////////	RTAO/SSGI 	////////////////////////
////////////////////////////////////////////////////////////////////

vec3 rayTrace_GI(vec3 dir,vec3 position,float dither, float quality){

	vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
	                   (-near -position.z) / dir.z : far*sqrt(3.);
	vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
	direction.xy = normalize(direction.xy);

	//get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
	float mult = maxLengths.y;

	vec3 stepv = direction * mult / quality*vec3(RENDER_SCALE,1.0);
	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) ;

	spos.xy += TAA_Offset*texelSize*0.5/RENDER_SCALE;

	spos += stepv*dither;

	float biasdist =  clamp(position.z*position.z/50.0,1,2); // shrink sample size as distance increases

	for(int i = 0; i < int(quality); i++){
		#ifdef UseQuarterResDepth
			float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/texelSize/4),0).w/65000.0);
		#else
			float sp = linZ(texelFetch2D(depthtex1,ivec2(spos.xy/ texelSize),0).r);
		#endif
		float currZ = linZ(spos.z);

		if( sp < currZ) {
			float dist = abs(sp-currZ)/currZ;
			if (abs(dist) < biasdist*0.05) return vec3(spos.xy, invLinZ(sp))/vec3(RENDER_SCALE,1.0);
		}
		spos += stepv;
	}
  return vec3(1.1);
}

float convertHandDepth_3(in float depth, bool hand) {
    if(!hand) return depth;
	
	float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    return ndcDepth * 0.5 + 0.5;
}

vec3 RT(vec3 dir, vec3 position, float noise, float stepsizes, bool hand){
	float dist = 1.0 + clamp(position.z*position.z,0,2); // shrink sample size as distance increases

	float stepSize = stepsizes / dist;
	int maxSteps = STEPS;
	vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * sqrt(3.0)*far) > -sqrt(3.0)*near) ?
	   								(-sqrt(3.0)*near -position.z) / dir.z : sqrt(3.0)*far;
	vec3 end = toClipSpace3(position+dir*rayLength) ;
	vec3 direction = end-clipPosition ;  //convert to clip space

	float len = max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y)/stepSize;
	//get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
	
	float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z)*2000.0;

	vec3 stepv = direction/len;


	int iterations = min(int(min(len, mult*len)-2), maxSteps);
	
	//Do one iteration for closest texel (good contact shadows)
	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) ;
	spos.xy += TAA_Offset*texelSize*0.5*RENDER_SCALE;
	
	spos += stepv;
	
	float distancered = 1.0 + clamp(position.z*position.z/50.0,0,2); // shrink sample size as distance increases

  	for(int i = 0; i < iterations; i++){
		if (spos.x < 0.0 || spos.y < 0.0 || spos.z < 0.0 || spos.x > 1.0 || spos.y > 1.0 || spos.z > 1.0) return vec3(1.1);
		
		spos += stepv*noise;
		#ifdef UseQuarterResDepth
			float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/ texelSize/4),0).w/65000.0);
		#else
			float sp = linZ(texelFetch2D(depthtex1,ivec2(spos.xy/ texelSize),0).r);
		#endif
		
		float currZ = linZ(spos.z);
		
		if( sp < currZ) {
			float dist = abs(sp-currZ)/currZ;
			if (dist <= mix(0.5, 0.1, clamp(position.z*position.z - 0.1,0,1))) return vec3(spos.xy, invLinZ(sp))/vec3(RENDER_SCALE,1.0);
		}
	}
	return vec3(1.1);
}

vec3 RT_alternate(vec3 dir, vec3 position, float noise, float stepsizes, bool hand, inout float CURVE ){

	vec3 worldpos = mat3(gbufferModelViewInverse) * position;

	float dist = 1.0 + length(worldpos)/far; // step length as distance increases
	float stepSize = stepsizes / dist;

	int maxSteps = 10;
	vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * sqrt(3.0)*far) > -sqrt(3.0)*near) ?
	   								(-sqrt(3.0)*near -position.z) / dir.z : sqrt(3.0)*far;
	vec3 end = toClipSpace3(position+dir*rayLength) ;
	vec3 direction = end-clipPosition ;  //convert to clip space

	float len = max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y)/stepSize;
	//get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
	float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z)*2000.0;

	vec3 stepv = direction/len;

	int iterations = min(int(min(len, mult*len)-2), maxSteps);

	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) + stepv*(noise-0.5);
	spos.xy += TAA_Offset*texelSize*0.5*RENDER_SCALE;
	
    float ascribeAmount = 255.0 * 1.0 * (1.0 / viewHeight) * gbufferProjectionInverse[1].y;

	float minZ = spos.z;
	float maxZ = spos.z;
	CURVE = 0.0;
  	for(int i = 0; i < iterations; i++){
		if (spos.x < 0.0 || spos.y < 0.0 || spos.z < 0.0 || spos.x > 1.0 || spos.y > 1.0 || spos.z > 1.0) return vec3(1.1);
		
		#ifdef UseQuarterResDepth
			float sp = invLinZ(sqrt(texelFetch2D(colortex4,ivec2(spos.xy/ texelSize/4),0).w/65000.0));
		#else
			float sp = texelFetch2D(depthtex1,ivec2(spos.xy/texelSize),0).r;
		#endif

		float currZ = linZ(spos.z);
		float nextZ = linZ(sp);

		if(nextZ < currZ && (sp <= max(minZ,maxZ) && sp >= min(minZ,maxZ))) return vec3(spos.xy/RENDER_SCALE,sp);
		
		float biasamount = 0.00005;

		minZ = maxZ-biasamount / currZ;
		maxZ += stepv.z;

		spos += stepv;

		CURVE += 1.0/iterations;
	}
	return vec3(1.1);
}

vec3 ApplySSRT(
	in vec3 unchangedIndirect,
	in vec3 blockLightColor,
	in vec3 minimumLightColor,

	vec3 viewPos,
	vec3 normal,
	vec3 noise,

	float lightmap, 

	bool isGrass,
	bool isLOD
){
	int nrays = RAY_COUNT;

	vec3 radiance = vec3(0.0);
	vec3 occlusion = vec3(0.0);
	vec3 skycontribution = unchangedIndirect;

	vec3 radiance2 = vec3(0.0);
	vec3 occlusion2 = vec3(0.0);
	vec3 skycontribution2 = unchangedIndirect;
	float CURVE = 1.0;
	vec3 bouncedLight = vec3(0.0);
	for (int i = 0; i < nrays; i++){
		int seed = (frameCounter%40000)*nrays+i;
		vec2 ij = fract(R2_samples(seed) + noise.xy);
		vec3 rayDir = TangentToWorld(normal, normalize(cosineHemisphereSample(ij)));

		#ifdef HQ_SSGI
			vec3 rayHit = rayTrace_GI( mat3(gbufferModelView) * rayDir, viewPos, noise.z, 50.); // ssr rt
		#else
			vec3 rayHit = RT_alternate(mat3(gbufferModelView)*rayDir, viewPos, noise.z, 10., isLOD, CURVE);  // choc sspt 


			/// RAAAAAAAAAAAAAAAAAAAAAAAAGHH
			// CURVE = (1.0-exp(-5.0*(1.0-CURVE)));
			CURVE = 1.0-pow(1.0-pow(1.0-CURVE,2.0),5.0);
		#endif

		#ifdef SKY_CONTRIBUTION_IN_SSRT
			#ifdef OVERWORLD_SHADER
				// skycontribution = doIndirectLighting(pow(skyCloudsFromTexLOD(rayDir, colortex4, 0).rgb/1200.0, vec3(0.7)) * 2.5, minimumLightColor, lightmap) + blockLightColor;
				skycontribution = doIndirectLighting(skyCloudsFromTex(rayDir, colortex4).rgb/1200.0, minimumLightColor, lightmap) + blockLightColor;
			#else
				skycontribution = volumetricsFromTex(rayDir, colortex4, 6).rgb / 1200.0 + blockLightColor;
			#endif
		#else
			#ifdef OVERWORLD_SHADER
				skycontribution = unchangedIndirect * (max(rayDir.y,pow(1.0-lightmap,2))*0.95+0.05);
			#endif
		#endif

		radiance += skycontribution;
		radiance2 += skycontribution2;

		if (rayHit.z < 1.0){
			#if indirect_effect == 4
				vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rayHit) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
				previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
				previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;

				if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.y < 1.0){
					bouncedLight = texture2D(colortex5, previousPosition.xy).rgb * GI_Strength * CURVE;	

					radiance += bouncedLight;
					radiance2 += bouncedLight;
				}
			#endif

			occlusion += skycontribution * CURVE;
			occlusion2 += skycontribution2 * CURVE;
		}
	}
	// return unchangedIndirect * CURVE;
	if(isLOD) return max(radiance/nrays, 0.0);

	#ifdef SKY_CONTRIBUTION_IN_SSRT
		return max((radiance - occlusion)/nrays,0.0);
	#else
		float threshold = isGrass ? 0.8 : (pow(1.0-lightmap,2.0) * 0.9 + 0.1);
		return max((radiance - occlusion)/nrays, (radiance2 - occlusion2)/nrays * threshold);
	#endif

}