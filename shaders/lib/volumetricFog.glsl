float phaseRayleigh(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) /acos(-1.0);
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

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

	float CloudyFog = max((fog_shape*1.2 - fog_eroded*0.2) - 0.75,0.0) ;

	float UniformFog = exp2( -max((pos.y - SEA_LEVEL) / 25.,0.0));
	
	float RainFog = max(fog_shape*10. - 7.,0.5) * exp2( -max((pos.y - SEA_LEVEL) / 25.,0.0)) * 5. * rainStrength * RainFog_amount;
	
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
	vec3 skyCol0 = AmbientColor / 150. * 5.; // * max(abs(WsunVec.y)/150.0,0.);

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
			sh *= GetCloudShadow_VLFOG(progressW);
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
		vec3 rainRays =   (sunColor*sh) * (rayL*phaseg(SdotV,0.5)) * clamp(pow(WsunVec.y,5)*2,0.0,1) * rainStrength * RainFog_amount; 
		vec3 CaveRays = (sunColor*sh)  * phaseg(SdotV,0.7) * 0.001 * (1.0 - max(eyeBrightnessSmooth.y,0)/240.);
 
		vec3 vL0 = (DirectLight + AmbientLight + AtmosphericFog + rainRays) * max(eyeBrightnessSmooth.y,0)/240. + CaveRays ;

		vL += (vL0 - vL0 * exp(-(rL+m)*dd*dL)) / ((rL+m)+0.00000001)*absorbance;
		absorbance *= dot(clamp(exp(-(rL+m)*dd*dL),0.0,1.0), vec3(0.333333));
	}
	return vec4(vL,absorbance);
}