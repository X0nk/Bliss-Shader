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

	return uniformFog + medium_gradientFog + cloudyFog;
}

float phaseRayleigh(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) / acos(-1.0);
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}
float fogPhase(float lightPoint){
	float linear = clamp(-lightPoint*0.5+0.5,0.0,1.0);
	float linear2 = 1.0 - clamp(lightPoint,0.0,1.0);

	float exponential = exp2(pow(linear,0.3) * -15.0 ) * 1.5;
	exponential += sqrt(exp2(sqrt(linear) * -12.5));

	// float exponential = 1.0 / (linear * 10.0 + 0.05);

	return exponential;
}
float phaseCloudFog(float x, float g){
    float gg = g * g;
    return (gg * -0.25 + 0.25) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5) / 3.14;
}
uniform ivec2 eyeBrightness;

vec4 GetVolumetricFog(
	in vec3 viewPosition,
	in vec3 sunVector,
	in vec2 dither,
	in vec3 LightColor,
	in vec3 AmbientColor,
	in vec3 AveragedAmbientColor,
	inout float atmosphereAlpha,
	inout vec3 sceneColor,
	in float cloudPlaneDistance
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

	float dL = length(dVWorld)/8.0;

	vec3 progress = start.xyz;
	vec3 progressW = vec3(0.0);
	float expFactor = 11.0;

	/// -------------  COLOR/LIGHTING STUFF ------------- \\\
	
	vec3 color = vec3(0.0);
	vec3 finalAbsorbance = vec3(1.0);

	// float totalAbsorbance = 1.0;
	vec3 totalAbsorbance = vec3(1.0);

	float fogAbsorbance = 1.0;
	// float atmosphereAbsorbance = 1.0;
	vec3 atmosphereAbsorbance = vec3(1.0);

	float SdotV = dot(mat3(gbufferModelView) * sunVector, normalize(viewPosition));

	///// ----- fog lighting
	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
	float sunPhase = fogPhase(SdotV)*5.0;//  phaseCloudFog(SdotV, 0.9) + phaseCloudFog(SdotV, 0.85) + phaseCloudFog(SdotV, 0.5) * 5.0;
	float sunPhase2 = (phaseCloudFog(SdotV, 0.85) + phaseCloudFog(SdotV, 0.5)) * 5.0;
	float skyPhase = 2.0 + pow(1.0-pow(1.0-clamp(normalize(wpos).y*0.5+0.5,0.0,1.0),2.0),5.0)*2.0 ;//pow(clamp(normalize(wpos).y*0.5+0.5,0.0,1.0),4.0)*5.0;
	float rayL = phaseRayleigh(SdotV);

	vec3 rC = vec3(sky_coefficientRayleighR*1e-6, sky_coefficientRayleighG*1e-5, sky_coefficientRayleighB*1e-5) ;
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);
	
	vec3 skyLightPhased = AmbientColor;
	vec3 LightSourcePhased = LightColor;

	skyLightPhased *= skyPhase;
	LightSourcePhased *= sunPhase;

	#ifdef ambientLight_only
		LightSourcePhased = vec3(0.0);
	#endif

	#ifdef PER_BIOME_ENVIRONMENT
		vec3 biomeDirect = LightSourcePhased; 
		vec3 biomeIndirect = skyLightPhased;
		float inBiome = BiomeVLFogColors(biomeDirect, biomeIndirect);
	#endif

	#if defined LPV_VL_FOG_ILLUMINATION && defined EXCLUDE_WRITE_TO_LUT
    	float TorchBrightness_autoAdjust = mix(1.0, 30.0,  clamp(exp(-10.0*exposure),0.0,1.0)) / 5.0;
	#endif

	float inACave = 1.0 - caveDetection;
	float lightLevelZero = pow(clamp(eyeBrightnessSmooth.y/240.0 ,0.0,1.0),3.0);

	// SkyLightColor *= lightLevelZero*0.9 + 0.1;
	vec3 finalsceneColor = vec3(0.0);


	for (int i = 0; i < SAMPLECOUNT; i++) {
		float d = (pow(expFactor, float(i+dither.x)/float(SAMPLECOUNT))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither.y)/float(SAMPLECOUNT)) * log(expFactor) / float(SAMPLECOUNT)/(expFactor-1.0);
		
		// check if the fog intersects clouds
		if(length(d*dVWorld) > cloudPlaneDistance) break;

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
				sh *= GetCloudShadow(progressW, sunVector);
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
			vec3 lighting = DirectLight + indirectLight;
			
			color += (lighting - lighting * fogVolumeCoeff) * totalAbsorbance;

			#if defined FLASHLIGHT && defined FLASHLIGHT_FOG_ILLUMINATION && !defined VL_CLOUDS_DEFERRED
				// vec3 shiftedViewPos = mat3(gbufferModelView)*(progressW-cameraPosition) + vec3(-0.25, 0.2, 0.0);
				// vec3 shiftedPlayerPos = mat3(gbufferModelViewInverse) * shiftedViewPos;
					vec3 shiftedViewPos;
    				vec3 shiftedPlayerPos;
					float forwardOffset;

    				#ifdef VIVECRAFT
    				    if (vivecraftIsVR) {
							forwardOffset = 0.0;
    				        shiftedPlayerPos = (progressW - cameraPosition) + ( vivecraftRelativeMainHandPos);
    				        shiftedViewPos = shiftedPlayerPos * mat3(vivecraftRelativeMainHandRot);
    				    } else
    				#endif
    				{
						forwardOffset = 0.5;
						shiftedViewPos = mat3(gbufferModelView)*(progressW-cameraPosition) + vec3(-0.25, 0.2, 0.0);
						shiftedPlayerPos = mat3(gbufferModelViewInverse) * shiftedViewPos;
    				}

				vec2 scaledViewPos = shiftedViewPos.xy / max(-shiftedViewPos.z - forwardOffset, 1e-7);
				float linearDistance = length(shiftedPlayerPos);
				float shiftedLinearDistance = length(scaledViewPos);

				float lightFalloff = 1.0 - clamp(1.0-linearDistance/FLASHLIGHT_RANGE, -0.999,1.0);
				lightFalloff = max(exp(-30.0 * lightFalloff),0.0);
				float projectedCircle = clamp(1.0 - shiftedLinearDistance*FLASHLIGHT_SIZE,0.0,1.0);

				vec3 flashlightGlow = vec3(FLASHLIGHT_R,FLASHLIGHT_G,FLASHLIGHT_B) * lightFalloff * projectedCircle * 0.5;

				color += (flashlightGlow - flashlightGlow * exp(-max(fogDensity,0.005)*dd*dL)) * totalAbsorbance;
			#endif

			// kill fog absorbance when in caves.
			totalAbsorbance *= mix(1.0, fogVolumeCoeff, lightLevelZero);
		//------------------------------------
		//------ ATMOSPHERE HAZE EFFECT
		//------------------------------------

			// maximum range for atmosphere haze, basically.
			float planetVolume = 1.0 - exp(clamp(1.0 - length(progressW-cameraPosition) / (16*150), 0.0,1.0) * -10);

			// just air
			vec2 airCoef = (exp2(-max(progressW.y-SEA_LEVEL,0.0)/vec2(8.0e3, 1.2e3)*vec2(6.,7.0)) * 192.0 * Haze_amount) * planetVolume;

			// Pbr for air, yolo mix between mie and rayleigh for water droplets
			vec3 rL = rC*airCoef.x;
			vec3 m =  mC*(airCoef.y+densityVol*300.0);

			// calculate the atmosphere haze seperately and purely additive to color, do not contribute to absorbtion.
			vec3 atmosphereVolumeCoeff = exp(-(rL+m)*dd*dL);
			// vec3 Atmosphere = LightSourcePhased * sh * (rayL*rL + sunPhase*m) + AveragedAmbientColor * (rL+m);
			vec3 Atmosphere = (LightSourcePhased * sh * (rayL*rL + sunPhase*m) + AveragedAmbientColor * (rL+m) * (lightLevelZero*0.99 + 0.01)) * inACave;
			color += (Atmosphere - Atmosphere * atmosphereVolumeCoeff) / (rL+m+1e-6) * atmosphereAbsorbance;
	
			atmosphereAbsorbance *= atmosphereVolumeCoeff*fogVolumeCoeff;

			// totalAbsorbance *= dot(atmosphereVolumeCoeff,vec3(0.33333));

		//------------------------------------
		//------ LPV FOG EFFECT
		//------------------------------------
			#if defined LPV_VL_FOG_ILLUMINATION && defined EXCLUDE_WRITE_TO_LUT 
				color += LPV_FOG_ILLUMINATION(progressW-cameraPosition, dd, dL) * totalAbsorbance;
			#endif
	}

	// sceneColor = finalsceneColor;

	// atmosphereAlpha = atmosphereAbsorbance;

	return vec4(color, totalAbsorbance);
}