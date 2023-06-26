
vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}


float phaseRayleigh(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) /acos(-1.0);
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

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


	float mult = exp( -max((pos.y - SEA_LEVEL) / 35.,0.0));

	float fog_shape = 1.0 - densityAtPosFog(samplePos * 24.0);
	float fog_eroded = 1.0 - densityAtPosFog(	samplePos2 * 200.0);

	// float CloudyFog = max(	(fog_shape*2.0 - fog_eroded*0.5) - 1.2, max(fog_shape-0.8,0.0)) * mult;

	float heightlimit = exp2( -max((pos.y - SEA_LEVEL) / 25.,0.0));
	float CloudyFog = max((fog_shape*1.2 - fog_eroded*0.2) - 0.75,0.0) * heightlimit ;

	float UniformFog = exp2( -max((pos.y - SEA_LEVEL) / 25.,0.0));
	
	float RainFog = max(fog_shape*10. - 7.,0.5) * exp2( -max((pos.y - SEA_LEVEL) / 25.,0.0)) * 5. * rainStrength * noPuddleAreas * RainFog_amount;
	
	TimeOfDayFog(UniformFog, CloudyFog);

	return CloudyFog + UniformFog + RainFog;
}


vec4 getVolumetricRays(
	vec3 fragpos,
	float dither,
	vec3 AmbientColor
){
	//project pixel position into projected shadowmap space
	vec3 wpos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
	vec3 fragposition = mat3(shadowModelView) * wpos + shadowModelView[3].xyz;
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;

	//project view origin into projected shadowmap space
	vec3 start = toShadowSpaceProjected(vec3(0.));

	//rayvector into projected shadow map space
	//we can use a projected vector because its orthographic projection
	//however we still have to send it to curved shadow map space every step
	vec3 dV = fragposition-start;
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	float maxLength = min(length(dVWorld),far)/length(dVWorld);
	dV *= maxLength;
	dVWorld *= maxLength;

	//apply dither
	vec3 progress = start.xyz;

	vec3 vL = vec3(0.);

	float SdotV = dot(sunVec,normalize(fragpos))*lightCol.a;
	float dL = length(dVWorld);

	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
	float mie = phaseg(SdotV,0.7)*5.0 + 1.0;
	float rayL = phaseRayleigh(SdotV);

	
	// Makes fog more white idk how to simulate it correctly
	vec3 sunColor = lightCol.rgb / 80.0;
	vec3 skyCol0 = AmbientColor / 150. * 5. ; // * max(abs(WsunVec.y)/150.0,0.);

	vec3 lightningColor =  vec3(Lightning_R,Lightning_G,Lightning_B) * 25.0 * lightningFlash * max(eyeBrightnessSmooth.y,0)/240.;
	#ifdef ReflectedFog
		lightningColor *= 0.01;
	#endif
	
	vec3 np3 = normVec(wpos);
	float ambfogfade =  clamp(exp(np3.y* 2 - 2),0.0,1.0) * 4 ;
	skyCol0 += lightningColor * ambfogfade;


	#ifdef Biome_specific_environment
		// recolor change sun and sky color to some color, but make sure luminance is preserved.
		BiomeFogColor(sunColor);
		BiomeFogColor(skyCol0);
	#endif

	vec3 rC = vec3(fog_coefficientRayleighR*1e-6, fog_coefficientRayleighG*1e-5, fog_coefficientRayleighB*1e-5);
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);

	float mu = 1.0;
	float muS = mu;
	float absorbance = 1.0;
	float expFactor = 11.0;

	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;

	vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;

	float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2) ,0.0,1.0);
	for (int i=0;i<VL_SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither)/float(VL_SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(VL_SAMPLES)) * log(expFactor) / float(VL_SAMPLES)/(expFactor-1.0);
		progress = start.xyz + d*dV;
		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
		
		//project into biased shadowmap space
		float distortFactor = calcDistort(progress.xy);
		vec3 pos = vec3(progress.xy*distortFactor, progress.z);
		float densityVol = cloudVol(progressW);
		float sh = 1.0;
		
		
		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
			sh = shadow2D( shadow, pos).x;
		}

		#ifdef VL_CLOUDS_SHADOWS
			sh *= GetCloudShadow_VLFOG(progressW,WsunVec);
		#endif
		
		//Water droplets(fog)
		float density = densityVol*ATMOSPHERIC_DENSITY*mu*300.;

		//Just air
		vec2 airCoef = exp(-max(progressW.y-SEA_LEVEL,0.0)/vec2(8.0e3, 1.2e3)*vec2(6.,7.0)) * 24 * Haze_amount;

		//Pbr for air, yolo mix between mie and rayleigh for water droplets
		vec3 rL = rC*airCoef.x;
		vec3 m = (airCoef.y+density)*mC;

		vec3 DirectLight =  (sunColor*sh) * (rayL*rL+m*mie);
		vec3 AmbientLight =  skyCol0 * m;
		vec3 AtmosphericFog = skyCol0 * (rL+m)  ;

		// extra fog effects
		vec3 rainRays =   (sunColor*sh) * (rayL*phaseg(SdotV,0.5)) * clamp(pow(WsunVec.y,5)*2,0.0,1) * rainStrength * noPuddleAreas * RainFog_amount * 0.5; 
		vec3 CaveRays = (sunColor*sh)  * phaseg(SdotV,0.7) * 0.001 * (1.0 - lightleakfix);
 
		vec3 vL0 = (DirectLight + AmbientLight + AtmosphericFog + rainRays ) * lightleakfix  ;


		vL += (vL0 - vL0 * exp(-(rL+m)*dd*dL)) / ((rL+m)+0.00000001)*absorbance;
		absorbance *= dot(clamp(exp(-(rL+m)*dd*dL),0.0,1.0), vec3(0.333333));
	}
	return vec4(vL,absorbance);
}


/// really dumb lmao
vec4 InsideACloudFog(
	vec3 fragpos,
	vec2 Dither,
	vec3 SunColor,
	vec3 MoonColor,
	vec3 SkyColor
){
	float total_extinction = 1.0;
	vec3 color = vec3(0.0);

	//project pixel position into projected shadowmap space
	vec3 wpos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
	vec3 fragposition = mat3(shadowModelView) * wpos + shadowModelView[3].xyz;
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;

	//project view origin into projected shadowmap space
	vec3 start = toShadowSpaceProjected(vec3(0.));

	//rayvector into projected shadow map space
	//we can use a projected vector because its orthographic projection
	//however we still have to send it to curved shadow map space every step
	vec3 dV = fragposition-start;
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	// float maxLength = min(length(dVWorld),16*8)/length(dVWorld);
	float maxLength = min(length(dVWorld),far+16)/length(dVWorld);
	dV *= maxLength;
	dVWorld *= maxLength;
	float mult = length(dVWorld)/25;
	float dL = length(dVWorld);

	vec3 progress = start.xyz;
	vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;

	vec3 progress_view = vec3(0.0);
	float expFactor = 11.0;

	////// lighitng stuff 
	float shadowStep = 200.;
	vec3 dV_Sun = normalize(mat3(gbufferModelViewInverse)*sunVec)*shadowStep;

	float SdotV = dot(sunVec,normalize(fragpos));

	SkyColor *= clamp(abs(dV_Sun.y)/100.,0.75,1.0);
	SunColor =  SunColor * clamp(dV_Sun.y ,0.0,1.0);
	MoonColor *=  clamp(-dV_Sun.y,0.0,1.0);

	if(dV_Sun.y/shadowStep < -0.1) dV_Sun = -dV_Sun;



	float fogSdotV = dot(sunVec,normalize(fragpos))*lightCol.a;
	float fogmie = phaseg(fogSdotV,0.7)*5.0 + 1.0;

	// Makes fog more white idk how to simulate it correctly
	vec3 Fog_SkyCol = averageSkyCol/ 150. * 5. ; // * max(abs(WsunVec.y)/150.0,0.);
	vec3 Fog_SunCol = lightCol.rgb / 80.0;


	vec3 lightningColor =  vec3(Lightning_R,Lightning_G,Lightning_B) * 255.0 * lightningFlash * max(eyeBrightnessSmooth.y,0)/240.;
	#ifdef ReflectedFog
		lightningColor *= 0.01;
	#endif

	vec3 np3 = normVec(wpos);
	float ambfogfade =  clamp(exp(np3.y* 2 - 2),0.0,1.0) * 4 ;

	Fog_SkyCol += (lightningColor/10) * ambfogfade;
	


		float mieDay = phaseg(SdotV, 0.75) * 3.14;
		float mieDayMulti = phaseg(SdotV, 0.35) * 2;

		vec3 sunContribution = SunColor * mieDay;
		vec3 sunContributionMulti = SunColor * mieDayMulti ;

		float mieNight = (phaseg(-SdotV,0.8) + phaseg(-SdotV, 0.35)*4);
		vec3 moonContribution = MoonColor * mieNight;

		float timing = 1.0 - clamp(pow(abs(dV_Sun.y)/150.0,2.0),0.0,1.0);





	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
	float mie = phaseg(SdotV,0.7)*5.0 + 1.0;
	float rayL = phaseRayleigh(SdotV);

	#ifdef Biome_specific_environment
		// recolor change sun and sky color to some color, but make sure luminance is preserved.
		BiomeFogColor(Fog_SunCol);
		BiomeFogColor(Fog_SkyCol);
	#endif

	vec3 rC = vec3(fog_coefficientRayleighR*1e-6, fog_coefficientRayleighG*1e-5, fog_coefficientRayleighB*1e-5);
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);

	float mu = 1.0;
	float muS = mu;
	
	float Shadows_for_Fog = 0.0;
	float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2) ,0.0,1.0);

	for (int i=0;i<VL_SAMPLES;i++) {

		float d = (pow(expFactor, float(i+Dither.x)/float(VL_SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+Dither.x)/float(VL_SAMPLES)) * log(expFactor) / float(VL_SAMPLES)/(expFactor-1.0);
		progress = start.xyz + d*dV;
		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

		//project into biased shadowmap space
		float distortFactor = calcDistort(progress.xy);
		vec3 pos = vec3(progress.xy*distortFactor, progress.z);
		float sh = 1.0;

		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
			sh = shadow2D( shadow, pos).x;
		}

		Shadows_for_Fog = sh;

		#ifdef VL_CLOUDS_SHADOWS
			Shadows_for_Fog = sh * GetCloudShadow_VLFOG(progressW,WsunVec);
		#endif

		float densityVol = cloudVol(progressW);
		//Water droplets(fog)
		float density = densityVol*ATMOSPHERIC_DENSITY*mu*300.;

		//Just air
		vec2 airCoef = exp(-max(progressW.y-SEA_LEVEL,0.0)/vec2(8.0e3, 1.2e3)*vec2(6.,7.0)) * 24 * Haze_amount;

		//Pbr for air, yolo mix between mie and rayleigh for water droplets
		vec3 rL = rC*airCoef.x;
		vec3 m = (airCoef.y+density)*mC;

		vec3 DirectLight =  (Fog_SunCol*Shadows_for_Fog) * (rayL*rL+m*fogmie);
		vec3 AmbientLight =  Fog_SkyCol * m;
		vec3 AtmosphericFog = Fog_SkyCol * (rL+m)  ;

		// extra fog effects
		vec3 rainRays =   ((Fog_SunCol/5)*Shadows_for_Fog) * (rayL*phaseg(SdotV,0.5)) * clamp(pow(WsunVec.y,5)*2,0.0,1.0) * rainStrength * noPuddleAreas * RainFog_amount; 
		vec3 CaveRays = (Fog_SunCol*Shadows_for_Fog)  * phaseg(SdotV,0.7) * 0.001 * (1.0 - lightleakfix);

		vec3 vL0 = (DirectLight + AmbientLight + AtmosphericFog + rainRays ) * lightleakfix ;

		color += (vL0 - vL0 * exp(-(rL+m)*dd*dL)) / ((rL+m)+0.00000001)*total_extinction;
		total_extinction *= dot(clamp(exp(-(rL+m)*dd*dL),0.0,1.0), vec3(0.333333));


		
			progress_view = progressW;
			float cumulus = GetCumulusDensity(progress_view, 1);

			float alteredDensity = Cumulus_density * clamp(exp( (progress_view.y - (MaxCumulusHeight - 75)) / 9.0	 ),0.0,1.0);

			if(cumulus > 1e-5){
				float muE =	cumulus*alteredDensity;

				float Sunlight = 0.0;
				float MoonLight = 0.0;

				for (int j=0; j < 3; j++){

					vec3 shadowSamplePos = progress_view + (dV_Sun * 0.15) * (1 + Dither.y/2 + j);

					float shadow = GetCumulusDensity(shadowSamplePos, 0) * Cumulus_density;

					Sunlight += shadow / (1 + j);
					MoonLight += shadow;
				}

				Sunlight  += (1-sh) * 100.;
				MoonLight += (1-sh) * 100.;

				#ifdef Altostratus
					// cast a shadow from higher clouds onto lower clouds
					vec3 HighAlt_shadowPos = progress_view + dV_Sun/abs(dV_Sun.y) * max(AltostratusHeight - progress_view.y,0.0);
					float HighAlt_shadow = GetAltostratusDensity(HighAlt_shadowPos);
					Sunlight += HighAlt_shadow;
				#endif

				float ambientlightshadow = 1.0 - clamp(exp((progress_view.y - (MaxCumulusHeight - 50)) / 100.0),0.0,1.0) ;
				vec3 S = Cloud_lighting(muE, cumulus*Cumulus_density, Sunlight, MoonLight, SkyColor, sunContribution, sunContributionMulti, moonContribution, ambientlightshadow, 0, progress_view, timing);
				
				S += lightningColor * exp((1.0-cumulus) * -5) * ambientlightshadow;

				vec3 Sint = (S - S * exp(-mult*muE)) / muE;
				color += max(muE*Sint*total_extinction,0.0);
				total_extinction *= max(exp(-mult*muE),0.0);

			}
		if (total_extinction < 1e-5) break;
	}
	return vec4(color, total_extinction);
}