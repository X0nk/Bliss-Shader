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

	vec3 samplePos = pos*vec3(1.0,1./48.,1.0);


    float finalfog = exp(max(100-pos.y,0.0) / -15) ;

	float floorfog = pow(exp(max(pos.y-30,0.0) / -3.0),2);


    float wind = pow(max(pos.y - 30,0.0) / 15.0,2.1);

	float noise_1 = pow(1-texture2D(noisetex, samplePos.xz/256.0 + wind/200).b,2.0);
	float noise_2 = pow(densityAtPosFog(samplePos*256 - frameTimeCounter*10 + wind*10),1) * 0.75 +0.25;

	float rooffog = exp(max(100-pos.y,0.0) / -5);
	finalfog = max(finalfog - noise_1*noise_2 - rooffog, max(floorfog -noise_2*0.2,0.0));
    
	return finalfog;
}

vec4 GetVolumetricFog(
	vec3 fragpos,
	float dither
){
	int SAMPLES = 16;
	vec3 vL = vec3(0.0);
	float absorbance = 1.0;

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

	float dL = length(dVWorld);
	vec3 fogcolor = (gl_Fog.color.rgb / max(dot(gl_Fog.color.rgb,vec3(0.3333)),0.01)) ;

	float expFactor = 11.0;
	for (int i=0;i<SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither)/float(SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(SAMPLES)) * log(expFactor) / float(SAMPLES)/(expFactor-1.0);
		vec3 progress = start.xyz + d*dV;
		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
	
		float Density = cloudVol(progressW);
		Density *= exp(max(progressW.y-80,0.0) / -5);
		
		float Air = 0.01;

		// vec3 vL0 = vec3(TORCH_R,TORCH_G,TORCH_B) * exp(max(progressW.y-30,0.0) / -10.0);
		vec3 vL0 = vec3(TORCH_R,TORCH_G,TORCH_B) * exp(Density * -50) * exp(max(progressW.y-30,0.0) / -10.0)*25   ;

		vL0 += (vec3(0.5,0.5,1.0)/ 5) * exp(max(100-progressW.y,0.0) / -15.0) * (1.0 - exp(Density * -1));

		vec3 vL1 = fogcolor / 20.0;

		vL += (vL0 - vL0*exp(-Density*dd*dL)) * absorbance;
		vL += (vL1 - vL1*exp(-Air*dd*dL)) * absorbance;

        absorbance *= exp(-(Density+Air)*dd*dL);
	}
	return vec4(vL,absorbance);
}