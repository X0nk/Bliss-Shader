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
	float Output = 0.0;
	vec3 samplePos = pos*vec3(1.0,1./48.,1.0);


    float Wind = pow(max(pos.y-30,0.0) / 15.0,2.1);

	float Plumes = texture2D(noisetex, (samplePos.xz + Wind)/256.0).b;
	float floorPlumes = clamp(0.3 - exp(Plumes * -6),0,1);
	Plumes *= Plumes;

	float Erosion = densityAtPosFog(samplePos * 400	- frameTimeCounter*10 - Wind*10) *0.7+0.3 ;

	// float maxdist = clamp((12 * 8) - length(pos - cameraPosition),0.0,1.0);

    float RoofToFloorDensityFalloff = exp(max(100-pos.y,0.0) / -15);
	float FloorDensityFalloff = pow(exp(max(pos.y-31,0.0) / -3.0),2);
	float RoofDensityFalloff = exp(max(120-pos.y,0.0) / -10);

	Output = max((RoofToFloorDensityFalloff - Plumes * (1.0-Erosion)) * 2.0,	clamp((FloorDensityFalloff - floorPlumes*0.5) * Erosion ,0.0,1.0) );
    
	return Output;
}

vec4 GetVolumetricFog(
	vec3 viewPos,
	float dither,
	float dither2
){
	
	#ifndef TOGGLE_VL_FOG
		return vec4(0.0,0.0,0.0,1.0);
	#endif
	
	int SAMPLES = 16;
	vec3 vL = vec3(0.0);
	float absorbance = 1.0;

  	//project pixel position into projected shadowmap space
	vec3 wpos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
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

	float dL = length(dVWorld);
	vec3 fogcolor = (gl_Fog.color.rgb / max(dot(gl_Fog.color.rgb,vec3(0.3333)),0.05)) ;

	float expFactor = 11.0;
	for (int i=0;i<SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither)/float(SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(SAMPLES)) * log(expFactor) / float(SAMPLES)/(expFactor-1.0);
		vec3 progress = start.xyz + d*dV;
		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

		// do main lighting
		float Density = cloudVol(progressW) * pow(exp(max(progressW.y-65,0.0) / -15),2);

		float clearArea =  1.0-min(max(1.0 - length(progressW - cameraPosition) / 100,0.0),1.0);
		Density = min(Density * clearArea, NETHER_PLUME_DENSITY);
		
		float fireLight = cloudVol(progressW - vec3(0,1,0)) * clamp(exp(max(30 - progressW.y,0.0) / -10.0),0,1);

		vec3 vL0 = vec3(1.0,0.4,0.2) * exp(fireLight * -25) * exp(max(progressW.y-30,0.0) / -10) * 25;
		vL0 += vec3(0.8,0.8,1.0) * (1.0 - exp(Density * -1)) / 10 ;

		
		// do background fog lighting	
		float AirDensity = 0.01;
		vec3 vL1 = fogcolor / 20.0;

		vL += (vL1 - vL1*exp(-AirDensity*dd*dL)) * absorbance;
		vL += (vL0 - vL0*exp(-Density*dd*dL)) * absorbance;

        absorbance *= exp(-(Density+AirDensity)*dd*dL);

		if (absorbance < 1e-5) break;
	}
	// return vec4(0.0,0.0,0.0,1.0);
	return vec4(vL, absorbance);
}