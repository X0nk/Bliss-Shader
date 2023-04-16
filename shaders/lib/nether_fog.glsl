///////////////// POSITION
///////////////// POSITION
///////////////// POSITION

vec3 ManualLightPos = vec3(ORB_X, ORB_Y, ORB_Z);

vec3 lighting_pos =  vec3(0, -1, 0);

vec3 lightSource = normalize(lighting_pos);
vec3 viewspace_sunvec = mat3(gbufferModelView) * lightSource;
vec3 WsunVec = normalize(mat3(gbufferModelViewInverse) * viewspace_sunvec);



///////////////// COLOR
///////////////// COLOR
///////////////// COLOR
vec3 LightSourceColor(){

    vec3 Color = vec3(1.0,0.75,0.5);

    return Color;
}

///////////////// SHAPE
///////////////// SHAPE
///////////////// SHAPE
vec3 LightSourceShape(vec3 WorldPos){

    vec3 Shapes = vec3(0.0);
    vec3 Origin = WorldPos ;

    return Shapes;
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
	// vec3 samplePos2 = pos*vec3(1.0,1./48.,1.0);

	// float fog_shape =  1-densityAtPosFog(samplePos * 16.0);
	// float fog_eroded = 1-densityAtPosFog(samplePos2 * (200 + fog_shape*25));

    // float finalfog = clamp(	(fog_shape*2.0 - fog_eroded*0.3) - 1.5, 0.0, 1.0);

    float finalfog = 1-exp(max(samplePos.y - 60,0.0) / -1);
    

	return finalfog;
}

// float GetCloudShadow(vec3 WorldPos, vec3 LightPos, float noise){
//     float Shadow = 0.0;

// 	for (int i=0; i < 3; i++){

// 	    // vec3 shadowSamplePos = WorldPos - LightPos.y/abs(LightPos.y) * (0.25 + pow(i,0.75)*0.25); 
// 	    vec3 shadowSamplePos = WorldPos + LightPos * (i * 20);

// 	    float Cast = cloudVol(shadowSamplePos);
// 	    Shadow += Cast;
//     }

// 	return clamp(exp(-Shadow*30),0.0,1.0);
// }
//Mie phase function
// float phaseg(float x, float g){
//     float gg = g * g;
//     return (gg * -0.25 + 0.25) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5) /3.14;
// }

mat2x3 getVolumetricRays(float dither,vec3 fragpos,float dither2) {
    int SAMPLES = 16;
	//project pixel position into projected shadowmap space
	vec3 wpos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
	vec3 fragposition = mat3(shadowModelView) * wpos + shadowModelView[3].xyz;
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;


	//project view origin into projected shadowmap space
	vec3 start = vec3(0.0);

	//rayvector into projected shadow map space
	//we can use a projected vector because its orthographic projection
	//however we still have to send it to curved shadow map space every step
	vec3 dV = (fragposition-start);
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	float maxLength = min(length(dVWorld),32.0 * 12.0)/length(dVWorld);
	dV *= maxLength;
	dVWorld *= maxLength;

	//apply dither
	vec3 progress = start.xyz;
	vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;
	vec3 vL = vec3(0.);
	float dL = length(dVWorld);

	vec3 absorbance = vec3(1.0);
	float expFactor = 11.0;

	vec3 fogColor = gl_Fog.color.rgb;

	// float SdotV = dot(normalize(viewspace_sunvec), normalize(fragpos));
	// float OrbMie = phaseg(SdotV, 0.8);

	for (int i=0;i<SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither)/float(SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(SAMPLES)) * log(expFactor) / float(SAMPLES)/(expFactor-1.0);
		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

		float densityVol = cloudVol(progressW) ;
		float density = min(densityVol,0.1);
        float air = 0.005;

        /// THE OOOOOOOOOOOOOOOOOOOOOORB
        vec3 LightColor = LightSourceColor();
        
        // vec3 LightPos = LightSourcePosition(progressW, cameraPosition);
        // float OrbMie = exp(length(LightPos) * -0.03) * 64.0;
        
		float OrbMie = clamp(exp((progressW.y - 30) / -10.) * 5,0,1);

        LightColor *= OrbMie;

		float CastLight = 0.0;
		for (int j=0; j < 5; j++){
	        vec3 shadowSamplePos = progressW + WsunVec * (0.5 + j * 5); 
	        // vec3 shadowSamplePos = progressW - LightPos.y * (j*30); 
			
			float densityVol2 = cloudVol(shadowSamplePos);
			CastLight += densityVol2;
		}

		vec3 CastedLight = LightColor * exp(CastLight * -15);

        // #ifdef THE_ORB
		//     density += clamp((1.0 - length(LightPos) / 10.0) * 10 ,0.0,1.0) ;
        // #endif
        
		vec3 AmbientLight =  fogColor* exp(density * -25);

		vec3 vL0 = AmbientLight;
        
		vec3 vL1 =  vec3(1.0,0.75,0.5) * 0.1;

		vL += (vL0 - vL0*exp(-density*dd*dL)) * absorbance;
		vL += (vL1 - vL1*exp(-air*dd*dL)) * absorbance;

        absorbance *= exp(-(density+air)*dd*dL);
	}
	return mat2x3(vL,absorbance);
}