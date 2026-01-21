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


////////////////////////////////////////////////////////////////////
/////////////////////////////	RTAO/SSGI 	////////////////////////
////////////////////////////////////////////////////////////////////

vec3 rayTrace_GI(vec3 dir,vec3 position,float dither, float quality){

	float biasAmount = 0.0001;

	vec3 clipPosition = toClipSpace3(position);

	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ? (-near -position.z) / dir.z : far*sqrt(3.);
	
	vec3 direction = toClipSpace3(position + dir*rayLength) - clipPosition;  //convert to clip space

	//get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.0, direction) - clipPosition) / direction;
	float mult = min(min(maxLengths.x, maxLengths.y), maxLengths.z);
	vec3 stepv = direction * mult / quality;

	clipPosition.xy *= RENDER_SCALE;
	stepv.xy *= RENDER_SCALE;

	vec3 spos = clipPosition + stepv*dither;
	// spos += stepv*0.3;

	#if defined DEFERRED_SPECULAR && TAA_MODE > 0
		spos.xy += taaJitter*texelSize*0.5/RENDER_SCALE;
	#endif

	float minZ = spos.z - biasAmount / linZ(spos.z);
	float maxZ = spos.z;
	
  	for (int i = 0; i <= int(quality); i++) {

		#ifdef UseQuarterResDepth
			float sampleDepth = sqrt(texelFetch(colortex4,ivec2(spos.xy/texelSize/4.0),0).a/65000.0);
		#else
			float sampleDepth = linZ(texelFetch(depthtex1,ivec2(spos.xy/ texelSize),0).r);
		#endif
		float sp = invLinZ(sampleDepth) ;

		if( (sp < max(minZ, maxZ) && sp > min(minZ, maxZ))) return vec3(spos.xy/RENDER_SCALE,sp);
		
		minZ = maxZ - biasAmount / linZ(spos.z);
		maxZ += stepv.z;

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

vec3 RT_alternate(vec3 dir, vec3 position, float noise, float stepsizes, bool hand, inout float CURVE ){

	vec3 worldpos = mat3(gbufferModelViewInverse) * position;

	float biasamount = 0.00005;
  	vec2 screenEdges = 2.0/vec2(viewWidth, viewHeight);

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

	int iterations = min(int(min(len, mult*len) - 2.0), maxSteps);

	clipPosition.xy *= RENDER_SCALE;
	stepv.xy *= RENDER_SCALE;

	vec3 spos = clipPosition + stepv*noise;
	// spos += stepv*0.3;
	spos.xy += taaJitter*texelSize*0.5*RENDER_SCALE;
	

	float minZ = spos.z - biasamount / linZ(spos.z);
	float maxZ = spos.z;
	CURVE = 0.0;

  	for(int i = 0; i < iterations; i++){

		spos.xy = clamp(spos.xy,screenEdges,1.0-screenEdges);

		if (spos.x < 0.0 || spos.y < 0.0 || spos.z < 0.0 || spos.x > 1.0 || spos.y > 1.0 || spos.z > 1.0) return vec3(1.1);
		
		#ifdef UseQuarterResDepth
			float sp = invLinZ(sqrt(texelFetch(colortex4,ivec2(spos.xy/ texelSize/4),0).w/65000.0));
		#else
			float sp = texelFetch(depthtex1,ivec2(spos.xy/texelSize),0).r;
		#endif

		float currZ = linZ(spos.z);
		float nextZ = linZ(sp);

		if(nextZ < currZ && (sp <= max(minZ,maxZ) && sp >= min(minZ,maxZ))) return vec3(spos.xy/RENDER_SCALE,sp);
		
		minZ = maxZ - biasamount / currZ;
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

		#ifdef LONG_RANGE_SSRT
			vec3 rayHit = rayTrace_GI( mat3(gbufferModelView) * rayDir, viewPos, noise.z, 50.); // ssr rt
		#else
			vec3 rayHit = RT_alternate(mat3(gbufferModelView)*rayDir, viewPos, noise.z, 10., isLOD, CURVE);  // choc sspt 
			
			/// RAAAAAAAAAAAAAAAAAAAAAAAAGHH
			// CURVE = (1.0-exp(-5.0*(1.0-CURVE)));
			CURVE = 1.0-pow(1.0-pow(1.0-CURVE,2.0),5.0);
		#endif
		
		#ifdef SKY_CONTRIBUTION_IN_SSRT
			#ifdef OVERWORLD_SHADER
				skycontribution = doIndirectLighting(skyCloudsFromTex(rayDir, colortex4).rgb/1200.0, minimumLightColor, lightmap) + blockLightColor;
			#else
				skycontribution = volumetricsFromTex(rayDir, colortex4, 6).rgb / 1200.0 + blockLightColor;
			#endif
		#else
			#ifdef OVERWORLD_SHADER
				skycontribution = unchangedIndirect * (max(rayDir.y,pow(1.0-lightmap,2))*0.95+0.05) * 1.25;
			#endif
		#endif

		radiance += skycontribution;
		radiance2 += skycontribution2;

		if (rayHit.z < 0.9999 && distance(gl_FragCoord.xy*texelSize, rayHit.xy) > 0.001){
			#if indirect_effect == SSRT_AO_GI
				vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rayHit) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
				previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
				previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;

				if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.y < 1.0){
					bouncedLight = texelFetch(colortex5, ivec2(previousPosition.xy/texelSize),0).rgb * GI_Strength * CURVE;
					// bouncedLight = texture(colortex5, previousPosition.xy).rgb * GI_Strength * CURVE;
					

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