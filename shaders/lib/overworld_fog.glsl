// uniform float NoRainFallEnviornmentSmooth;
uniform ivec2 eyeBrightness;

float densityAtPosFog(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	f = (f*f) * (3.-2.*f);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	vec2 xy = texture(noisetex, coord).yx;
	return mix(xy.r,xy.g, f.y);
}


float phaseRayleigh(float cosTheta) {
	const float oneOverPi 	= 1.0 / acos(-1.0);
	const vec2 mul_add = vec2(0.1, 0.28) * oneOverPi;
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

vec3 sampleShadowmapVL(vec3 start, vec3 shadowMapRayStartPos, vec3 shadowMapRayProgress, float increment){
	vec3 shadowColor = vec3(1.0);

	shadowMapRayProgress = start.xyz + increment*shadowMapRayStartPos;

	#ifdef DISTORT_SHADOWMAP
		float distortFactor = calcDistort(shadowMapRayProgress.xy);
	#else
		float distortFactor = 1.0;
	#endif

	vec3 shadowPos = vec3(shadowMapRayProgress.xy*distortFactor, shadowMapRayProgress.z);

	if (abs(shadowPos.x) < 1.0-0.5/2048. && abs(shadowPos.y) < 1.0-0.5/2048){

		shadowPos = shadowPos * vec3(0.5, 0.5, 0.5/6.0) + 0.5;

		#ifdef TRANSLUCENT_COLORED_SHADOWS
			shadowColor = vec3(shadow2D(shadowtex0, shadowPos).x);

			if(shadow2D(shadowtex1, shadowPos).x > shadowPos.z && shadowColor.x < 1.0){
				vec4 translucentShadow = texture(shadowcolor0, shadowPos.xy);
				if(translucentShadow.a < 0.9) shadowColor = normalize(translucentShadow.rgb+0.0001);
			}
		#else
			float shadowMap = shadow2D(shadow, shadowPos).x;
			shadowColor = vec3(shadowMap);
		#endif
	}
	return shadowColor;
}

vec3 getShadows(
	vec3 rayProgress, in vec3 sunVector,
	float increment, vec3 start, vec3 shadowMapRayStartPos, vec3 shadowMapRayProgress
	,float flatPhase
	,inout float sunPhase
){
	vec3 shadows = vec3(1.0);

	shadows *= sampleShadowmapVL(start, shadowMapRayStartPos, shadowMapRayProgress, increment);
	
	float cloudShadow = GetCloudShadow(rayProgress, sunVector);
	
	shadows *= cloudShadow;

	return shadows;
}

uniform bool isInSpecialEnviornment;
uniform vec3 exitedBiomePos;
// uniform float fadeAwayLocalEffect;

float getLocalEffectDensity(
	in vec3 playerPos
){	
	float fogResult = 0.0;
	
	fogResult = parameters.localFog.x;
	
	if(parameters.localFog.y > 0.0){
		vec3 pos = playerPos;
		vec3 samplePos = playerPos * vec3(1.0,1.0/48.0,1.0) * 24.0 * 7.0;
		samplePos += vec3(1.0, -0.01, 1.0)*frameTimeCounter*1500.0;

		float clumpyFog = min(max(densityAtPosFog(samplePos) - 0.2,0.0)/0.8,1.0);

		fogResult += clumpyFog * parameters.localFog.y;
	}
	
	return fogResult;
}

float getFogDensities(
	in vec3 playerPos,
	float localEffectRadius
){	

	float fogResult = 0.0;
	
	fogResult = pow(parameters.fog.x,3);
	
	if(parameters.fog.y > 0.0){
		vec3 movement = vec3(1.0, -0.01, 1.0)*frameTimeCounter;
		vec3 pos = playerPos;
		vec3 samplePos = playerPos * vec3(1.0,1.0/24.0,1.0) + movement;
		vec3 samplePos2 = playerPos * vec3(1.0,1.0/48.0,1.0) + movement;

		float shape = 1.0 - densityAtPosFog(samplePos * 24.0);
		float shape2 = 1.0 - densityAtPosFog(samplePos2 * 200.0 - vec3(min(max(shape - 0.6 ,0.0) * 2.0 ,1.0)*200.0));
		float finalShape = max(min(max(shape - 0.6 ,0.0) * 2.0 ,1.0) - shape2 * 0.4, 0.0) * exp(-0.05 * max(pos.y - 60,0.0));

		fogResult += finalShape * pow(parameters.fog.y,3);
	}
	
	return fogResult;

	// FogDensities(medium_gradientFog, cloudyFog, rainyFog, maxDistance, dailyWeatherParams0.a, dailyWeatherParams1.a);

	// return uniformFog + medium_gradientFog + cloudyFog + rainyFog;

	// float fog = pow(parameters.fog.x,5);
	// if(parameters.localFog.y > 0.0){
	// }
	// return fog;

	// vec3 samplePos = playerPos * vec3(1.0,1.0/48.0,1.0) * 24.0 * 5;
	// samplePos += vec3(1.0, -0.01, 1.0)*frameTimeCounter*1500.0;
	// float clumpyFog = densityAtPosFog(samplePos);

	// float localUniformFogDensity = pow(parameters.localFog.x,5.0);
	// float localClumpyFogDensity = pow(parameters.localFog.y,5.0);
	// float localFogEffects = localEffectRadius * (localUniformFogDensity + max(clumpyFog*localClumpyFogDensity - 0.3,0.0));

	// return localFogEffects;

	// float fogYstart = FOG_START_HEIGHT+3;
	// vec3 samplePos = pos*vec3(1.0,1./24.,1.0);
	// vec3 samplePos2 = pos*vec3(1.0,1./48.,1.0);
	
	// float uniformFog = 0.0;

	// float low_gradientFog = exp2(-0.3 * max(pos.y - fogYstart,0.0));
	// float medium_gradientFog = exp2(-0.15 * max(pos.y - fogYstart,0.0));
	// float high_gradientFog = exp2(-0.06 * max(pos.y - fogYstart,0.0));
	
	// float fog_shape = 0.0;
	// float fog_erosion = 0.0;
	// if(sandStorm < 1.0 && snowStorm < 1.0){
	// 	fog_shape = 1.0 - densityAtPosFog(samplePos * 24.0);
	// 	fog_erosion = 1.0 - densityAtPosFog(samplePos2 * 200.0 - vec3(min(max(fog_shape - 0.6 ,0.0) * 2.0 ,1.0)*200.0));
	// }
	
	// float cloudyFog = max(min(max(fog_shape - 0.6 ,0.0) * 2.0 ,1.0) - fog_erosion * 0.4	, 0.0)	*	exp(-0.05 * max(pos.y - (fogYstart+20),0.0));
	// float rainyFog = (low_gradientFog * 0.5 + exp2(-0.06 * max(pos.y - fogYstart,0.0))) * rainStrength * NoRainFallEnviornmentSmooth;
	
	// if(sandStorm > 0.0 || snowStorm > 0.0){
	// 	float IntenseFogs = pow(1.0 - densityAtPosFog( (samplePos2  - vec3(frameTimeCounter,0,frameTimeCounter)*15.0) * 100.0),2.0) * mix(1.0, high_gradientFog, snowStorm);
	// 	cloudyFog = mix(cloudyFog, IntenseFogs, sandStorm+snowStorm);

	// 	medium_gradientFog = 1.0;
	// }

	// FogDensities(medium_gradientFog, cloudyFog, rainyFog, maxDistance, 1.0, 1.0);

	// return uniformFog + medium_gradientFog + cloudyFog;
}

vec4 GetVolumetricFog(
	in vec3 viewPos,
	in vec2 dither,
	in vec3 sunVector,
	
	in vec3 LightColor,
	in vec3 AmbientColor,
	in vec3 AveragedAmbientColor,
	
	in float cloudPlaneDistance
	
	// #if defined LPV_VL_FOG_ILLUMINATION && defined EXCLUDE_WRITE_TO_LUT
	// 	,in vec3 LPV_ILLUMINATION
	// #endif

	,in vec4 phaseLevels 
	,in float backScatterPhase
){
	#ifndef TOGGLE_VL_FOG
		return vec4(0.0,0.0,0.0,1.0);
	#endif
	
	int SAMPLECOUNT = VL_SAMPLES;

	//project pixel position into projected shadowmap space
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
	vec3 rayStartPos = playerPos - gbufferModelViewInverse[3].xyz;

	vec3 localRayStartPos = rayStartPos;
	float localRayLength = length(localRayStartPos);
	localRayStartPos *= min(localRayLength, 64.0)/localRayLength;
	localRayLength = length(localRayStartPos);
	vec3 localRayProgress = vec3(0.0);

	// shadowmap stuff
	vec3 shadowViewPos = mat3(shadowModelView) * playerPos + shadowModelView[3].xyz;
	shadowViewPos = diagonal3(shadowProjection) * shadowViewPos + shadowProjection[3].xyz;
	vec3 start = toShadowSpaceProjected(vec3(0.0));
	vec3 shadowMapRayStartPos = shadowViewPos - start;

	float rayLength = length(rayStartPos);

	#ifdef USING_LOD_MOD
		float maxLength = min(rayLength, max(far, LOD_RENDERDISTANCE))/rayLength;
	#else
		float maxLength = min(rayLength, far)/rayLength;
	#endif

	shadowMapRayStartPos *= maxLength;
	rayStartPos *= maxLength;

	rayLength = length(rayStartPos);

	vec3 rayProgress = vec3(0.0);
	vec3 shadowMapRayProgress = vec3(0.0);
	float expFactor = 11.0;
	
	float indoors = clamp(eyeBrightnessSmooth.y/240.0,0,1);

	vec3 localFogColor = parameters.localFogColor.rgb;
	vec3 localFogColor_lightCol = localFogColor * dot(LightColor,vec3(0.33333));
	vec3 localFogColor_ambientCol = localFogColor * dot(AmbientColor,vec3(0.33333));
	
	vec3 color = vec3(0.0);
	float absorbance = 1.0;
	float localAbsorbance = 1.0;
	float LPVAbsorb = 1.0;
	vec3 airAbsorbance = vec3(1.0);
	
	float SdotV = dot(sunVector, normalize(playerPos));
	float rayleighPhase = phaseRayleigh(SdotV);
	float sunPhase = fogPhase(SdotV) * 5.0;
	float flatPhase =  clamp(SdotV*0.5+0.5,0.0,1.0);

	float skyPhase = 0.5 + pow(1.0-pow(1.0-clamp(normalize(playerPos).y*0.5+0.5,0.0,1.0),2.0),5.0)*2.0;

	vec3 rayleighCoeffs = vec3(sky_coefficientRayleighR*1e-6, sky_coefficientRayleighG*1e-5, sky_coefficientRayleighB*1e-5);
	vec3 mieCoeffs = vec3(sky_coefficientMieR*1e-6, sky_coefficientMieG*1e-6, sky_coefficientMieB*1e-6);

	// this is to reduce sampling problems with shadows when thick local fog is used.
	float localFogExists = (parameters.localFog.x > 0.0 || parameters.localFog.y > 0.0) ? 1.0 : 0.0;
	
	for (int i = 0; i < SAMPLECOUNT; i++) {
		float d = (pow(expFactor, float(i+dither.x)/float(SAMPLECOUNT))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither.y)/float(SAMPLECOUNT)) * log(expFactor) / float(SAMPLECOUNT)/(expFactor-1.0);

		// #if (defined CloudLayer0 || defined CloudLayer1 || defined CloudLayer2)
			// check if the fog intersects clouds
			// if(length(d*rayStartPos) > cloudPlaneDistance) break;
		// #endif
	
		#if (defined CloudLayer0 || defined CloudLayer1 || defined CloudLayer2)
			float kill = length(d*rayStartPos) > cloudPlaneDistance ? 0.0 : 1.0;
		#else
			float kill = 1.0;
		#endif

		rayProgress = gbufferModelViewInverse[3].xyz + cameraPosition + d*rayStartPos;
		localRayProgress = gbufferModelViewInverse[3].xyz + cameraPosition + d*localRayStartPos;
		
		#ifdef FAKE_PLANET
			LightColor = getPlanetAbsorb(rayProgress, WsunVec, colortex4);
		#endif

		vec3 shadows = getShadows(mix(rayProgress, localRayProgress, localFogExists), sunVector, d, start, shadowMapRayStartPos, shadowMapRayProgress, flatPhase, sunPhase);
		
		#if defined LIGHTNING_FLASH && defined LIGHTNINGFLASH_VL
			vec3 lightningFlash = createLightningPointLight(rayProgress - cameraPosition, lightningBoltPosition.xyz, 1.0, 1.0) * indoors;
		#endif
		/// ATMOSOPHERE
		float planetVolume = clamp(1.0 - length((rayProgress-cameraPosition) - vec3(0.0, 250.0, 0.0)) / 2500.0, 0.0,1.0);
		#ifdef USING_LOD_MOD
			vec2 airCoef = exp2(-max(rayProgress.y-62.0,0.0)/vec2(8.0e3, 1.2e3)*vec2(6.,7.0)) * planetVolume * 12.5 * Haze_amount;
		#else
			vec2 airCoef = exp2(-max(rayProgress.y-62.0,0.0)/vec2(8.0e3, 1.2e3)*vec2(6.,7.0)) * planetVolume * 25.0 * Haze_amount;
		#endif
		vec3 rayleigh = rayleighCoeffs*airCoef.x;
		vec3 mie = mieCoeffs*(airCoef.y + min(Haze_amount,1.0));
		vec3 airDensity = kill*(rayleigh + mie);
		vec3 airDensityPhased = rayleighPhase*rayleigh + sunPhase*mie;
		vec3 airVolumeCoeff = exp(-airDensity*dd*rayLength);

		#ifdef AERIAL_PERSPECTIVE_TEST
			vec3 airLighting = LightColor*shadows*sunPhase * airDensityPhased;
		#else
			vec3 airLighting = LightColor*shadows*sunPhase * airDensityPhased + AveragedAmbientColor*0.666*airDensity;
		#endif
		
		#if defined LIGHTNING_FLASH && defined LIGHTNINGFLASH_VL
			airLighting += lightningFlash*airDensity;
		#endif
		
		color += (airLighting - airLighting * airVolumeCoeff) / (airDensity+1e-6)*airAbsorbance;

		/// GLOBAL FOG
		float fogDensity = kill*getFogDensities(rayProgress, 0.0);


		float fogVolumeCoeff = exp(-fogDensity*dd*rayLength); 


		float beerCoef = -4.0;
		float powder = min(exp(beerCoef*exp(beerCoef*fogDensity)) * 3.5, 1);
		float backscatter = powder * backScatterPhase;
		float forwardscatter = mix(mix(phaseLevels.x, phaseLevels.y, powder), mix(phaseLevels.z, phaseLevels.w, powder), powder);
		vec3 fogLighting = (6.28 * LightColor * (forwardscatter + backscatter))*shadows + AmbientColor*skyPhase;
		// vec3 fogLighting = LightColor*sunPhase*shadows + AmbientColor*skyPhase;
		
		#if defined LIGHTNING_FLASH && defined LIGHTNINGFLASH_VL
			fogLighting += lightningFlash;
		#endif
		
		color += (fogLighting - fogLighting * fogVolumeCoeff) * absorbance;

		/// LOCAL FOG
		#if (defined CloudLayer0 || defined CloudLayer1 || defined CloudLayer2)
			kill = length(d*localRayStartPos) > cloudPlaneDistance ? 0.0 : 1.0;
		#endif

		float localEffectDensity = kill * getLocalEffectDensity(localRayProgress);

		#ifdef EXCLUDE_WRITE_TO_LUT
			localEffectDensity *= indoors;
		#endif

		float localFogVolumeCoeff = exp(-localEffectDensity*dd*localRayLength);
		float localpowder = min(exp(beerCoef*exp(beerCoef*localEffectDensity)) * 3.5, 1);
		float localbackscatter = localpowder * backScatterPhase;
		float localforwardscatter = mix(mix(phaseLevels.x, phaseLevels.y, localpowder), mix(phaseLevels.z, phaseLevels.w, localpowder), localpowder);
		vec3 localFogLighting = (6.28 * localFogColor_lightCol * (localforwardscatter + localbackscatter))*shadows + localFogColor_ambientCol*skyPhase;
		// vec3 localFogLighting = localFogColor_lightCol*shadows*sunPhase + localFogColor_ambientCol*skyPhase;
		
		color += (localFogLighting - localFogLighting * localFogVolumeCoeff) * localAbsorbance;
		
		localAbsorbance *= localFogVolumeCoeff;
		airAbsorbance *= airVolumeCoeff*fogVolumeCoeff*localFogVolumeCoeff;
		
		#ifdef AERIAL_PERSPECTIVE_TEST
			absorbance *= fogVolumeCoeff*localFogVolumeCoeff;
		#else
			absorbance *= fogVolumeCoeff*localFogVolumeCoeff*dot(airVolumeCoeff,vec3(0.33333));
		#endif
	}
	return vec4(color, absorbance);
}