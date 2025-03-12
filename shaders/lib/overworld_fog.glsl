uniform float noPuddleAreas;

float densityAtPosFog(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	f = (f*f) * (3.-2.*f);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	vec2 xy = texture2D(noisetex, coord).yx;
	return mix(xy.r,xy.g, f.y);
}


float cloudVol(in vec3 pos, float maxDistance ){
	
	float fogYstart = FOG_START_HEIGHT+3;
	vec3 samplePos = pos*vec3(1.0,1./24.,1.0);
	vec3 samplePos2 = pos*vec3(1.0,1./48.,1.0);
	
	float uniformFog = 0.0;

	float low_gradientFog = exp2(-0.3 * max(pos.y - fogYstart,0.0));
	float medium_gradientFog = exp2(-0.15 * max(pos.y - fogYstart,0.0));
	float high_gradientFog = exp2(-0.06 * max(pos.y - fogYstart,0.0));
	
	float fog_shape = 0.0;
	float fog_erosion = 0.0;
	if(sandStorm < 1.0 && snowStorm < 1.0){
		fog_shape = 1.0 - densityAtPosFog(samplePos * 24.0);
		fog_erosion = 1.0 - densityAtPosFog(samplePos2 * 200.0 - vec3(min(max(fog_shape - 0.6 ,0.0) * 2.0 ,1.0)*200.0));
	}
	
	float cloudyFog = max(min(max(fog_shape - 0.6 ,0.0) * 2.0 ,1.0) - fog_erosion * 0.4	, 0.0)	*	exp(-0.05 * max(pos.y - (fogYstart+20),0.0));
	float rainyFog = (low_gradientFog * 0.5 + exp2(-0.06 * max(pos.y - fogYstart,0.0))) * rainStrength * noPuddleAreas;
	
	if(sandStorm > 0.0 || snowStorm > 0.0){
		float IntenseFogs = pow(1.0 - densityAtPosFog( (samplePos2  - vec3(frameTimeCounter,0,frameTimeCounter)*15.0) * 100.0),2.0) * mix(1.0, high_gradientFog, snowStorm);
		cloudyFog = mix(cloudyFog, IntenseFogs, sandStorm+snowStorm);

		medium_gradientFog = 1.0;
	}

	FogDensities(medium_gradientFog, cloudyFog, rainyFog, maxDistance, dailyWeatherParams0.a, dailyWeatherParams1.a);

	return uniformFog + medium_gradientFog + cloudyFog + rainyFog;
}

float phaseRayleigh(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) / acos(-1.0);
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}
float fogPhase(float lightPoint){
	float linear = 1.0 - clamp(lightPoint*0.5+0.5,0.0,1.0);
	float linear2 = 1.0 - clamp(lightPoint,0.0,1.0);

	float exponential = exp2(pow(linear,0.3) * -15.0 ) * 1.5;
	exponential += sqrt(exp2(sqrt(linear) * -12.5));

	return exponential;
}

uniform ivec2 eyeBrightness;
vec4 GetVolumetricFog(
	vec3 viewPosition,
	vec2 dither,
	vec3 LightColor,
	vec3 AmbientColor,
	vec3 AveragedAmbientColor,
	inout float atmosphereAlpha
){
	#ifndef TOGGLE_VL_FOG
		return vec4(0.0,0.0,0.0,1.0);
	#endif
	
	/// -------------  RAYMARCHING STUFF ------------- \\\

	int SAMPLECOUNT = VL_SAMPLES;

	//project pixel position into projected shadowmap space
	vec3 wpos = mat3(gbufferModelViewInverse) * viewPosition + gbufferModelViewInverse[3].xyz;
	vec3 fragposition = mat3(shadowModelView) * wpos + shadowModelView[3].xyz;
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;

	//project view origin into projected shadowmap space
	vec3 start = toShadowSpaceProjected(vec3(0.0));

	//rayvector into projected shadow map space
	//we can use a projected vector because its orthographic projection
	//however we still have to send it to curved shadow map space every step
	vec3 dV = fragposition - start;
	vec3 dVWorld = wpos - gbufferModelViewInverse[3].xyz;

	#ifdef DISTANT_HORIZONS
		float maxLength = min(length(dVWorld), max(far, dhRenderDistance))/length(dVWorld);
	#else
		float maxLength = min(length(dVWorld), far)/length(dVWorld);
	#endif
	
	dV *= maxLength;
	dVWorld *= maxLength;

	float dL_alternate = length(dVWorld);
	float dL = dL_alternate/8.0;

	vec3 progress = start.xyz;
	vec3 progressW = vec3(0.0);
	float expFactor = 11.0;

	/// -------------  COLOR/LIGHTING STUFF ------------- \\\
	
	vec3 color = vec3(0.0);
	float totalAbsorbance = 1.0;
	float fogAbsorbance = 1.0;
	float atmosphereAbsorbance = 1.0;

	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec;
	float SdotV = dot(sunVec, normalize(viewPosition))*lightCol.a;

	///// ----- fog lighting
	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
	float sunPhase = fogPhase(SdotV) * 5.0;
	float skyPhase = pow(clamp(normalize(wpos).y*0.5+0.5,0.0,1.0),4.0)*5.0;
	float rayL = phaseRayleigh(SdotV);

	vec3 rC = vec3(sky_coefficientRayleighR*1e-6, sky_coefficientRayleighG*1e-5, sky_coefficientRayleighB*1e-5) ;
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);
	
	vec3 skyLightPhased = AmbientColor;
	vec3 LightSourcePhased = LightColor;

	skyLightPhased *= 1.0 + skyPhase;
	LightSourcePhased *= sunPhase;

	#ifdef ambientLight_only
		LightSourcePhased = vec3(0.0);
	#endif

	#ifdef PER_BIOME_ENVIRONMENT
		vec3 biomeDirect = LightSourcePhased; 
		vec3 biomeIndirect = skyLightPhased;
		float inBiome = BiomeVLFogColors(biomeDirect, biomeIndirect);
	#endif

	#ifdef DISTANT_HORIZONS
		float atmosphereMult = 1.0;
	#else
		float atmosphereMult = 1.5;
	#endif

	#ifdef RAYMARCH_CLOUDS_WITH_FOG
		vec3 SkyLightColor = AmbientColor;
		vec3 LightSourceColor = LightColor;
		
		#ifdef ambientLight_only
			LightSourceColor = vec3(0.0);
		#endif

		vec3 dV_Sun = WsunVec;

		float mieDay = phaseg(SdotV, 0.85) + phaseg(SdotV, 0.75);
		float mieDayMulti = (phaseg(SdotV, 0.35) + phaseg(-SdotV, 0.35) * 0.5);

		vec3 directScattering = LightSourceColor * mieDay * 3.14;
		vec3 directMultiScattering = LightSourceColor * mieDayMulti * 3.14 * 2.0;
	#endif

	#if defined LPV_VL_FOG_ILLUMINATION && defined EXCLUDE_WRITE_TO_LUT
    	float TorchBrightness_autoAdjust = mix(1.0, 30.0,  clamp(exp(-10.0*exposure),0.0,1.0)) / 5.0;
	#endif

	float inACave = 1.0 - caveDetection;
	float lightLevelZero = pow(clamp(eyeBrightnessSmooth.y/240.0 ,0.0,1.0),3.0);

	// SkyLightColor *= lightLevelZero*0.9 + 0.1;

	for (int i = 0; i < SAMPLECOUNT; i++) {
		float d = (pow(expFactor, float(i+dither.x)/float(SAMPLECOUNT))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither.x)/float(SAMPLECOUNT)) * log(expFactor) / float(SAMPLECOUNT)/(expFactor-1.0);
		
		progress = start.xyz + d*dV;
		progressW = gbufferModelViewInverse[3].xyz + cameraPosition + d*dVWorld;

		//------------------------------------
		//------ SAMPLE SHADOWS FOR FOG EFFECTS
		//------------------------------------
			#ifdef DISTORT_SHADOWMAP
				float distortFactor = calcDistort(progress.xy);
			#else
				float distortFactor = 1.0;
			#endif
			vec3 shadowPos = vec3(progress.xy*distortFactor, progress.z);

			vec3 sh = vec3(1.0);
			if (abs(shadowPos.x) < 1.0-0.5/2048. && abs(shadowPos.y) < 1.0-0.5/2048){
				shadowPos = shadowPos*vec3(0.5,0.5,0.5/6.0)+0.5;

				#ifdef TRANSLUCENT_COLORED_SHADOWS
					sh = vec3(shadow2D(shadowtex0, shadowPos).x);

					if(shadow2D(shadowtex1, shadowPos).x > shadowPos.z && sh.x < 1.0){
						vec4 translucentShadow = texture2D(shadowcolor0, shadowPos.xy);
						if(translucentShadow.a < 0.9) sh = normalize(translucentShadow.rgb+0.0001);
					}
				#else
					sh = vec3(shadow2D(shadow, shadowPos).x);
				#endif
			}
			#ifdef RAYMARCH_CLOUDS_WITH_FOG
				vec3 sh_forClouds = sh;
			#endif

			#ifdef VL_CLOUDS_SHADOWS
				sh *= GetCloudShadow_VLFOG(progressW, WsunVec * lightCol.a);
			#endif

		#ifdef PER_BIOME_ENVIRONMENT
			float maxDistance = inBiome * min(max(1.0 -  length(d*dVWorld.xz)/(32*8),0.0)*2.0,1.0);
			float densityVol = cloudVol(progressW, maxDistance) * inACave;
		#else
			float densityVol = cloudVol(progressW, 0.0) * inACave;
		#endif

		//------------------------------------
		//------ MAIN FOG EFFECT
		//------------------------------------
			float fogDensity = densityVol;
			float fogVolumeCoeff = exp(-fogDensity*dd*dL); // this is like beer-lambert law or something

			#ifdef PER_BIOME_ENVIRONMENT
				vec3 indirectLight = mix(skyLightPhased, biomeIndirect, maxDistance);
				vec3 DirectLight = mix(LightSourcePhased, biomeDirect, maxDistance) * sh;
			#else
				vec3 indirectLight = skyLightPhased;
				vec3 DirectLight = LightSourcePhased * sh;
			#endif

			vec3 Lightning = Iris_Lightningflash_VLfog(progressW-cameraPosition, lightningBoltPosition.xyz);
			vec3 lighting = DirectLight + indirectLight * (lightLevelZero*0.99 + 0.01) + Lightning;

			color += (lighting - lighting * fogVolumeCoeff) * fogAbsorbance;
			fogAbsorbance *= fogVolumeCoeff;

			// kill fog absorbance when in caves.
			totalAbsorbance *= mix(1.0, fogVolumeCoeff, lightLevelZero);
		//------------------------------------
		//------ ATMOSPHERE HAZE EFFECT
		//------------------------------------
			#if defined CloudLayer0 && defined VOLUMETRIC_CLOUDS
				float cloudPlaneCutoff = clamp((CloudLayer0_height +  max(eyeAltitude-(CloudLayer0_height-100),0)) - progressW.y,0.0,1.0);
			#else
				float cloudPlaneCutoff = 1.0;
			#endif

			// just air
			vec2 airCoef = exp2(-max(progressW.y-SEA_LEVEL,0.0)/vec2(8.0e3, 1.2e3)*vec2(6.,7.0)) * (24.0 * atmosphereMult) * Haze_amount * cloudPlaneCutoff;

			// Pbr for air, yolo mix between mie and rayleigh for water droplets
			vec3 rL = rC*airCoef.x;
			vec3 m =  mC*(airCoef.y+densityVol*300.0);

			// calculate the atmosphere haze seperately and purely additive to color, do not contribute to absorbtion.
			vec3 atmosphereVolumeCoeff = exp(-(rL+m)*dd*dL_alternate);
			
			vec3 Atmosphere = (LightSourcePhased * sh * (rayL*rL + sunPhase*m) + AveragedAmbientColor * (rL+m) * (lightLevelZero*0.99 + 0.01)) * inACave;
			color += (Atmosphere - Atmosphere * atmosphereVolumeCoeff) / (rL+m+1e-6) * atmosphereAbsorbance * totalAbsorbance;
			atmosphereAbsorbance *= dot(atmosphereVolumeCoeff, vec3(0.33333));
			
		//------------------------------------
		//------ LPV FOG EFFECT
		//------------------------------------
			#if defined LPV_VL_FOG_ILLUMINATION && defined EXCLUDE_WRITE_TO_LUT 
				color += LPV_FOG_ILLUMINATION(progressW-cameraPosition, dd, dL) * TorchBrightness_autoAdjust * totalAbsorbance;
			#endif
		//------------------------------------
		//------ STUPID RENDER CLOUDS AS FOG EFFECT
		//------------------------------------
		#ifdef RAYMARCH_CLOUDS_WITH_FOG
			float otherlayer = max(progressW.y - (CloudLayer0_height+99.5), 0.0) > 0.0 ? 0.0 : 1.0;

			float DUAL_MIN_HEIGHT = otherlayer > 0.0 ? CloudLayer0_height : CloudLayer1_height;
			float DUAL_MAX_HEIGHT = DUAL_MIN_HEIGHT + 100.0;

			float DUAL_DENSITY = otherlayer > 0.0 ? CloudLayer0_density : CloudLayer1_density;

			if(clamp(progressW.y - DUAL_MAX_HEIGHT,0.0,1.0) < 1.0 && clamp(progressW.y - DUAL_MIN_HEIGHT,0.0,1.0) > 0.0){
			
				#if defined CloudLayer1 && defined CloudLayer0
					float upperLayerOcclusion = otherlayer > 0.0 ? GetCumulusDensity(1, progressW + vec3(0.0,1.0,0.0) * max((LAYER1_minHEIGHT+30) - progressW.y,0.0), 0, LAYER1_minHEIGHT, LAYER1_maxHEIGHT) : 0.0;
					float skylightOcclusion = mix(1.0, (1.0 - LAYER1_DENSITY)*0.8 + 0.2, (1.0 - exp2(-5.0 * (upperLayerOcclusion*upperLayerOcclusion))));
				#else
					float skylightOcclusion = 1.0;
				#endif

				float DUAL_MIN_HEIGHT_2 = otherlayer > 0.0 ? CloudLayer0_height : CloudLayer1_height;
				float DUAL_MAX_HEIGHT_2 = DUAL_MIN_HEIGHT + 100.0;

				float cumulus = GetCumulusDensity(-1, progressW, 1, CloudLayer0_height, CloudLayer1_height);
				float fadedDensity = DUAL_DENSITY * pow(clamp((progressW.y - DUAL_MIN_HEIGHT_2)/25,0.0,1.0),2.0);

				float muE = cumulus*fadedDensity;
				float directLight = 0.0;

				if(muE > 1e-5){

					for (int j=0; j < 3; j++){
						// vec3 shadowSamplePos = progressW + dV_Sun * (0.1 + j * (0.1 + dither.y*0.05));
						vec3 shadowSamplePos = progressW + dV_Sun * (20.0 + j * (20.0 + dither.y*20.0));
						float shadow = GetCumulusDensity(-1, shadowSamplePos, 0, DUAL_MIN_HEIGHT, DUAL_MAX_HEIGHT) * DUAL_DENSITY;

						directLight += shadow;
					}

					/// shadows cast from one layer to another
					/// large cumulus -> small cumulus
					#if defined CloudLayer1 && defined CloudLayer0
						if(otherlayer > 0.0) directLight += LAYER1_DENSITY * 2.0 * GetCumulusDensity(1, progressW + dV_Sun/abs(dV_Sun.y) * max((LAYER1_minHEIGHT+35) - progressW.y,0.0), 0, LAYER1_minHEIGHT, LAYER1_maxHEIGHT);
					#endif
					// altostratus -> cumulus
					#ifdef CloudLayer2
						vec3 HighAlt_shadowPos = progressW + dV_Sun/abs(dV_Sun.y) * max(LAYER2_HEIGHT - progressW.y,0.0);
						float HighAlt_shadow = GetAltostratusDensity(HighAlt_shadowPos) * CloudLayer2_density * (1.0-abs(WsunVec.y));
						directLight += HighAlt_shadow;
					#endif

					float skyScatter = clamp(((DUAL_MAX_HEIGHT - progressW.y) / 100.0),0.0,1.0); // linear gradient from bottom to top of cloud layer
					float distantfade = 1- exp( -10*pow(clamp(1.0 - length(progressW - cameraPosition)/(32*65),0.0,1.0),2));
					vec3 cloudlighting = DoCloudLighting(DUAL_DENSITY * cumulus, SkyLightColor*skylightOcclusion, skyScatter, directLight, directScattering*sh_forClouds, directMultiScattering*sh_forClouds, 1);

					color += max(cloudlighting - cloudlighting*exp(-muE*dd*dL_alternate),0.0) * totalAbsorbance * lightLevelZero;
					totalAbsorbance *= max(exp(-muE*dd*dL_alternate),1.0-lightLevelZero);
				}
			}
		#else
			if (totalAbsorbance < 1e-5) break;
		#endif
	}
	atmosphereAlpha = atmosphereAbsorbance;
	return vec4(color, totalAbsorbance);
}



















// vec4 GetVolumetricFog(
// 	vec3 viewPosition,
// 	vec2 dither,
// 	vec3 LightColor,
// 	vec3 AmbientColor
// ){

// 	#ifndef TOGGLE_VL_FOG
// 		return vec4(0.0,0.0,0.0,1.0);
// 	#endif
// 	int SAMPLECOUNT = VL_SAMPLES;
// 	/// -------------  RAYMARCHING STUFF ------------- \\\

// 	//project pixel position into projected shadowmap space
	
// 	vec3 wpos = mat3(gbufferModelViewInverse) * viewPosition + gbufferModelViewInverse[3].xyz;
// 	vec3 fragposition = mat3(shadowModelView) * wpos + shadowModelView[3].xyz;
// 	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;

// 	//project view origin into projected shadowmap space
// 	vec3 start = toShadowSpaceProjected(vec3(0.0));

// 	//rayvector into projected shadow map space
// 	//we can use a projected vector because its orthographic projection
// 	//however we still have to send it to curved shadow map space every step
// 	vec3 dV = fragposition - start;
// 	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

// 	#ifdef DISTANT_HORIZONS
// 		float maxLength = min(length(dVWorld), max(dhFarPlane-1000,0.0))/length(dVWorld);
// 		SAMPLECOUNT += SAMPLECOUNT;
// 	#else
// 		float maxLength = min(length(dVWorld), far)/length(dVWorld);
// 	#endif
	
// 	dV *= maxLength;
// 	dVWorld *= maxLength;

// 	float dL = length(dVWorld);
// 	float mult = length(dVWorld)/25;

// 	vec3 progress = start.xyz;
// 	vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition;

// 	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;
// 	float SdotV = dot(sunVec,normalize(viewPosition))*lightCol.a;


// 	/// -------------  COLOR/LIGHTING STUFF ------------- \\\

// 	vec3 color = vec3(0.0);
// 	vec3 absorbance = vec3(1.0);
	
// 	///// ----- fog lighting
// 	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
// 	float mie = fogPhase(SdotV) * 5.0;
// 	float rayL = phaseRayleigh(SdotV);

// 	vec3 rC = vec3(sky_coefficientRayleighR*1e-6, sky_coefficientRayleighG*1e-5, sky_coefficientRayleighB*1e-5);
// 	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);

// 	vec3 skyLightPhased = AmbientColor;
// 	vec3 LightSourcePhased = LightColor;

// 	#ifdef ambientLight_only
// 		LightSourcePhased = vec3(0.0);
// 	#endif
// 	#ifdef PER_BIOME_ENVIRONMENT
// 		vec3 biomeDirect = LightSourcePhased; 
// 		vec3 biomeIndirect = skyLightPhased;
// 		float inBiome = BiomeVLFogColors(biomeDirect, biomeIndirect);
// 	#endif

// 	skyLightPhased = max(skyLightPhased + skyLightPhased*(normalize(wpos).y*0.9+0.1),0.0);
// 	LightSourcePhased *= mie;	
	
// 	// float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2) ,0.0,1.0);
	
// 	float lightleakfix = 1.0 - caveDetection;

// 	#ifdef RAYMARCH_CLOUDS_WITH_FOG
// 		vec3 SkyLightColor = AmbientColor;
// 		vec3 LightSourceColor = LightColor;
		
// 		#ifdef ambientLight_only
// 			LightSourceColor = vec3(0.0);
// 		#endif

// 		float shadowStep = 200.0;

// 		vec3 dV_Sun = WsunVec*shadowStep;

// 		float mieDay = phaseg(SdotV, 0.75);
// 		float mieDayMulti = (phaseg(SdotV, 0.35) + phaseg(-SdotV, 0.35) * 0.5) ;

// 		vec3 directScattering = LightSourceColor * mieDay * 3.14;
// 		vec3 directMultiScattering = LightSourceColor * mieDayMulti * 3.14;

// 		vec3 sunIndirectScattering = LightSourceColor * phaseg(dot(mat3(gbufferModelView)*vec3(0,1,0),normalize(viewPosition)), 0.5) * 3.14;
// 	#endif
	
	
// 	#ifdef DISTANT_HORIZONS
// 		float atmosphereMult = 1.0;
// 	#else
// 		float atmosphereMult = 1.5;	
// 	#endif
	
// 	float expFactor = 11.0;
// 	for (int i=0;i<SAMPLECOUNT;i++) {
// 		float d = (pow(expFactor, float(i+dither.x)/float(SAMPLECOUNT))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
// 		float dd = pow(expFactor, float(i+dither.x)/float(SAMPLECOUNT)) * log(expFactor) / float(SAMPLECOUNT)/(expFactor-1.0);
// 		progress = start.xyz + d*dV;
// 		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

// 		// float curvature = 1-exp(-25*pow(clamp(1.0 - length(progressW - cameraPosition)/(32*80),0.0,1.0),2));

// 		//project into biased shadowmap space
// 		#ifdef DISTORT_SHADOWMAP
// 			float distortFactor = calcDistort(progress.xy);
// 		#else
// 			float distortFactor = 1.0;
// 		#endif
// 		vec3 pos = vec3(progress.xy*distortFactor, progress.z);

// 		vec3 sh = vec3(1.0);
	
// 		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
// 			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;

// 			#ifdef TRANSLUCENT_COLORED_SHADOWS
// 				sh = vec3(shadow2D(shadowtex0, pos).x);
			
// 				if(shadow2D(shadowtex1, pos).x > pos.z && sh.x < 1.0){
// 					vec4 translucentShadow = texture2D(shadowcolor0, pos.xy);
// 					if(translucentShadow.a < 0.9) sh = normalize(translucentShadow.rgb+0.0001);
// 				}
// 			#else
// 				sh = vec3(shadow2D(shadow, pos).x);
// 			#endif

// 		}
// 		vec3 sh2 = sh;

// 		#ifdef VL_CLOUDS_SHADOWS
// 			// if(clamp(progressW.y - CloudLayer1_height,0.0,1.0) < 1.0 && clamp(progressW.y-50,0.0,1.0) > 0.0) 
// 			sh *= GetCloudShadow_VLFOG(progressW, WsunVec);
// 		#endif
		

// 		#ifdef PER_BIOME_ENVIRONMENT
// 			float maxDistance = inBiome * min(max(1.0 -  length(d*dVWorld.xz)/(32*8),0.0)*2.0,1.0);
// 			float densityVol = cloudVol(progressW, maxDistance) * lightleakfix;
// 		#else
// 			float densityVol = cloudVol(progressW, 0.0) * lightleakfix;
// 		#endif

// 		//Water droplets(fog)
// 		float density = densityVol*300.0;

// 		///// ----- main fog lighting

// 		//Just air
// 		vec2 airCoef = exp(-max(progressW.y - SEA_LEVEL, 0.0) / vec2(8.0e3, 1.2e3) * vec2(6.,7.0)) * (atmosphereMult * 24.0) * Haze_amount * clamp(CloudLayer0_height - progressW.y + max(eyeAltitude-(CloudLayer0_height-50),0),0.0,1.0);

// 		//Pbr for air, yolo mix between mie and rayleigh for water droplets
// 		vec3 rL = rC*airCoef.x;
// 		vec3 m = (airCoef.y+density) * mC;

// 		#ifdef PER_BIOME_ENVIRONMENT
// 			vec3 Atmosphere = mix(skyLightPhased, biomeDirect, maxDistance) * (rL + m); // not pbr so just make the atmosphere also dense fog heh
// 			vec3 DirectLight = mix(LightSourcePhased, biomeIndirect, maxDistance)  * sh * (rL*rayL + m);
// 		#else
// 			vec3 Atmosphere = skyLightPhased * (rL + m); // not pbr so just make the atmosphere also dense fog heh
// 			vec3 DirectLight = LightSourcePhased * sh * (rL*rayL + m);
// 		#endif
// 		vec3 Lightning = Iris_Lightningflash_VLfog(progressW-cameraPosition, lightningBoltPosition.xyz) * (rL + m);

// 		vec3 foglighting = (Atmosphere + DirectLight + Lightning) * lightleakfix;
		


// 		color += (foglighting - foglighting * exp(-(rL+m)*dd*dL)) / ((rL+m)+0.00000001)*absorbance;
// 		absorbance *= clamp(exp(-(rL+m)*dd*dL),0.0,1.0);
	
// 	#ifdef RAYMARCH_CLOUDS_WITH_FOG
// 		//////////////////////////////////////////
// 		///// ----- cloud part
// 		//////////////////////////////////////////
// 		// curvature = clamp(1.0 - length(progressW - cameraPosition)/(32*128),0.0,1.0);
		

// 		float otherlayer = max(progressW.y - (CloudLayer0_height+99.5), 0.0) > 0.0 ? 0.0 : 1.0;

// 		float DUAL_MIN_HEIGHT = otherlayer > 0.0 ? CloudLayer0_height : CloudLayer1_height;
// 		float DUAL_MAX_HEIGHT = DUAL_MIN_HEIGHT + 100.0;

// 		float DUAL_DENSITY = otherlayer > 0.0 ? CloudLayer0_density : CloudLayer1_density;
		
// 		if(clamp(progressW.y - DUAL_MAX_HEIGHT,0.0,1.0) < 1.0 && clamp(progressW.y - DUAL_MIN_HEIGHT,0.0,1.0) > 0.0){
		
// 		float DUAL_MIN_HEIGHT_2 = otherlayer > 0.0 ? CloudLayer0_height : CloudLayer1_height;
// 		float DUAL_MAX_HEIGHT_2 = DUAL_MIN_HEIGHT + 100.0;

// 		float cumulus = GetCumulusDensity(-1, progressW, 1, CloudLayer0_height, CloudLayer1_height);
// 		float fadedDensity = DUAL_DENSITY * clamp(exp( (progressW.y - (DUAL_MAX_HEIGHT - 75)) / 9.0	 ),0.0,1.0);

// 		float muE = cumulus*fadedDensity;
// 		float directLight = 0.0;
// 		for (int j=0; j < 3; j++){
// 			vec3 shadowSamplePos = progressW + dV_Sun * (0.1 + j * (0.1 + dither.y*0.05));
// 			float shadow = GetCumulusDensity(-1, shadowSamplePos, 0, DUAL_MIN_HEIGHT, DUAL_MAX_HEIGHT) * DUAL_DENSITY;

// 			directLight += shadow;
// 		}

// 		/// shadows cast from one layer to another
// 		/// large cumulus -> small cumulus
// 		#if defined CloudLayer1 && defined CloudLayer0
// 			if(otherlayer > 0.0) directLight += LAYER1_DENSITY * 2.0 * GetCumulusDensity(1, progressW + dV_Sun/abs(dV_Sun.y) * max((LAYER1_minHEIGHT+70*dither.y) - progressW.y,0.0), 0, LAYER1_minHEIGHT, LAYER1_maxHEIGHT);
// 		#endif
// 		// // altostratus -> cumulus
// 		// #ifdef CloudLayer2
// 		// 	vec3 HighAlt_shadowPos = rayProgress + dV_Sun/abs(dV_Sun.y) * max(LAYER2_HEIGHT - rayProgress.y,0.0);
// 		// 	float HighAlt_shadow = GetAltostratusDensity(HighAlt_shadowPos) * CloudLayer2_density;
// 		// 	directLight += HighAlt_shadow;
// 		// #endif


// 		float skyScatter = clamp(((DUAL_MAX_HEIGHT - 20 - progressW.y) / 275.0)  * (0.5+DUAL_DENSITY),0.0,1.0);
// 		float distantfade = 1- exp( -10*pow(clamp(1.0 - length(progressW - cameraPosition)/(32*65),0.0,1.0),2));
// 		vec3 cloudlighting = DoCloudLighting(cloudDensity * cumulus, SkyLightColor, skyScatter, directLight, directScattering*sh2, directMultiScattering*sh2, 1);

// 		color += max(cloudlighting - cloudlighting*exp(-muE*dd*dL),0.0) * absorbance;
// 		absorbance *= max(exp(-muE*dd*dL),0.0);
// 		}
		
// 	#endif
	
// 		if (min(dot(absorbance,vec3(0.335)),1.0) < 1e-5) break;
// 	}
// 	return vec4(color, min(dot(absorbance,vec3(0.335)),1.0));
// }