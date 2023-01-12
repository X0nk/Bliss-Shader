#version 120
#extension GL_EXT_gpu_shader4 : enable
#define EXPOSURE_MULTIPLIER 1.0 //[0.25 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.1 1.2 1.3 1.4 1.5 2.0 3.0 4.0]
#define AUTO_EXPOSURE		//Highly recommended to keep it on unless you want to take screenshots
#define Manual_exposure_value 1.0			// [0.000553 0.000581 0.000611 0.000642 0.000675 0.000710 0.000746 0.000784 0.000825 0.000867 0.000911 0.000958 0.001007 0.001059 0.001113 0.001170 0.001230 0.001294 0.001360 0.001430 0.001503 0.001580 0.001661 0.001746 0.001836 0.001930 0.002029 0.002133 0.002242 0.002357 0.002478 0.002605 0.002739 0.002879 0.003027 0.003182 0.003345 0.003517 0.003697 0.003887 0.004086 0.004296 0.004516 0.004748 0.004991 0.005247 0.005516 0.005799 0.006096 0.006409 0.006737 0.007083 0.007446 0.007828 0.008229 0.008651 0.009095 0.009561 0.010051 0.010567 0.011108 0.011678 0.012277 0.012906 0.013568 0.014264 0.014995 0.015764 0.016572 0.017422 0.018315 0.019254 0.020241 0.021279 0.022370 0.023517 0.024723 0.025991 0.027323 0.028724 0.030197 0.031745 0.033373 0.035084 0.036883 0.038774 0.040762 0.042852 0.045049 0.047358 0.049787 0.052339 0.055023 0.057844 0.060810 0.063927 0.067205 0.070651 0.074273 0.078081 0.082084 0.086293 0.090717 0.095369 0.100258 0.105399 0.110803 0.116484 0.122456 0.128734 0.135335 0.142274 0.149568 0.157237 0.165298 0.173773 0.182683 0.192049 0.201896 0.212247 0.223130 0.234570 0.246596 0.259240 0.272531 0.286504 0.301194 0.316636 0.332871 0.349937 0.367879 0.386741 0.406569 0.427414 0.449328 0.472366 0.496585 0.522045 0.548811 0.576949 0.606530 0.637628 0.670320 0.704688 0.740818 0.778800 0.818730 0.860707 0.904837 0.951229 1.0 1.051271 1.105170 1.161834 1.221402 1.284025 1.349858 1.419067 1.491824 1.568312 1.648721 1.733253 1.822118 1.915540 2.013752 2.117000 2.225540 2.339646 2.459603 2.585709 2.718281 2.857651 3.004166 3.158192 3.320116 3.490342 3.669296 3.857425 4.055199 4.263114 4.481689 4.711470 4.953032 5.206979 5.473947 5.754602 6.049647 6.359819 6.685894 7.028687 7.389056 7.767901 8.166169 8.584858 9.025013 9.487735 9.974182 10.48556 11.02317 11.58834 12.18249 ]
#define Exposure_Speed 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 4.0 5.0]
#define DoF_Adaptation_Speed 1.00 // [0.20 0.21 0.23 0.24 0.25 0.27 0.29 0.30 0.32 0.34 0.36 0.39 0.41 0.43 0.46 0.49 0.52 0.55 0.59 0.62 0.66 0.70 0.74 0.79 0.84 0.89 0.94 1.00 1.06 1.13 1.20 1.27 1.35 1.43 1.52 1.61 1.71 1.82 1.93 2.05 2.18 2.31 2.45 2.60 2.76 2.93 3.11 3.30 3.51 3.72 3.95 4.19 4.45 4.73 5.02 5.33 5.65 6.00]
#define CLOUDS_SHADOWS
#define BASE_FOG_AMOUNT 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0 10.0 20.0 30.0 50.0 100.0 150.0 200.0]  Base fog amount amount (does not change the "cloudy" fog)
#define CLOUDY_FOG_AMOUNT 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0]
#define FOG_TOD_MULTIPLIER 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0] //Influence of time of day on fog amount
#define FOG_RAIN_MULTIPLIER 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0] //Influence of rain on fog amount
#include "lib/res_params.glsl"
flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;
flat varying vec3 zenithColor;
flat varying vec3 sunColor;
flat varying vec3 sunColorCloud;
flat varying vec3 moonColor;
flat varying vec3 moonColorCloud;
flat varying vec3 lightSourceColor;
flat varying vec3 avgSky;
flat varying vec2 tempOffsets;
flat varying float exposure;
flat varying float avgBrightness;
flat varying float exposureF;
flat varying float rodExposure;
flat varying float fogAmount;
flat varying float VFAmount;
flat varying float avgL2;
flat varying float centerDepth;

uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;


uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec2 texelSize;
uniform float rainStrength;
uniform float sunElevation;
uniform float nightVision;
uniform float near;
uniform float far;
uniform float frameTime;
uniform float eyeAltitude;
uniform int frameCounter;
uniform int worldTime;
vec3 sunVec = normalize(mat3(gbufferModelViewInverse) *sunPosition);



#include "lib/sky_gradient.glsl"
#include "/lib/util.glsl"
#include "/lib/ROBOBO_sky.glsl"


vec3 rodSample(vec2 Xi)
{
	float r = sqrt(1.0f - Xi.x*Xi.y);
    float phi = 2 * 3.14159265359 * Xi.y;

    return normalize(vec3(cos(phi) * r, sin(phi) * r, Xi.x)).xzy;
}
vec3 cosineHemisphereSample(vec2 Xi)
{
    float r = sqrt(Xi.x);
    float theta = 2.0 * 3.14159265359 * Xi.y;

    float x = r * cos(theta);
    float y = r * sin(theta);

    return vec3(x, y, sqrt(clamp(1.0 - Xi.x,0.,1.)));
}

float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}

vec2 tapLocation(int sampleNumber,int nb, float nbRot,float jitter)
{
    float alpha = float(sampleNumber+jitter)/nb;
    float angle = (jitter+alpha) * (nbRot * 6.28);

    float ssR = alpha;
    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*ssR;
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
void main() {

	gl_Position = ftransform()*0.5+0.5;
	gl_Position.xy = gl_Position.xy*vec2(18.+258*2,258.)*texelSize;
	gl_Position.xy = gl_Position.xy*2.-1.0;

	tempOffsets = R2_samples(frameCounter%10000);

	ambientUp = vec3(0.0);
	ambientDown = vec3(0.0);
	ambientLeft = vec3(0.0);
	ambientRight = vec3(0.0);
	ambientB = vec3(0.0);
	ambientF = vec3(0.0);
	avgSky = vec3(0.0);
	//Integrate sky light for each block side
	int maxIT = 20;
	for (int i = 0; i < maxIT; i++) {
			vec2 ij = R2_samples((frameCounter%1000)*maxIT+i);
			vec3 pos = normalize(rodSample(ij));


			vec3 samplee = 1.72*skyFromTex(pos,colortex4).rgb/maxIT/150.;
			avgSky += samplee/1.72;
			ambientUp += samplee*(pos.y+abs(pos.x)/7.+abs(pos.z)/7.);
			ambientLeft += samplee*(clamp(-pos.x,0.0,1.0)+clamp(pos.y/7.,0.0,1.0)+abs(pos.z)/7.);
			ambientRight += samplee*(clamp(pos.x,0.0,1.0)+clamp(pos.y/7.,0.0,1.0)+abs(pos.z)/7.);
			ambientB += samplee*(clamp(pos.z,0.0,1.0)+abs(pos.x)/7.+clamp(pos.y/7.,0.0,1.0));
			ambientF += samplee*(clamp(-pos.z,0.0,1.0)+abs(pos.x)/7.+clamp(pos.y/7.,0.0,1.0));
			ambientDown += samplee*(clamp(pos.y/6.,0.0,1.0)+abs(pos.x)/7.+abs(pos.z)/7.);

			/*
			ambientUp += samplee*(pos.y);
			ambientLeft += samplee*(clamp(-pos.x,0.0,1.0));
			ambientRight += samplee*(clamp(pos.x,0.0,1.0));
			ambientB += samplee*(clamp(pos.z,0.0,1.0));
			ambientF += samplee*(clamp(-pos.z,0.0,1.0));
			ambientDown += samplee*(clamp(pos.y/6.,0.0,1.0))*0;
			*/

	}


	vec2 planetSphere = vec2(0.0);
	vec3 sky = vec3(0.0);
	vec3 skyAbsorb = vec3(0.0);

	float sunVis = clamp(sunElevation,0.0,0.05)/0.05*clamp(sunElevation,0.0,0.05)/0.05;
	float moonVis = clamp(-sunElevation,0.0,0.05)/0.05*clamp(-sunElevation,0.0,0.05)/0.05;

	zenithColor = calculateAtmosphere(vec3(0.0), vec3(0.0,1.0,0.0), vec3(0.0,1.0,0.0), sunVec, -sunVec, planetSphere, skyAbsorb, 25,tempOffsets.x);
	skyAbsorb = vec3(0.0);
	vec3 absorb = vec3(0.0);
	sunColor = calculateAtmosphere(vec3(0.0), sunVec, vec3(0.0,1.0,0.0), sunVec, -sunVec, planetSphere, skyAbsorb, 25,0.0);
	sunColor = sunColorBase/4000. * skyAbsorb;

	skyAbsorb = vec3(1.0);
	float dSun = 0.03;
	vec3 modSunVec = sunVec*(1.0-dSun)+vec3(0.0,dSun,0.0);
	vec3 modSunVec2 = sunVec*(1.0-dSun)+vec3(0.0,dSun,0.0);
	if (modSunVec2.y > modSunVec.y) modSunVec = modSunVec2;
	sunColorCloud = calculateAtmosphere(vec3(0.0), modSunVec, vec3(0.0,1.0,0.0), sunVec, -sunVec, planetSphere, skyAbsorb, 25,0.);
	sunColorCloud = sunColorBase/4000. * skyAbsorb ;

	skyAbsorb = vec3(1.0);
	moonColor = calculateAtmosphere(vec3(0.0), -sunVec, vec3(0.0,1.0,0.0), sunVec, -sunVec, planetSphere, skyAbsorb, 25,0.5);
	moonColor = moonColorBase/4000.0*skyAbsorb;

	skyAbsorb = vec3(1.0);
	modSunVec = -sunVec*(1.0-dSun)+vec3(0.0,dSun,0.0);
	modSunVec2 = -sunVec*(1.0-dSun)+vec3(0.0,dSun,0.0);
	if (modSunVec2.y > modSunVec.y) modSunVec = modSunVec2;
	moonColorCloud = calculateAtmosphere(vec3(0.0), modSunVec, vec3(0.0,1.0,0.0), sunVec, -sunVec, planetSphere, skyAbsorb, 25,0.5);

	moonColorCloud = moonColorBase/4000.0*0.55;
	#ifndef CLOUDS_SHADOWS
	sunColor *= (1.0-rainStrength*vec3(0.96,0.95,0.94));
	moonColor *= (1.0-rainStrength*vec3(0.96,0.95,0.94));
	#endif
	lightSourceColor = sunVis >= 1e-5 ? sunColor * sunVis : moonColor * moonVis;

	float lightDir = float( sunVis >= 1e-5)*2.0-1.0;


	//Fake bounced sunlight
	vec3 bouncedSun = lightSourceColor*0.1/5.0*0.5*clamp(lightDir*sunVec.y,0.0,1.0)*clamp(lightDir*sunVec.y,0.0,1.0);
	vec3 cloudAmbientSun = (sunColorCloud)*0.007;
	vec3 cloudAmbientMoon = (moonColorCloud)*0.007;
	ambientUp += bouncedSun*clamp(-lightDir*sunVec.y+4.,0.,4.0) + cloudAmbientSun*clamp(sunVec.y+2.,0.,4.0) + cloudAmbientMoon*clamp(-sunVec.y+2.,0.,4.0);
	ambientLeft += bouncedSun*clamp(lightDir*sunVec.x+4.,0.0,4.) + cloudAmbientSun*clamp(-sunVec.x+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(sunVec.x+2.,0.0,4.)*0.7;
	ambientRight += bouncedSun*clamp(-lightDir*sunVec.x+4.,0.0,4.) + cloudAmbientSun*clamp(sunVec.x+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(-sunVec.x+2.,0.0,4.)*0.7;
	ambientB += bouncedSun*clamp(-lightDir*sunVec.z+4.,0.0,4.) + cloudAmbientSun*clamp(sunVec.z+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(-sunVec.z+2.,0.0,4.)*0.7;
	ambientF += bouncedSun*clamp(lightDir*sunVec.z+4.,0.0,4.) + cloudAmbientSun*clamp(-sunVec.z+2.,0.0,4.)*0.7 + cloudAmbientMoon*clamp(sunVec.z+2.,0.0,4.)*0.7;
	ambientDown += bouncedSun*clamp(lightDir*sunVec.y+4.,0.0,4.)*0.7 + cloudAmbientSun*clamp(-sunVec.y+2.,0.0,4.)*0.5 + cloudAmbientMoon*clamp(sunVec.y+2.,0.0,4.)*0.5;
	avgSky += bouncedSun*5.;

	vec3 rainNightBoost = moonColorCloud*rainStrength*0.005;
	ambientUp += rainNightBoost;
	ambientLeft += rainNightBoost;
	ambientRight += rainNightBoost;
	ambientB += rainNightBoost;
	ambientF += rainNightBoost;
	ambientDown += rainNightBoost;
	avgSky += rainNightBoost;

	float avgLuma = 0.0;
	float m2 = 0.0;
	int n=100;
	vec2 clampedRes = max(1.0/texelSize,vec2(1920.0,1080.));
	float avgExp = 0.0;
	float avgB = 0.0;
	vec2 resScale = vec2(1920.,1080.)/clampedRes*BLOOM_QUALITY;
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


	exposure=max(targetExposure*EXPOSURE_MULTIPLIER, 0);
	float currCenterDepth = ld(texture2D(depthtex0, vec2(0.5)*RENDER_SCALE).r);
	centerDepth = mix(sqrt(texelFetch2D(colortex4,ivec2(14,37),0).g/65000.0), currCenterDepth, clamp(DoF_Adaptation_Speed*exp(-0.016/frameTime+1.0)/(6.0+currCenterDepth*far),0.0,1.0));
	centerDepth = centerDepth * centerDepth * 65000.0;

	rodExposure = targetrodExposure;

	#ifndef AUTO_EXPOSURE
	 exposure = Manual_exposure_value;
	 rodExposure = clamp(log(Manual_exposure_value*2.0+1.0)-0.1,0.0,2.0);
	#endif
	float modWT = (worldTime%24000)*1.0;

	float fogAmount0 = 1/3000.+FOG_TOD_MULTIPLIER*(1/100.*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.))*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.)) + 1/120.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.));
	VFAmount = CLOUDY_FOG_AMOUNT*(fogAmount0*fogAmount0+FOG_RAIN_MULTIPLIER*1.0/20000.*rainStrength);
	fogAmount = BASE_FOG_AMOUNT*(fogAmount0+max(FOG_RAIN_MULTIPLIER*1/10.*rainStrength , FOG_TOD_MULTIPLIER*1/50.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.)));
}
