#version 120
#extension GL_EXT_gpu_shader4 : disable

#include "/lib/settings.glsl"

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
vec3 sunVec = vec3(0.0,1.0,0.0);



#include "/lib/sky_gradient.glsl"
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
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
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

// 	tempOffsets = R2_samples(frameCounter%10000);

// 	ambientUp = vec3(0.0);
// 	ambientDown = vec3(0.0);
// 	ambientLeft = vec3(0.0);
// 	ambientRight = vec3(0.0);
// 	ambientB = vec3(0.0);
// 	ambientF = vec3(0.0);
// 	avgSky = vec3(0.0);



// 	//Fake bounced sunlight
// 	vec3 bouncedSun = clamp(gl_Fog.color.rgb*pow(luma(gl_Fog.color.rgb),-0.75)*0.65,0.0,1.0)/4000.*0.08;
// 	ambientUp += bouncedSun*clamp(-sunVec.y+5.,0.,6.0);
// 	ambientLeft += bouncedSun*clamp(sunVec.x+5.,0.0,6.);
// 	ambientRight += bouncedSun*clamp(-sunVec.x+5.,0.0,6.);
// 	ambientB += bouncedSun*clamp(-sunVec.z+5.,0.0,6.);
// 	ambientF += bouncedSun*clamp(sunVec.z+5.,0.0,6.);
// 	ambientDown += bouncedSun*clamp(sunVec.y+5.,0.0,6.);


// 	float avgLuma = 0.0;
// 	float m2 = 0.0;
// 	int n=100;
// 	vec2 clampedRes = max(1.0/texelSize,vec2(1920.0,1080.));
// 	float avgExp = 0.0;
// 	vec2 resScale = vec2(1920.,1080.)/clampedRes;
// 	float v[25];
// 	float temp;
// 	// 5x5 Median filter by morgan mcguire
// 	// We take the median value of the most blurred bloom buffer
// 	#define s2(a, b)				temp = a; a = min(a, b); b = max(temp, b);
// 	#define t2(a, b)				s2(v[a], v[b]);
// 	#define t24(a, b, c, d, e, f, g, h)			t2(a, b); t2(c, d); t2(e, f); t2(g, h);
// 	#define t25(a, b, c, d, e, f, g, h, i, j)		t24(a, b, c, d, e, f, g, h); t2(i, j);
// 	for (int i = 0; i < 5; i++){
// 		for (int j = 0; j < 5; j++){
// 			vec2 tc = 0.5 + vec2(i-2,j-2)/2.0 * 0.35;
// 			v[i+j*5] = luma(texture2D(colortex6,tc/128. * resScale+vec2(0.484375*resScale.x+10.5*texelSize.x,.0)).rgb);
// 		}
// 	}
// 	t25(0, 1,			3, 4,		2, 4,		2, 3,		6, 7);
//   t25(5, 7,			5, 6,		9, 7,		1, 7,		1, 4);
//   t25(12, 13,		11, 13,		11, 12,		15, 16,		14, 16);
//   t25(14, 15,		18, 19,		17, 19,		17, 18,		21, 22);
//   t25(20, 22,		20, 21,		23, 24,		2, 5,		3, 6);
//   t25(0, 6,			0, 3,		4, 7,		1, 7,		1, 4);
//   t25(11, 14,		8, 14,		8, 11,		12, 15,		9, 15);
//   t25(9, 12,		13, 16,		10, 16,		10, 13,		20, 23);
//   t25(17, 23,		17, 20,		21, 24,		18, 24,		18, 21);
//   t25(19, 22,		8, 17,		9, 18,		0, 18,		0, 9);
//   t25(10, 19,		1, 19,		1, 10,		11, 20,		2, 20);
//   t25(2, 11,		12, 21,		3, 21,		3, 12,		13, 22);
//   t25(4, 22,		4, 13,		14, 23,		5, 23,		5, 14);
//   t25(15, 24,		6, 24,		6, 15,		7, 16,		7, 19);
//   t25(3, 11,		5, 17,		11, 17,		9, 17,		4, 10);
//   t25(6, 12,		7, 14,		4, 6,		4, 7,		12, 14);
//   t25(10, 14,		6, 7,		10, 12,		6, 10,		6, 17);
//   t25(12, 17,		7, 17,		7, 10,		12, 18,		7, 12);
//   t24(10, 18,		12, 20,		10, 20,		10, 12);
// 	avgExp = v[12];		// Median value


// 	avgBrightness = clamp(mix(avgExp,texelFetch2D(colortex4,ivec2(10,37),0).g,0.95),0.00003051757,65000.0);

// 	float currentExposure = texelFetch2D(colortex4,ivec2(10,37),0).b;
// 	float L = max(avgBrightness,1e-8);
// 	float keyVal = 1.03-2.0/(log(L+1.0)/log(10.0)+2.0);
// 	float targetExposure = 1.0*keyVal/L;

// 	float targetrodExposure = clamp(log(targetExposure*2.0+1.0)-0.1,0.0,2.0);
// 	float currentrodExposure = texelFetch2D(colortex4,ivec2(14,37),0).r;

// 	targetExposure = clamp(targetExposure,2.0,3.0);
// 	float rad = sqrt(currentExposure);
// 	float rtarget = sqrt(targetExposure);
// 	float dir = sign(rtarget-rad);
// 	float dist = abs(rtarget-rad);
// 	float maxApertureChange = 0.0032*frameTime/0.016666*Exposure_Speed * exp2(max(rad,rtarget)*0.5);

// 	maxApertureChange *= 1.0+nightVision*4.;
// 	rad = rad+dir*min(dist,maxApertureChange);

// 	exposureF = rad*rad;
// 	exposure=exposureF*EXPOSURE_MULTIPLIER;


// 	dir = sign(targetrodExposure-currentrodExposure);
// 	dist = abs(targetrodExposure-currentrodExposure);
// 	maxApertureChange = 0.0032*frameTime/0.016666*Exposure_Speed * exp2(max(rad,rtarget)*0.5);

// 	rodExposure = currentrodExposure + dir * min(dist,maxApertureChange);

	exposure = 1.0;
	rodExposure = clamp(log(1.0*2.0+1.0)-0.1,0.0,2.0);

}
