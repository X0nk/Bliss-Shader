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

vec3 TangentToWorld(vec3 N, vec3 H, float roughness){
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

vec2 SSAO(
	vec3 viewPos, vec3 normal, bool hand, bool leaves, float noise
){
	if(hand) return vec2(1.0,0.0);
	int samples = 7;
	float occlusion = 0.0; 
	float sss = 0.0;


	float dist = 1.0 + clamp(viewPos.z*viewPos.z/50.0,0,5); // shrink sample size as distance increases
	float mulfov2 = gbufferProjection[1][1]/(3 * dist);
	float maxR2 = viewPos.z*viewPos.z*mulfov2*2.*5/50.0;

	#ifdef Ambient_SSS
		float maxR2_2 = viewPos.z*viewPos.z*mulfov2*2.*2./50.0;

		float dist3 = clamp(1-exp( viewPos.z*viewPos.z / -50),0,1);
		if(leaves) maxR2_2 = mix(10, maxR2_2, dist3);
	#endif

	vec2 acc = -(TAA_Offset*(texelSize/2))*RENDER_SCALE ;

	int n = 0;
	for (int i = 0; i < samples; i++) {
		
		// vec2 sampleOffset = SpiralSample(i, 7, 8, noise) * 0.2 * mulfov2;
		
		vec2 sampleOffset = SpiralSample(i, 7, 8, noise) * clamp(0.05 + i*0.095, 0.0,0.3)  * mulfov2;

		ivec2 offset = ivec2(gl_FragCoord.xy + sampleOffset*vec2(viewWidth,viewHeight*aspectRatio)*RENDER_SCALE);

		if (offset.x >= 0 && offset.y >= 0 && offset.x < viewWidth*RENDER_SCALE.x && offset.y < viewHeight*RENDER_SCALE.y ) {
			#ifdef DISTANT_HORIZONS
				float dhdepth = texelFetch2D(dhDepthTex1, offset,0).x;
			#else
				float dhdepth = 0.0;
			#endif

			vec3 t0 = toScreenSpace_DH((offset*texelSize+acc+0.5*texelSize) * (1.0/RENDER_SCALE), texelFetch2D(depthtex1, offset,0).x, dhdepth);
			vec3 vec = (t0.xyz - viewPos);
			float dsquared = dot(vec, vec);
			
			if (dsquared > 1e-5){
				if (dsquared < maxR2){
					float NdotV = clamp(dot(vec*inversesqrt(dsquared), normalize(normal)),0.,1.);
					occlusion += NdotV * clamp(1.0-dsquared/maxR2,0.0,1.0);
				}

				#ifdef Ambient_SSS
					if(dsquared > maxR2_2){
						float NdotV = 1.0 - clamp(dot(vec*dsquared, normalize(normal)),0.,1.);
						sss += max((NdotV - (1.0-NdotV)) * clamp(1.0-maxR2_2/dsquared,0.0,1.0) ,0.0);
					}
				#endif

				n += 1;
			}
		}
	}
	return max(1.0 - vec2(occlusion, sss)/n, 0.0);
}
float ScreenSpace_SSS(
	vec3 viewPos, vec3 normal, bool hand, bool leaves, float noise
){
	if(hand) return 0.0;
	int samples = 7;
	float occlusion = 0.0; 
	float sss = 0.0;


	float dist = 1.0 + clamp(viewPos.z*viewPos.z/50.0,0,5); // shrink sample size as distance increases
	float mulfov2 = gbufferProjection[1][1]/(3 * dist);

	float maxR2_2 = viewPos.z*viewPos.z*mulfov2*2.*2./50.0;

	float dist3 = clamp(1-exp( viewPos.z*viewPos.z / -50),0,1);
	if(leaves) maxR2_2 = mix(10, maxR2_2, dist3);
	

	vec2 acc = -(TAA_Offset*(texelSize/2))*RENDER_SCALE ;

	int n = 0;
	for (int i = 0; i < samples; i++) {
		
		vec2 sampleOffset = SpiralSample(i, 7, 8, noise) * 0.2 * mulfov2;

		ivec2 offset = ivec2(gl_FragCoord.xy + sampleOffset*vec2(viewWidth,viewHeight*aspectRatio)*RENDER_SCALE);

		if (offset.x >= 0 && offset.y >= 0 && offset.x < viewWidth*RENDER_SCALE.x && offset.y < viewHeight*RENDER_SCALE.y ) {
			vec3 t0 = toScreenSpace(vec3(offset*texelSize+acc+0.5*texelSize, texelFetch2D(depthtex1, offset,0).x) * vec3(1.0/RENDER_SCALE, 1.0) );
			vec3 vec = (t0.xyz - viewPos);
			float dsquared = dot(vec, vec);
			
			if (dsquared > 1e-5){
				if(dsquared > maxR2_2){
					float NdotV = 1.0 - clamp(dot(vec*dsquared, normalize(normal)),0.,1.);
					sss += max((NdotV - (1.0-NdotV)) * clamp(1.0-maxR2_2/dsquared,0.0,1.0) ,0.0);
				}
				n += 1;
			}
		}
	}
	return max(1.0 - sss/n, 0.0);
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

	vec3 stepv = direction * mult / quality*vec3(RENDER_SCALE,1.0) * dither;
	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) ;

	spos.xy += TAA_Offset*texelSize*0.5/RENDER_SCALE;

	float biasdist =  clamp(position.z*position.z/50.0,1,2); // shrink sample size as distance increases

	for(int i = 0; i < int(quality); i++){
		spos += stepv;
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

vec3 RT(vec3 dir, vec3 position, float noise, float stepsizes){
	float dist = 1.0 + clamp(position.z*position.z/50.0,0,2); // shrink sample size as distance increases

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
	spos += stepv/(stepSize/2);
	
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
			if (dist <= 0.1) return vec3(spos.xy, invLinZ(sp))/vec3(RENDER_SCALE,1.0);
		}
	}
	return vec3(1.1);
}

void ApplySSRT(
	inout vec3 lighting, 
	vec3 viewPos,
	vec3 normal,
	vec3 noise,

	vec2 lightmaps, 
	vec3 skylightcolor, 
	vec3 torchcolor, 

	bool isGrass
){
	int nrays = RAY_COUNT;

	vec3 radiance = vec3(0.0);

	vec3 occlusion = vec3(0.0);
	vec3 skycontribution = vec3(0.0);

	vec3 occlusion2 = vec3(0.0);
	vec3 skycontribution2 = vec3(0.0);

	// rgb = torch color * lightmap. a = sky lightmap.
	vec4 Lighting = RT_AmbientLight(torchcolor, lightmaps);
	skylightcolor = skylightcolor * ambient_brightness * Lighting.a;

	for (int i = 0; i < nrays; i++){
		int seed = (frameCounter%40000)*nrays+i;
		vec2 ij = fract(R2_samples(seed) + noise.xy);
		vec3 rayDir = TangentToWorld(normal, normalize(cosineHemisphereSample(ij)) ,1.0);

		#ifdef HQ_SSGI
			vec3 rayHit = rayTrace_GI( mat3(gbufferModelView) * rayDir, viewPos, noise.z, 50.); // ssr rt
		#else
			vec3 rayHit = RT(mat3(gbufferModelView)*rayDir, viewPos, noise.z, 30.);  // choc sspt 
		#endif

		#ifdef SKY_CONTRIBUTION_IN_SSRT
			#ifdef OVERWORLD_SHADER
				if(isGrass) rayDir.y = clamp(rayDir.y +  0.5,-1,1);

				// rayDir.y = mix(-1.0, rayDir.y, lightmaps.y*lightmaps.y);
				
				skycontribution = ((skyCloudsFromTexLOD(rayDir, colortex4, 0).rgb / 30.0) * 2.5  * ambient_brightness) * Lighting.a + Lighting.rgb;
			#else
				skycontribution = ((skyCloudsFromTexLOD2(rayDir, colortex4, 6).rgb / 30.0) * 2.5  * ambient_brightness) * Lighting.a + Lighting.rgb;
			#endif
		#else

			#ifdef OVERWORLD_SHADER
				if(isGrass) rayDir.y = clamp(rayDir.y +  0.25,-1,1);
			#endif

			skycontribution = skylightcolor * (max(rayDir.y,pow(1.0-lightmaps.y,2))*0.95+0.05) + Lighting.rgb;

			#if indirect_effect == 4
				skycontribution2 = skylightcolor + Lighting.rgb;
			#endif

		#endif

		if (rayHit.z < 1.){
			
			#if indirect_effect == 4
				vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rayHit) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
				previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
				previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
				
				if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0){
					radiance += (texture2D(colortex5,previousPosition.xy).rgb + skycontribution) * GI_Strength;
				} else{
					radiance += skycontribution;
				}

			#else
				radiance += skycontribution;
			#endif

			occlusion += skycontribution * GI_Strength;
			
			#if indirect_effect == 4
				occlusion2 += skycontribution2 * GI_Strength;
			#endif
				
		} else {
			radiance += skycontribution;
		}
	}
	
	occlusion *= AO_Strength;
	
	#if indirect_effect == 4
		lighting = max(radiance/nrays - max(occlusion, occlusion2*0.5)/nrays, 0.0);
	#else
		lighting = max(radiance/nrays - occlusion/nrays, 0.0);
	#endif
}