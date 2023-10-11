vec4 GetVolumetricFog(
	vec3 viewPos,
	float dither,
	float dither2
){
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
	float expFactor = 11.0;
	for (int i=0;i<SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither)/float(SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(SAMPLES)) * log(expFactor) / float(SAMPLES)/(expFactor-1.0);
		vec3 progress = start.xyz + d*dV;
		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

		// do main lighting
		float Density = 0.05;


		Density *= pow(normalize(-wpos).y*0.5+0.5,3.0);


		// vec3 vL0 = vec3(0.8,0.5,1) * 0.05 * pow(normalize(wpos).y*0.5+0.5,2.0)*2.0;
		vec3 vL0 = vec3(0.8,1.0,0.5) * 0.05 ;

		vL += (vL0 - vL0*exp(-Density*dd*dL)) * absorbance;

        absorbance *= exp(-(Density)*dd*dL);

		if (absorbance < 1e-5) break;
	}
	return vec4(vL, absorbance);
}