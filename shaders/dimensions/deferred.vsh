#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

flat varying vec2 tempOffsets;
flat varying float exposure;
flat varying float avgBrightness;
flat varying float rodExposure;
flat varying float avgL2;
flat varying float centerDepth;

uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec2 texelSize;
uniform float sunElevation;
uniform float eyeAltitude;
uniform float near;
uniform float far;
uniform float frameTime;
uniform int frameCounter;
uniform float rainStrength;

// uniform int worldTime;
vec3 sunVec = normalize(mat3(gbufferModelViewInverse) *sunPosition);

#include "/lib/sky_gradient.glsl"
#include "/lib/util.glsl"
#include "/lib/ROBOBO_sky.glsl"

float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}

//Low discrepancy 2D sequence, integration error is as low as sobol but easier to compute : http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}
float tanh(float x){
	return (exp(x) - exp(-x))/(exp(x) + exp(-x));
}
float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}

uniform float nightVision;


void main() {

	gl_Position = ftransform()*0.5+0.5;
	gl_Position.xy = gl_Position.xy*vec2(18.+258*2,258.)*texelSize;
	gl_Position.xy = gl_Position.xy*2.-1.0;

//////////////////////////////
/// --- EXPOSURE STUFF --- ///
//////////////////////////////

	float avgLuma = 0.0;
	float m2 = 0.0;
	int n=100;
	vec2 clampedRes = max(1.0/texelSize,vec2(1920.0,1080.));
	float avgExp = 0.0;
	float avgB = 0.0;
	vec2 resScale = vec2(1920.,1080.)/clampedRes;
	const int maxITexp = 50;
	float w = 0.0;
	for (int i = 0; i < maxITexp; i++){
			vec2 ij = R2_samples((frameCounter%2000)*maxITexp+i);
			vec2 tc = 0.5 + (ij-0.5) * 0.7;
			vec3 sp = texture2D(colortex6,tc/16. * resScale+vec2(0.375*resScale.x+4.5*texelSize.x,.0)).rgb;
			avgExp += log(luma(sp));
			avgB += log(min(dot(sp,vec3(0.07,0.22,0.71)),8e-2));
	}

	avgExp = exp(avgExp/maxITexp);
	avgB = exp(avgB/maxITexp);

	avgBrightness = clamp(mix(avgExp,texelFetch2D(colortex4,ivec2(10,37),0).g,0.95),0.00003051757,65000.0);

	float L = max(avgBrightness,1e-8);
	float keyVal = 1.03-2.0/(log(L*4000/150.*8./3.0+1.0)/log(10.0)+2.0);
	float expFunc = 0.5+0.5*tanh(log(L));
	float targetExposure = 0.18/log2(L*2.5+1.045)*0.62;

	avgL2 = clamp(mix(avgB,texelFetch2D(colortex4,ivec2(10,37),0).b,0.985),0.00003051757,65000.0);
	float targetrodExposure = max(0.012/log2(avgL2+1.002)-0.1,0.0)*1.2;


	exposure = max(targetExposure*EXPOSURE_MULTIPLIER, 0);
	float currCenterDepth = ld(texture2D(depthtex0, vec2(0.5)).r);
	centerDepth = mix(sqrt(texelFetch2D(colortex4,ivec2(14,37),0).g/65000.0), currCenterDepth, clamp(DoF_Adaptation_Speed*exp(-0.016/frameTime+1.0)/(6.0+currCenterDepth*far),0.0,1.0));
	centerDepth = centerDepth * centerDepth * 65000.0;

	rodExposure = targetrodExposure;

	#ifndef AUTO_EXPOSURE
	 exposure = Manual_exposure_value;
	 rodExposure = clamp(log(Manual_exposure_value*2.0+1.0)-0.1,0.0,2.0);
	#endif
}