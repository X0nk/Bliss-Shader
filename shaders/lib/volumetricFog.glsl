
float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float phaseRayleigh(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) /acos(-1.0);
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}


// #define TIMEOFDAYFOG
// #include "/lib/climate_settings.glsl"
	// uniform int worldTime;

	// void TimeOfDayFog( inout float Uniform, inout float Cloudy) {
	
	//     float Time = (worldTime%24000)*1.0; 

	// 	// set schedules for fog to appear at specific ranges of time in the day.
	// 	float Morning = clamp((Time-22000)/2000,0,1) + clamp((2000-Time)/2000,0,1);
	// 	float Noon 	  = clamp(Time/2000,0,1) * clamp((12000-Time)/2000,0,1);
	// 	float Evening = clamp((Time-10000)/2000,0,1) * clamp((14000-Time)/2000,0,1) ;
	// 	float Night   = clamp((Time-12000)/2000,0,1) * clamp((23000-Time)/2000,0,1) ;

	// 	vec4 UniformDensity = vec4(0,	55,	0,	0);
	// 	vec4 CloudyDensity =  vec4(0,	0,	0,	0);


	// 	Uniform *= Morning*UniformDensity.r + Noon*UniformDensity.g + Evening*UniformDensity.b + Night*UniformDensity.a;
	// 	Cloudy *= Morning*CloudyDensity.r + Noon*CloudyDensity.g + Evening*CloudyDensity.b + Night*CloudyDensity.a;
	// }

float cloudVol(in vec3 pos){

	vec3 samplePos = pos*vec3(1.0,1./24.,1.0);
	vec3 samplePos2 = pos*vec3(1.0,1./48.,1.0);


	float mult = exp2( -max((pos.y - SEA_LEVEL) / 35.,0.0));

	float fog_shape = 1-densityAtPos(samplePos * 24.0);
	float fog_eroded = densityAtPos(	samplePos2 * 150.0);

	float CloudyFog = max(	(fog_shape*2.0 - fog_eroded*0.5) - 1.4, 0.0) * mult;
	float UniformFog = exp2( -max((pos.y - SEA_LEVEL) / 25.,0.0));
	
	float RainFog = max(fog_shape*10. - 7.,0.5) * exp2( -max((pos.y - SEA_LEVEL) / 25.,0.0)) * 5. * rainStrength;
	
	TimeOfDayFog(UniformFog, CloudyFog);

	return RainFog + CloudyFog + UniformFog;
}

mat2x3 getVolumetricRays(
	float dither,
	vec3 fragpos
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
	vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;

	vec3 vL = vec3(0.);

	float SdotV = dot(sunVec,normalize(fragpos))*lightCol.a;
	float dL = length(dVWorld);

	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
	float mie = phaseg(SdotV,0.7)*5.0 + 1.0;
	float rayL = phaseRayleigh(SdotV);

	// Makes fog more white idk how to simulate it correctly
	vec3 sunColor = lightCol.rgb / 5.0;
	vec3 skyCol0 = (ambientUp / 5.0 * 5.); // * max(abs(WsunVec.y)/150.0,0.);

	vec3 rC = vec3(fog_coefficientRayleighR*1e-6, fog_coefficientRayleighG*1e-5, fog_coefficientRayleighB*1e-5);
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);

	float mu = 1.0;
	float muS = mu;
	vec3 absorbance = vec3(1.0);
	float expFactor = 11.0;
	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;

	float cloudShadow = 1.0;

	for (int i=0;i<VL_SAMPLES2;i++) {
		float d = (pow(expFactor, float(i+dither)/float(VL_SAMPLES2))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(VL_SAMPLES2)) * log(expFactor) / float(VL_SAMPLES2)/(expFactor-1.0);
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
		#ifdef VOLUMETRIC_CLOUDS
		#ifdef CLOUDS_SHADOWS
		#ifdef VL_CLOUDS_SHADOWS
			float max_height = clamp(400.0 - progressW.y, 0.0,1.0); // so it doesnt go beyond the height of the clouds
			vec3 campos = (progressW)-319;
			// get cloud position
			vec3 cloudPos = campos*Cloud_Size + WsunVec/abs(WsunVec.y) * (2250 - campos.y*Cloud_Size);
			// get the cloud density and apply it
			cloudShadow = getCloudDensity(cloudPos, 1);
			cloudShadow = exp(-cloudShadow*cloudDensity*200);
			cloudShadow *= max_height;
			// cloudShadow *= 1000; //debug 
		#endif
		#endif
		#endif

		//Water droplets(fog)
		float density = densityVol*ATMOSPHERIC_DENSITY*mu*300.;

		//Just air
		vec2 airCoef = exp(-max(progressW.y-SEA_LEVEL,0.0)/vec2(8.0e3, 1.2e3)*vec2(6.,7.0)) * 16;

		//Pbr for air, yolo mix between mie and rayleigh for water droplets
		vec3 rL = rC*airCoef.x;
		vec3 m = (airCoef.y+density)*mC;

		vec3 rainRays =   (sunColor*sh*cloudShadow) * (rayL*phaseg(SdotV,0.6)) * clamp(pow(WsunVec.y,5)*2,0.0,1) * rainStrength;

		vec3 DirectLight =  (sunColor*sh*cloudShadow) * (rayL*rL+m*mie);
		vec3 AmbientLight =  skyCol0 * m;
		
		vec3 AtmosphericFog = skyCol0 * (rL+m)  ;

		vec3 vL0 =  (DirectLight +AmbientLight+AtmosphericFog + rainRays) * max(eyeBrightnessSmooth.y,0)/240.;
		
		#ifdef Biome_specific_environment
			BiomeFogColor(vL0);
		#endif
		vL += (vL0 - vL0 * exp(-(rL+m)*dd*dL)) / ((rL+m)+0.00000001)*absorbance;
		absorbance *= clamp(exp(-(rL+m)*dd*dL),0.0,1.0);

	}
	return mat2x3(vL,absorbance);
}