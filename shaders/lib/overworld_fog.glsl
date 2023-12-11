

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

	float testfogshapes = exp(sqrt(max(pos.y - fogYstart - 5,0.0)) / -1) * 50;


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

/*
/// experimental functions to render clouds and fog in 2 passes

float cloudCoverage(in vec3 pos, float minHeight, float maxHeight){
	float FinalCloudCoverage = 0.0;
	vec3 playerPos = pos - cameraPosition;
	vec3 samplePos =  pos*vec3(1.0,1./48.,1.0)/4;

	// minHeight -= curvature; maxHeight -= curvature;

	float thingy = pow(1.0-clamp(1.0-length(playerPos)/2000,0,1),2) * 2.0;

	float CloudLarge = texture2D(noisetex, (samplePos.xz+ cloud_movement)/5000.0).b;
	float CloudSmall = texture2D(noisetex, (samplePos.xz- cloud_movement)/500.0).r;

	float coverage = abs(CloudLarge*2.0 - 1.2)*0.5 - (1.0-CloudSmall);


	/////// FIRST LAYER
	float layer0 = min(min(coverage + max(Cumulus_coverage,thingy), clamp(maxHeight - pos.y,0,1)), 1.0 - clamp(minHeight - pos.y,0,1));
	
	float Topshape = max(pos.y - (maxHeight - 75),0.0) / 200.0;
	Topshape += max(pos.y - (maxHeight - 10),0.0) / 50.0;

	float Baseshape = max(minHeight + 12.5 - pos.y, 0.0) / 50.0;
	
	FinalCloudCoverage += max(layer0 - Topshape - Baseshape,0.0);

	float erosion = 1.0 - densityAtPos(samplePos * 200);
	float noise = erosion * (1.0-FinalCloudCoverage) ;
	FinalCloudCoverage = max(FinalCloudCoverage - noise*noise*0.5, 0.0);
	
	return FinalCloudCoverage;
}

vec4 renderVolumetrics(
	vec3 viewPosition,
	vec2 dither,
	vec3 directLightColor,
	vec3 skyLightColor
){
	int SAMPLES = 30;
	vec3 color = vec3(0.0);
	float absorbance = 1.0;

	vec3 wpos = mat3(gbufferModelViewInverse) * viewPosition + gbufferModelViewInverse[3].xyz;
	vec3 fragposition = mat3(shadowModelView) * wpos + shadowModelView[3].xyz;
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;

	//////////////////////////////////////////
	////// lighting stuff 
	//////////////////////////////////////////

	float shadowStep = 200.0;
	vec3 dV_Sun = WsunVec*shadowStep;
	float SdotV = dot(mat3(gbufferModelView)*WsunVec,normalize(viewPosition));
	// if(dV_Sun.y/shadowStep < -0.1) dV_Sun = -dV_Sun;
	
	float mieDay = phaseg(SdotV, 0.75);
	float mieDayMulti = (phaseg(SdotV, 0.35) + phaseg(-SdotV, 0.35) * 0.5) ;

	vec3 sunScattering = directLightColor * mieDay * 3.14;
	vec3 sunMultiScattering = directLightColor * mieDayMulti * 4.0;

	//////////////////////////////////////////
	////// raymarching stuff 
	//////////////////////////////////////////


	//project view origin into projected shadowmap space
	vec3 start = toShadowSpaceProjected(vec3(0.0));

	vec3 dV = fragposition - start;
	// vec3 dVWorld = (wpos - gbufferModelViewInverse[3].xyz);
	vec3 dVWorld = (wpos - gbufferModelViewInverse[3].xyz);

	// float maxLength = min(length(dVWorld), far)/length(dVWorld);
	float maxLength = 1.0;
	dV *= maxLength;
	dVWorld *= maxLength;

	float dL = length(dVWorld);
	
	float minCloudHeight = Cumulus_height;
	float maxCloudHeight = minCloudHeight + 100;


	float expFactor = 11.0;
	vec3 progress = start.xyz;

	vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition;
	
	
	float heightRelativeToClouds = clamp(1.0 - max(eyeAltitude - (Cumulus_height),0.0) / 100.0 ,0.0,1.0);
	
	for (int i=0; i < SAMPLES; i++) {
	
		float d = (pow(expFactor, float(i+dither.x)/float(SAMPLES))/expFactor - 1.0/expFactor)/(1.0-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither.x)/float(SAMPLES)) * log(expFactor) / float(SAMPLES)/(expFactor-1.0);
		
		progress = start.xyz + d*dV;
		
		// progressW = gbufferModelViewInverse[3].xyz + cameraPosition + d*dVWorld;
		
		progressW = gbufferModelViewInverse[3].xyz + cameraPosition + d*dVWorld;


		float curvature = pow(length(progressW-cameraPosition)/200.0,2.0) * heightRelativeToClouds ;
		minCloudHeight -= curvature; maxCloudHeight -= curvature;

		//project into biased shadowmap space
		float distortFactor = calcDistort(progress.xy);
		vec3 pos = vec3(progress.xy*distortFactor, progress.z);

		float sh = 1.0;
		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
			sh = shadow2D(shadow, pos).x;
		}

		float cloud = cloudCoverage(progressW, minCloudHeight, maxCloudHeight);

		float UniformFog =  clamp(1.0 - (progressW.y-minCloudHeight-100) / 200,0.0,1.0);

		float density = max(cloud, (UniformFog*UniformFog) * 0.00);

		float horizonfalloff = exp(-(1.0-clamp(normalize(progressW-vec3(cameraPosition.x,0.0,cameraPosition.x)).y+1.0,0,1)));
		sunScattering *= horizonfalloff;
		sunMultiScattering *= horizonfalloff;


		// if(density > 1e-5){
			float muE = density * 0.5;

			float sunLight = 0.0;


			for (int j=0; j < 3; j++){
				vec3 shadowSamplePos = progressW + dV_Sun * (0.1 + j * (0.1 + dither.y*0.05));
				float shadow = cloudCoverage(shadowSamplePos, minCloudHeight, maxCloudHeight) * 0.5;

				sunLight += shadow;
			}

			sunLight += 2*cloudCoverage(progressW + dV_Sun/abs(dV_Sun.y) * max(minCloudHeight+20 - progressW.y,0.0), minCloudHeight, maxCloudHeight) * exp(-10*cloud);
			vec3 lighting = skyLightColor + (sunScattering*exp(-5 * sunLight) + sunMultiScattering*exp(-3 * sunLight)) * sh;

			color += max(lighting - lighting*exp(-muE*dd*dL),0.0) * absorbance;
			absorbance *= max(exp(-muE*dd*dL),0.0);
			
			if (absorbance < 1e-5) break;
	}
	return vec4(color, absorbance);
}
*/