

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

	vec3 samplePos = pos*vec3(1.0,1./24.,1.0);
	vec3 samplePos2 = pos*vec3(1.0,1./48.,1.0);
	float fogYstart = FOG_START_HEIGHT+3;

	float mult = exp( -max((pos.y - fogYstart) / 35.,0.0));
	float fog_shape = 1.0 - densityAtPosFog(samplePos * 24.0 );
	float fog_eroded = 1.0 - densityAtPosFog(samplePos2 * 200.0 );

	// float CloudyFog = max(	(fog_shape*2.0 - fog_eroded*0.5) - 1.2, max(fog_shape-0.8,0.0)) * mult;

	float heightlimit = exp2( -max((pos.y - fogYstart * (1.0+snowStorm)) / 25.,0.0));
	float CloudyFog = max((fog_shape*1.2 - fog_eroded*0.2) - 0.75,0.0) * heightlimit ;

	float UniformFog = exp( max(pos.y - fogYstart,0.0)  / -25);
	// UniformFog = 1.0;
	
	float RainFog = ((2 + max(fog_shape*10. - 7.0,0.5)*2.0)) *UniformFog* rainStrength * noPuddleAreas * RainFog_amount;
	// float RainFog = (CloudyFog*255) * rainStrength * noPuddleAreas * RainFog_amount;
	
	#ifdef PER_BIOME_ENVIRONMENT
		// sandstorms and snowstorms
	  	if(sandStorm > 0 || snowStorm > 0) CloudyFog = mix(CloudyFog, max(densityAtPosFog((samplePos2  - vec3(frameTimeCounter,0,frameTimeCounter)*10) * 100.0 ) - 0.2,0.0) * heightlimit, sandStorm+snowStorm);
	#endif

	TimeOfDayFog(UniformFog, CloudyFog, maxDistance);

	float noise = densityAtPosFog(samplePos * 12.0);
    float erosion = 1.0-densityAtPosFog(samplePos2 * (125 - (1-pow(1-noise,5))*25));
    

	// float clumpyFog = max(exp(noise * -5)*2 - (erosion*erosion), 0.0);

	// float testfogshapes = clumpyFog*30;
	// return testfogshapes;

	// return max(exp( max(pos.y - 90,0.0)  / -1), 0.0) * 100;
	return CloudyFog + UniformFog + RainFog;
	

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

vec4 GetVolumetricFog(
	vec3 viewPosition,
	vec2 dither,
	vec3 LightColor,
	vec3 AmbientColor
){

	#ifndef TOGGLE_VL_FOG
		return vec4(0.0,0.0,0.0,1.0);
	#endif
	int SAMPLECOUNT = VL_SAMPLES;
	/// -------------  RAYMARCHING STUFF ------------- \\\

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
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	#ifdef DISTANT_HORIZONS
		float maxLength = min(length(dVWorld), max(dhFarPlane-1000,0.0))/length(dVWorld);
		SAMPLECOUNT += SAMPLECOUNT;
	#else
		float maxLength = min(length(dVWorld), far)/length(dVWorld);
	#endif
	
	dV *= maxLength;
	dVWorld *= maxLength;

	float dL = length(dVWorld);
	float mult = length(dVWorld)/25;

	vec3 progress = start.xyz;
	vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition;

	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;
	float SdotV = dot(sunVec,normalize(viewPosition))*lightCol.a;


	/// -------------  COLOR/LIGHTING STUFF ------------- \\\

	vec3 color = vec3(0.0);
	vec3 absorbance = vec3(1.0);
	
	///// ----- fog lighting
	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
	float mie = fogPhase(SdotV) * 5.0;
	float rayL = phaseRayleigh(SdotV);

	vec3 rC = vec3(sky_coefficientRayleighR*1e-6, sky_coefficientRayleighG*1e-5, sky_coefficientRayleighB*1e-5);
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);

	vec3 skyLightPhased = AmbientColor;
	vec3 LightSourcePhased = LightColor;

	#ifdef ambientLight_only
		LightSourcePhased = vec3(0.0);
	#endif
	#ifdef PER_BIOME_ENVIRONMENT
		vec3 biomeDirect = LightSourcePhased; 
		vec3 biomeIndirect = skyLightPhased;
		float inBiome = BiomeVLFogColors(biomeDirect, biomeIndirect);
	#endif

	skyLightPhased = max(skyLightPhased + skyLightPhased*(normalize(wpos).y*0.9+0.1),0.0);
	LightSourcePhased *= mie;	
	
	float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2) ,0.0,1.0);

	#ifdef RAYMARCH_CLOUDS_WITH_FOG
		vec3 SkyLightColor = AmbientColor;
		vec3 LightSourceColor = LightColor;
		
		#ifdef ambientLight_only
			LightSourceColor = vec3(0.0);
		#endif

		float shadowStep = 200.0;

		vec3 dV_Sun = WsunVec*shadowStep;

		float mieDay = phaseg(SdotV, 0.75);
		float mieDayMulti = (phaseg(SdotV, 0.35) + phaseg(-SdotV, 0.35) * 0.5) ;

		vec3 directScattering = LightSourceColor * mieDay * 3.14;
		vec3 directMultiScattering = LightSourceColor * mieDayMulti * 3.14;

		vec3 sunIndirectScattering = LightSourceColor * phaseg(dot(mat3(gbufferModelView)*vec3(0,1,0),normalize(viewPosition)), 0.5) * 3.14;
	#endif
	
	
	#ifdef DISTANT_HORIZONS
		float atmosphereMult = 1.0;
	#else
		float atmosphereMult = 1.5;	
	#endif
	
	float expFactor = 11.0;
	for (int i=0;i<SAMPLECOUNT;i++) {
		float d = (pow(expFactor, float(i+dither.x)/float(SAMPLECOUNT))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither.x)/float(SAMPLECOUNT)) * log(expFactor) / float(SAMPLECOUNT)/(expFactor-1.0);
		progress = start.xyz + d*dV;
		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

		// float curvature = 1-exp(-25*pow(clamp(1.0 - length(progressW - cameraPosition)/(32*80),0.0,1.0),2));

		//project into biased shadowmap space
		#ifdef DISTORT_SHADOWMAP
			float distortFactor = calcDistort(progress.xy);
		#else
			float distortFactor = 1.0;
		#endif
		vec3 pos = vec3(progress.xy*distortFactor, progress.z);

		vec3 sh = vec3(1.0);
	
		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
			#ifdef TRANSLUCENT_COLORED_SHADOWS
				sh = vec3(shadow2D(shadowtex0, pos).x);
			
				if(shadow2D(shadowtex1, pos).x > pos.z && sh.x < 1.0){
				
					vec4 translucentShadow = texture2D(shadowcolor0, pos.xy);
					if(translucentShadow.a < 0.9) sh = normalize(translucentShadow.rgb+0.0001);
				}
			#else
				sh = vec3(shadow2D(shadow, pos).x);
			#endif

		}
		vec3 sh2 = sh;

		#ifdef VL_CLOUDS_SHADOWS
			// if(clamp(progressW.y - CloudLayer1_height,0.0,1.0) < 1.0 && clamp(progressW.y-50,0.0,1.0) > 0.0) 
			sh *= GetCloudShadow_VLFOG(progressW, WsunVec);
		#endif
		

		#ifdef PER_BIOME_ENVIRONMENT
			float maxDistance = inBiome * min(max(1.0 -  length(d*dVWorld.xz)/(32*8),0.0)*2.0,1.0);
			float densityVol = cloudVol(progressW, maxDistance) * lightleakfix;
		#else
			float densityVol = cloudVol(progressW, 0.0) * lightleakfix;
		#endif
		//Water droplets(fog)
		float density = densityVol*300.0;

		///// ----- main fog lighting

		//Just air
		vec2 airCoef = exp(-max(progressW.y - SEA_LEVEL, 0.0) / vec2(8.0e3, 1.2e3) * vec2(6.,7.0)) * (atmosphereMult * 24.0) * Haze_amount * clamp(CloudLayer0_height - progressW.y + max(eyeAltitude-(CloudLayer0_height-50),0),0.0,1.0);

		//Pbr for air, yolo mix between mie and rayleigh for water droplets
		vec3 rL = rC*airCoef.x;
		vec3 m = (airCoef.y+density) * mC;

		#ifdef PER_BIOME_ENVIRONMENT
			vec3 Atmosphere = mix(skyLightPhased, biomeDirect, maxDistance) * (rL + m); // not pbr so just make the atmosphere also dense fog heh
			vec3 DirectLight = mix(LightSourcePhased, biomeIndirect, maxDistance)  * sh * (rL*rayL + m);
		#else
			vec3 Atmosphere = skyLightPhased * (rL + m); // not pbr so just make the atmosphere also dense fog heh
			vec3 DirectLight = LightSourcePhased * sh * (rL*rayL + m);
		#endif
		vec3 Lightning = Iris_Lightningflash_VLfog(progressW-cameraPosition, lightningBoltPosition.xyz) * (rL + m);

		vec3 foglighting = (Atmosphere + DirectLight + Lightning) * lightleakfix;
		


		color += (foglighting - foglighting * exp(-(rL+m)*dd*dL)) / ((rL+m)+0.00000001)*absorbance;
		absorbance *= clamp(exp(-(rL+m)*dd*dL),0.0,1.0);
	
	#ifdef RAYMARCH_CLOUDS_WITH_FOG
		//////////////////////////////////////////
		///// ----- cloud part
		//////////////////////////////////////////
		// curvature = clamp(1.0 - length(progressW - cameraPosition)/(32*128),0.0,1.0);
		

		float otherlayer = max(progressW.y - (CloudLayer0_height+99.5), 0.0) > 0.0 ? 0.0 : 1.0;

		float DUAL_MIN_HEIGHT = otherlayer > 0.0 ? CloudLayer0_height : CloudLayer1_height;
		float DUAL_MAX_HEIGHT = DUAL_MIN_HEIGHT + 100.0;

		float DUAL_DENSITY = otherlayer > 0.0 ? CloudLayer0_density : CloudLayer1_density;
		
		if(clamp(progressW.y - DUAL_MAX_HEIGHT,0.0,1.0) < 1.0 && clamp(progressW.y - DUAL_MIN_HEIGHT,0.0,1.0) > 0.0){
		
		float DUAL_MIN_HEIGHT_2 = otherlayer > 0.0 ? CloudLayer0_height : CloudLayer1_height;
		float DUAL_MAX_HEIGHT_2 = DUAL_MIN_HEIGHT + 100.0;

		float cumulus = GetCumulusDensity(-1, progressW, 1, CloudLayer0_height, CloudLayer1_height);
		float fadedDensity = DUAL_DENSITY * clamp(exp( (progressW.y - (DUAL_MAX_HEIGHT - 75)) / 9.0	 ),0.0,1.0);

		float muE = cumulus*fadedDensity;
		float directLight = 0.0;
		for (int j=0; j < 3; j++){
			vec3 shadowSamplePos = progressW + dV_Sun * (0.1 + j * (0.1 + dither.y*0.05));
			float shadow = GetCumulusDensity(-1, shadowSamplePos, 0, DUAL_MIN_HEIGHT, DUAL_MAX_HEIGHT) * DUAL_DENSITY;

			directLight += shadow;
		}

		/// shadows cast from one layer to another
		/// large cumulus -> small cumulus
		#if defined CloudLayer1 && defined CloudLayer0
			if(otherlayer > 0.0) directLight += LAYER1_DENSITY * 2.0 * GetCumulusDensity(1, progressW + dV_Sun/abs(dV_Sun.y) * max((LAYER1_minHEIGHT+70*dither.y) - progressW.y,0.0), 0, LAYER1_minHEIGHT, LAYER1_maxHEIGHT);
		#endif
		// // altostratus -> cumulus
		// #ifdef CloudLayer2
		// 	vec3 HighAlt_shadowPos = rayProgress + dV_Sun/abs(dV_Sun.y) * max(LAYER2_HEIGHT - rayProgress.y,0.0);
		// 	float HighAlt_shadow = GetAltostratusDensity(HighAlt_shadowPos) * CloudLayer2_density;
		// 	directLight += HighAlt_shadow;
		// #endif


		float skyScatter = clamp(((DUAL_MAX_HEIGHT - 20 - progressW.y) / 275.0)  * (0.5+DUAL_DENSITY),0.0,1.0);
		float distantfade = 1- exp( -10*pow(clamp(1.0 - length(progressW - cameraPosition)/(32*65),0.0,1.0),2));
		vec3 cloudlighting = DoCloudLighting(muE, cumulus, SkyLightColor, skyScatter, directLight, directScattering*sh2, directMultiScattering*sh2, 1);

		color += max(cloudlighting - cloudlighting*exp(-muE*dd*dL),0.0) * absorbance;
		absorbance *= max(exp(-muE*dd*dL),0.0);
		}
		
	#endif
	
		if (min(dot(absorbance,vec3(0.335)),1.0) < 1e-5) break;
	}
	return vec4(color, min(dot(absorbance,vec3(0.335)),1.0));
}