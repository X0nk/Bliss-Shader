

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


float cloudVol(in vec3 pos){

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
	
	// float RainFog = max(fog_shape*10. - 7.,0.5) * exp2( -max((pos.y - SEA_LEVEL) / 25.,0.0)) * 72. * rainStrength * noPuddleAreas * RainFog_amount;
	float RainFog = (2 + max(fog_shape*10. - 7.,0.5)*2.0) * UniformFog * rainStrength * noPuddleAreas * RainFog_amount;
	
	#ifdef PER_BIOME_ENVIRONMENT
		// sandstorms and snowstorms
	  	if(sandStorm > 0 || snowStorm > 0) CloudyFog = mix(CloudyFog, max(densityAtPosFog((samplePos2  - vec3(frameTimeCounter,0,frameTimeCounter)*10) * 100.0 ) - 0.2,0.0) * heightlimit, sandStorm+snowStorm);
	#endif

	TimeOfDayFog(UniformFog, CloudyFog);

	float testfogshapes = clamp(130 - pos.y,0,1) * 100;
	// return testfogshapes;

	return CloudyFog + UniformFog + RainFog;// + testfogshapes;
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

	float maxLength = min(length(dVWorld), far)/length(dVWorld);
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

	vec3 rC = vec3(sky_coefficientRayleighR*1e-6, sky_coefficientRayleighG*1e-5, sky_coefficientRayleighB*1e-5) * 3.0;
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);

	vec3 skyLightPhased = AmbientColor;
	vec3 LightSourcePhased = LightColor;

	#ifdef ambientLight_only
		LightSourcePhased = vec3(0.0);
	#endif
	#ifdef PER_BIOME_ENVIRONMENT
		BiomeFogColor(LightSourcePhased);
		BiomeFogColor(skyLightPhased);
	#endif

	skyLightPhased = max(skyLightPhased + skyLightPhased*(normalize(wpos).y*0.9+0.1),0.0);
	LightSourcePhased *= mie;
	
	float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2) ,0.0,1.0);

	#ifdef RAYMARCH_CLOUDS_WITH_FOG
		// first cloud layer
		float MinHeight_0 = Cumulus_height;
		float MaxHeight_0 = 100 + MinHeight_0;

		// second cloud layer
		float MinHeight_1 = MaxHeight_0 + 50;
		float MaxHeight_1 = 100 + MinHeight_1;

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
		vec3 directMultiScattering = LightSourceColor * mieDayMulti * 4.0;

		vec3 sunIndirectScattering = LightSourceColor * phaseg(dot(mat3(gbufferModelView)*vec3(0,1,0),normalize(viewPosition)), 0.5) * 3.14;
	#endif

	float expFactor = 11.0;
	for (int i=0;i<VL_SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither.x)/float(VL_SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither.x)/float(VL_SAMPLES)) * log(expFactor) / float(VL_SAMPLES)/(expFactor-1.0);
		progress = start.xyz + d*dV;
		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

		//project into biased shadowmap space
		float distortFactor = calcDistort(progress.xy);
		vec3 pos = vec3(progress.xy*distortFactor, progress.z);

		float sh = 1.0;
	
		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
			sh = shadow2D(shadow, pos).x;
		}
		float sh2 = sh;

		#ifdef VL_CLOUDS_SHADOWS
			sh *= GetCloudShadow_VLFOG(progressW, WsunVec);
		#endif
		
		float densityVol = cloudVol(progressW) * lightleakfix;
		//Water droplets(fog)
		float density = densityVol*300.0;

		///// ----- main fog lighting

		//Just air
		vec2 airCoef = exp(-max(progressW.y - SEA_LEVEL, 0.0) / vec2(8.0e3, 1.2e3) * vec2(6.,7.0)) * 24 * Haze_amount;

		//Pbr for air, yolo mix between mie and rayleigh for water droplets
		vec3 rL = rC*airCoef.x;
		vec3 m = (airCoef.y+density) * mC;

		vec3 Atmosphere = skyLightPhased * (rL + m); // not pbr so just make the atmosphere also dense fog heh
		vec3 DirectLight = LightSourcePhased * sh * (rL*rayL + m);
		vec3 Lightning = Iris_Lightningflash_VLfog(progressW-cameraPosition, lightningBoltPosition.xyz) * (rL + m);

		vec3 lighting = (Atmosphere + DirectLight + Lightning) * lightleakfix;

		color += (lighting - lighting * exp(-(rL+m)*dd*dL)) / ((rL+m)+0.00000001)*absorbance;
		absorbance *= clamp(exp(-(rL+m)*dd*dL),0.0,1.0);

	#ifdef RAYMARCH_CLOUDS_WITH_FOG
		//////////////////////////////////////////
		///// ----- cloud part
		//////////////////////////////////////////

		float curvature = pow(clamp(1.0 - length(progressW)/far,0,1),2) * 50;

		// determine the base of each cloud layer
		bool isUpperLayer = max(progressW.y - MinHeight_1,0.0) > 0.0;
		float CloudBaseHeights = isUpperLayer ? 200.0 + MaxHeight_0 : MaxHeight_0;

		float cumulus = GetCumulusDensity(progressW, 1, MinHeight_0, MaxHeight_0);
		float fadedDensity = Cumulus_density * clamp(exp( (progressW.y - (CloudBaseHeights - 70)) / 9.0	 ),0.0,1.0);

		if(cumulus > 1e-5){
			float muE =	cumulus*fadedDensity;

			float directLight = 0.0;
			for (int j=0; j < 3; j++){

				vec3 shadowSamplePos = progressW + dV_Sun * (0.1 + j * (0.1 + dither.y*0.05));
				float shadow = GetCumulusDensity(shadowSamplePos, 0, MinHeight_0, MaxHeight_0) * Cumulus_density;

				directLight += shadow;
			}

			if(max(progressW.y - MaxHeight_1 + 50,0.0) < 1.0) directLight += Cumulus_density * 2.0 * GetCumulusDensity(progressW + dV_Sun/abs(dV_Sun.y) * max((MaxHeight_1 - 30.0) - progressW.y,0.0), 0, MinHeight_0, MaxHeight_0);

			float upperLayerOcclusion = !isUpperLayer ? Cumulus_density * 2.0 * GetCumulusDensity(progressW + vec3(0.0,1.0,0.0) * max((MaxHeight_1 - 30.0) - progressW.y,0.0), 0, MinHeight_0, MaxHeight_0) : 0.0;
			float skylightOcclusion = max(exp2((upperLayerOcclusion*upperLayerOcclusion) * -5), 0.75);
			
			float skyScatter = clamp((CloudBaseHeights - 20 - progressW.y) / 275.0,0.0,1.0);
			vec3 Lighting = DoCloudLighting(muE, cumulus, SkyLightColor*skylightOcclusion, skyScatter, directLight, directScattering*sh2, directMultiScattering*sh2, 1.0);

			// a horrible approximation of direct light indirectly hitting the lower layer of clouds after scattering through/bouncing off the upper layer.
			Lighting += sunIndirectScattering * exp((skyScatter*skyScatter) * cumulus * -35.0) * upperLayerOcclusion * exp(-20.0 * pow(abs(upperLayerOcclusion - 0.3),2));

			color += max(Lighting - Lighting*exp(-muE*dd*dL),0.0) * absorbance;
			absorbance *= max(exp(-muE*dd*dL),0.0);
		}
	#endif /// VL CLOUDS
	}
	return vec4(color, min(dot(absorbance,vec3(0.335)),1.0));
}

/*
// uniform bool inSpecialBiome;
vec4 GetVolumetricFog(
	vec3 viewPosition,
	float dither,
	vec3 LightColor,
	vec3 AmbientColor
){

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

	float maxLength = min(length(dVWorld), far)/length(dVWorld);
	dV *= maxLength;
	dVWorld *= maxLength;
	float dL = length(dVWorld);

	vec3 progress = start.xyz;
	vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition;

	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;
	float SdotV = dot(sunVec,normalize(viewPosition))*lightCol.a;


	/// -------------  COLOR/LIGHTING STUFF ------------- \\\

	vec3 color = vec3(0.0);
	vec3 absorbance = vec3(1.0);
	
	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
	float mie = fogPhase(SdotV) * 5.0;
	float rayL = phaseRayleigh(SdotV);

	vec3 rC = vec3(fog_coefficientRayleighR*1e-6, fog_coefficientRayleighG*1e-5, fog_coefficientRayleighB*1e-5);
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);

	vec3 LightSourceColor = LightColor;
	#ifdef ambientLight_only
		LightSourceColor = vec3(0.0);
	#endif

	vec3 skyCol0 = AmbientColor;
	#ifdef PER_BIOME_ENVIRONMENT
		BiomeFogColor(LightSourceColor);
		BiomeFogColor(skyCol0);
	#endif

	skyCol0 = max(skyCol0 + skyCol0*(normalize(wpos).y*0.9+0.1),0.0);
	


	float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2) ,0.0,1.0);
	
	float expFactor = 11.0;
	for (int i=0;i<VL_SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither)/float(VL_SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(VL_SAMPLES)) * log(expFactor) / float(VL_SAMPLES)/(expFactor-1.0);
		progress = start.xyz + d*dV;
		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
		
		//project into biased shadowmap space
		float distortFactor = calcDistort(progress.xy);
		vec3 pos = vec3(progress.xy*distortFactor, progress.z);

		float sh = 1.0;
		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
			sh = shadow2D(shadow, pos).x;
		}
		
		#ifdef VL_CLOUDS_SHADOWS
			sh *= GetCloudShadow_VLFOG(progressW, WsunVec);
		#endif
		
		float densityVol = cloudVol(progressW) * lightleakfix;
		//Water droplets(fog)
		float density = densityVol*300.;

		//Just air
		vec2 airCoef = exp(-max(progressW.y - SEA_LEVEL, 0.0) / vec2(8.0e3, 1.2e3) * vec2(6.,7.0)) * 24 * Haze_amount;

		//Pbr for air, yolo mix between mie and rayleigh for water droplets
		vec3 rL = rC*airCoef.x;
		vec3 m = (airCoef.y+density) * mC;

		vec3 AtmosphericFog = skyCol0 * (rL*3.0 + m);
		vec3 DirectLight =  (LightSourceColor*sh) * (rayL*rL*3.0 + m*mie);
		vec3 AmbientLight =  skyCol0 * m;
		vec3 Lightning = Iris_Lightningflash_VLfog(progressW-cameraPosition, lightningBoltPosition.xyz) * m;

		vec3 lighting = (AtmosphericFog + AmbientLight + DirectLight + Lightning) * lightleakfix;


		color += max(lighting - lighting * exp(-(rL+m)*dd*dL),0.0) / max(rL+m, 0.00000001)*absorbance;
		absorbance *= max(exp(-(rL+m)*dd*dL),0.0);
	}
	return vec4(color, dot(absorbance,vec3(0.333333)));
}
*/