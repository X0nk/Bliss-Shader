#version 120
#extension GL_EXT_gpu_shader4 : enable
#define EXPOSURE_MULTIPLIER 1.0 //[0.25 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.1 1.2 1.3 1.4 1.5 2.0 3.0 4.0]
#define AUTO_EXPOSURE		//Highly recommended to keep it on unless you want to take screenshots
#define Manual_exposure_value 1.0			// [0.000553 0.000581 0.000611 0.000642 0.000675 0.000710 0.000746 0.000784 0.000825 0.000867 0.000911 0.000958 0.001007 0.001059 0.001113 0.001170 0.001230 0.001294 0.001360 0.001430 0.001503 0.001580 0.001661 0.001746 0.001836 0.001930 0.002029 0.002133 0.002242 0.002357 0.002478 0.002605 0.002739 0.002879 0.003027 0.003182 0.003345 0.003517 0.003697 0.003887 0.004086 0.004296 0.004516 0.004748 0.004991 0.005247 0.005516 0.005799 0.006096 0.006409 0.006737 0.007083 0.007446 0.007828 0.008229 0.008651 0.009095 0.009561 0.010051 0.010567 0.011108 0.011678 0.012277 0.012906 0.013568 0.014264 0.014995 0.015764 0.016572 0.017422 0.018315 0.019254 0.020241 0.021279 0.022370 0.023517 0.024723 0.025991 0.027323 0.028724 0.030197 0.031745 0.033373 0.035084 0.036883 0.038774 0.040762 0.042852 0.045049 0.047358 0.049787 0.052339 0.055023 0.057844 0.060810 0.063927 0.067205 0.070651 0.074273 0.078081 0.082084 0.086293 0.090717 0.095369 0.100258 0.105399 0.110803 0.116484 0.122456 0.128734 0.135335 0.142274 0.149568 0.157237 0.165298 0.173773 0.182683 0.192049 0.201896 0.212247 0.223130 0.234570 0.246596 0.259240 0.272531 0.286504 0.301194 0.316636 0.332871 0.349937 0.367879 0.386741 0.406569 0.427414 0.449328 0.472366 0.496585 0.522045 0.548811 0.576949 0.606530 0.637628 0.670320 0.704688 0.740818 0.778800 0.818730 0.860707 0.904837 0.951229 1.0 1.051271 1.105170 1.161834 1.221402 1.284025 1.349858 1.419067 1.491824 1.568312 1.648721 1.733253 1.822118 1.915540 2.013752 2.117000 2.225540 2.339646 2.459603 2.585709 2.718281 2.857651 3.004166 3.158192 3.320116 3.490342 3.669296 3.857425 4.055199 4.263114 4.481689 4.711470 4.953032 5.206979 5.473947 5.754602 6.049647 6.359819 6.685894 7.028687 7.389056 7.767901 8.166169 8.584858 9.025013 9.487735 9.974182 10.48556 11.02317 11.58834 12.18249 ]
#define Exposure_Speed 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 4.0 5.0]
#define CLOUDS_SHADOWS
#define BASE_FOG_AMOUNT 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0 10.0 20.0 30.0 50.0 100.0 150.0 200.0]  Base fog amount amount (does not change the "cloudy" fog)
#define CLOUDY_FOG_AMOUNT 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0]
#define FOG_TOD_MULTIPLIER 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0] //Influence of time of day on fog amount
#define FOG_RAIN_MULTIPLIER 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0] //Influence of rain on fog amount
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

uniform sampler2D colortex4;
uniform sampler2D colortex6;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec2 texelSize;
uniform float rainStrength;
uniform float sunElevation;
uniform float nightVision;
uniform float frameTime;
uniform float eyeAltitude;
uniform int frameCounter;
uniform int worldTime;
vec3 sunVec = -normalize(vec3(0.8,0.8,0.2));


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



	//Fake bounced sunlight
	vec3 bouncedSun = 0.3 * vec3(1.0,0.7,0.85)/4000;
	ambientUp += bouncedSun*clamp(-sunVec.y+1.,0.,4.0);
	ambientLeft += bouncedSun*clamp(sunVec.x+1.,0.0,4.);
	ambientRight += bouncedSun*clamp(-sunVec.x+1.,0.0,4.);
	ambientB += bouncedSun*clamp(-sunVec.z+1.,0.0,4.);
	ambientF += bouncedSun*clamp(sunVec.z+1.,0.0,4.);
	ambientDown += bouncedSun*clamp(sunVec.y+1.,0.0,4.);


	float avgLuma = 0.0;
	float m2 = 0.0;
	int n=100;
	vec2 clampedRes = max(1.0/texelSize,vec2(1920.0,1080.));
	float avgExp = 0.0;
	vec2 resScale = vec2(1920.,1080.)/clampedRes;
	float v[25];
	float temp;
	// 5x5 Median filter by morgan mcguire
	// We take the median value of the most blurred bloom buffer
	#define s2(a, b)				temp = a; a = min(a, b); b = max(temp, b);
	#define t2(a, b)				s2(v[a], v[b]);
	#define t24(a, b, c, d, e, f, g, h)			t2(a, b); t2(c, d); t2(e, f); t2(g, h);
	#define t25(a, b, c, d, e, f, g, h, i, j)		t24(a, b, c, d, e, f, g, h); t2(i, j);
	for (int i = 0; i < 5; i++){
		for (int j = 0; j < 5; j++){
			vec2 tc = 0.5 + vec2(i-2,j-2)/2.0 * 0.35;
			v[i+j*5] = luma(texture2D(colortex6,tc/128. * resScale+vec2(0.484375*resScale.x+10.5*texelSize.x,.0)).rgb);
		}
	}
	t25(0, 1,			3, 4,		2, 4,		2, 3,		6, 7);
  t25(5, 7,			5, 6,		9, 7,		1, 7,		1, 4);
  t25(12, 13,		11, 13,		11, 12,		15, 16,		14, 16);
  t25(14, 15,		18, 19,		17, 19,		17, 18,		21, 22);
  t25(20, 22,		20, 21,		23, 24,		2, 5,		3, 6);
  t25(0, 6,			0, 3,		4, 7,		1, 7,		1, 4);
  t25(11, 14,		8, 14,		8, 11,		12, 15,		9, 15);
  t25(9, 12,		13, 16,		10, 16,		10, 13,		20, 23);
  t25(17, 23,		17, 20,		21, 24,		18, 24,		18, 21);
  t25(19, 22,		8, 17,		9, 18,		0, 18,		0, 9);
  t25(10, 19,		1, 19,		1, 10,		11, 20,		2, 20);
  t25(2, 11,		12, 21,		3, 21,		3, 12,		13, 22);
  t25(4, 22,		4, 13,		14, 23,		5, 23,		5, 14);
  t25(15, 24,		6, 24,		6, 15,		7, 16,		7, 19);
  t25(3, 11,		5, 17,		11, 17,		9, 17,		4, 10);
  t25(6, 12,		7, 14,		4, 6,		4, 7,		12, 14);
  t25(10, 14,		6, 7,		10, 12,		6, 10,		6, 17);
  t25(12, 17,		7, 17,		7, 10,		12, 18,		7, 12);
  t24(10, 18,		12, 20,		10, 20,		10, 12);
	avgExp = v[12];		// Median value


	avgBrightness = clamp(mix(avgExp,texelFetch2D(colortex4,ivec2(10,37),0).g,0.95),0.00003051757,65000.0);

	float currentExposure = texelFetch2D(colortex4,ivec2(10,37),0).b;
	float L = max(avgBrightness,1e-8);
	float keyVal = 1.03-2.0/(log(L+1.0)/log(10.0)+2.0);
	float targetExposure = 1.0*keyVal/L;

	float targetrodExposure = clamp(log(targetExposure*2.0+1.0)-0.1,0.0,2.0);
	float currentrodExposure = texelFetch2D(colortex4,ivec2(14,37),0).r;

	targetExposure = clamp(targetExposure,2.0,3.0);
	float rad = sqrt(currentExposure);
	float rtarget = sqrt(targetExposure);
	float dir = sign(rtarget-rad);
	float dist = abs(rtarget-rad);
	float maxApertureChange = 0.0032*frameTime/0.016666*Exposure_Speed * exp2(max(rad,rtarget)*0.5);

	maxApertureChange *= 1.0+nightVision*4.;
	rad = rad+dir*min(dist,maxApertureChange);

	exposureF = rad*rad;
	exposure=exposureF*EXPOSURE_MULTIPLIER;


	dir = sign(targetrodExposure-currentrodExposure);
	dist = abs(targetrodExposure-currentrodExposure);
	maxApertureChange = 0.0032*frameTime/0.016666*Exposure_Speed * exp2(max(rad,rtarget)*0.5);

	rodExposure = currentrodExposure + dir * min(dist,maxApertureChange);

	#ifndef AUTO_EXPOSURE
	 exposure = Manual_exposure_value;
	 rodExposure = clamp(log(Manual_exposure_value*2.0+1.0)-0.1,0.0,2.0);
	#endif
	float modWT = (worldTime%24000)*1.0;

	float fogAmount0 = 1/3000.+FOG_TOD_MULTIPLIER*(1/180.*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.))*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.)) + 1/200.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.));
	VFAmount = CLOUDY_FOG_AMOUNT*(fogAmount0*fogAmount0+FOG_RAIN_MULTIPLIER*1.8/20000.*rainStrength);
	fogAmount = BASE_FOG_AMOUNT*(fogAmount0+max(FOG_RAIN_MULTIPLIER*1/15.*rainStrength , FOG_TOD_MULTIPLIER*1/50.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.)));
}
