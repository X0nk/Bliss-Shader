#include "/lib/settings.glsl"

#define ReflectedFog



flat varying vec3 averageSkyCol_Clouds;
flat varying vec3 averageSkyCol;

flat varying vec3 lightSourceColor;
flat varying vec3 sunColor;
flat varying vec3 moonColor;
// flat varying vec3 zenithColor;
// flat varying vec3 rayleighAborbance; 

// flat varying vec3 WsunVec;

flat varying vec2 tempOffsets;

flat varying float exposure;
flat varying float avgBrightness;
flat varying float rodExposure;
flat varying float avgL2;
flat varying float centerDepth;

uniform sampler2D noisetex;

uniform float frameTime;
uniform int frameCounter;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float eyeAltitude;
uniform vec3 sunVec;
uniform vec2 texelSize;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float sunElevation;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
// uniform float far;
uniform ivec2 eyeBrightnessSmooth;
uniform float caveDetection;


vec4 lightCol = vec4(lightSourceColor, float(sunElevation > 1e-5)*2-1.);

#include "/lib/util.glsl"
#include "/lib/ROBOBO_sky.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/Shadow_Params.glsl"

vec3 WsunVec = mat3(gbufferModelViewInverse)*sunVec;
// vec3 WsunVec = normalize(LightDir);

vec3 toShadowSpaceProjected(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    p3 = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
    p3 = diagonal3(shadowProjection) * p3 + shadowProjection[3].xyz;

    return p3;
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)+frameCounter/1.6180339887);
	return noise;
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}

#define DHVLFOG
// #define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
// #define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 feetPlayerPos = p * 2. - 1.;
    vec4 viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
    return viewPos.xyz / viewPos.w;
}

uniform float near;
uniform float dhFarPlane;
uniform float dhNearPlane;

#include "/lib/DistantHorizons_projections.glsl"

vec3 DH_toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(dhProjectionInverse[0].x, dhProjectionInverse[1].y, dhProjectionInverse[2].zw);
    vec3 feetPlayerPos = p * 2. - 1.;
    vec4 viewPos = iProjDiag * feetPlayerPos.xyzz + dhProjectionInverse[3];
    return viewPos.xyz / viewPos.w;
}

vec3 DH_toClipSpace3(vec3 viewSpacePosition) {
    return projMAD(dhProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

// float DH_ld(float dist) {
//     return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
// }
// float DH_invLinZ (float lindepth){
// 	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
// }

float DH_ld(float dist) {
    return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
}
float DH_inv_ld (float lindepth){
	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}
float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}
#ifdef OVERWORLD_SHADER

	// uniform sampler2D colortex12;
	// const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;

	// #undef TRANSLUCENT_COLORED_SHADOWS

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif

	#define TEST
	#define TIMEOFDAYFOG
	#include "/lib/lightning_stuff.glsl"
	
	#include "/lib/volumetricClouds.glsl"
	#include "/lib/overworld_fog.glsl"
	
#endif
#ifdef NETHER_SHADER
	uniform sampler2D colortex4;
	#include "/lib/nether_fog.glsl"
#endif
#ifdef END_SHADER
	uniform sampler2D colortex4;
	#include "/lib/end_fog.glsl"
#endif

vec3 rodSample(vec2 Xi)
{
	float r = sqrt(1.0f - Xi.x*Xi.y);
    float phi = 2 * 3.14159265359 * Xi.y;

    return normalize(vec3(cos(phi) * r, sin(phi) * r, Xi.x)).xzy;
}
//Low discrepancy 2D sequence, integration error is as low as sobol but easier to compute : http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
vec2 R2_samples(float n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}

void main() {
/* DRAWBUFFERS:4 */

gl_FragData[0] = vec4(0.0);
float mixhistory = 0.06;

float accumuteSpeed = texelFetch2D(colortex4, ivec2(5,5), 0).r/150.0;

vec2 pixelPos6 = vec2(5,5);

if (gl_FragCoord.x > pixelPos6.x && gl_FragCoord.x < pixelPos6.x + 1 && gl_FragCoord.y > pixelPos6.y && gl_FragCoord.y < pixelPos6.y + 1){
	mixhistory = 0.1;
	gl_FragData[0] = vec4(1,0,0,1);
}




#ifdef OVERWORLD_SHADER

	//////////////////////////////////////////////
	/// --- STORE DAILY WEATHER PARAMETERS --- ///
	//////////////////////////////////////////////

	// the idea is to store the 8 values, coverage + density of 3 cloud layers and 2 fog density values.

	#ifdef Daily_Weather
		ivec2 pixelPos = ivec2(0,0);
		if (gl_FragCoord.x > 1 && gl_FragCoord.x < 4 && gl_FragCoord.y > 1 && gl_FragCoord.y < 2){
			
			mixhistory = 0.005;
			
			if(gl_FragCoord.x < 2) gl_FragData[0] = vec4(dailyWeatherParams0.rgb * 2.0,1.0);
			if(gl_FragCoord.x > 2) gl_FragData[0] = vec4(dailyWeatherParams1.rgb * 2.0,1.0);
			if(gl_FragCoord.x > 3) gl_FragData[0] = vec4(dailyWeatherParams0.a * 2.0, dailyWeatherParams1.a * 2.0, 0.0, 1.0);
	
		}
	#endif

	///////////////////////////////
	/// --- STORE COLOR LUT --- ///
	///////////////////////////////

	vec3 AmbientLightTint = vec3(AmbientLight_R, AmbientLight_G, AmbientLight_B);

	// --- the color of the atmosphere + the average color of the atmosphere.
	vec3 skyGroundCol = skyFromTex(vec3(0, -1 ,0), colortex4).rgb;// * clamp(WsunVec.y*2.0,0.2,1.0);


	/// --- Save light values
	if (gl_FragCoord.x < 1. && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
	gl_FragData[0] = vec4(averageSkyCol_Clouds * AmbientLightTint,1.0);

	if (gl_FragCoord.x > 1. && gl_FragCoord.x < 2.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
	gl_FragData[0] = vec4((skyGroundCol/150.0) * AmbientLightTint,1.0);

	#ifdef ambientLight_only
		if (gl_FragCoord.x > 6. && gl_FragCoord.x < 7.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);

		if (gl_FragCoord.x > 8. && gl_FragCoord.x < 9.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);

		if (gl_FragCoord.x > 13. && gl_FragCoord.x < 14.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);
	#else
		if (gl_FragCoord.x > 6. && gl_FragCoord.x < 7.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(lightSourceColor,1.0);
		if (gl_FragCoord.x > 8. && gl_FragCoord.x < 9.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(sunColor,1.0);
		if (gl_FragCoord.x > 9. && gl_FragCoord.x < 10.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(moonColor,1.0);
		// if (gl_FragCoord.x > 16. && gl_FragCoord.x < 17.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		// gl_FragData[0] = vec4(rayleighAborbance,1.0);
	#endif
	

////////////////////////////////
/// --- ATMOSPHERE IMAGE --- ///
////////////////////////////////

/// --- Sky only
if (gl_FragCoord.x > 18. && gl_FragCoord.y > 1. && gl_FragCoord.x < 18+257){
	vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.,1.))/256.+tempOffsets/256.,0.0,1.0);
	vec3 viewVector = cartToSphere(p);

	vec2 planetSphere = vec2(0.0);
	vec3 sky = vec3(0.0);
	vec3 skyAbsorb = vec3(0.0);
	
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);
	
	sky = calculateAtmosphere((averageSkyCol*4000./2.0), viewVector, vec3(0.0,1.0,0.0), WsunVec, -WsunVec, planetSphere, skyAbsorb, 10, blueNoise());

	// fade atmosphere conditions for rain away when you pass above the cloud plane.
	float heightRelativeToClouds = clamp(1.0 - max(eyeAltitude - CloudLayer0_height,0.0) / 200.0 ,0.0,1.0);
	if(rainStrength > 0.0) sky = mix(sky, 3.0 + averageSkyCol*4000 * (skyAbsorb*0.7+0.3), clamp(1.0 - exp(pow(clamp(-viewVector.y+0.9,0.0,1.0),2) * -5.0),0.0,1.0) * heightRelativeToClouds * rainStrength);
	
	#ifdef AEROCHROME_MODE
		sky *= vec3(0.0, 0.18, 0.35);
	#endif

  gl_FragData[0] = vec4(sky / 4000.0, 1.0);
}

/// --- Sky + clouds + fog 
if (gl_FragCoord.x > 18.+257. && gl_FragCoord.y > 1. && gl_FragCoord.x < 18+257+257.){
	vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.+257,1.))/256.+tempOffsets/256.,0.0,1.0);
	vec3 viewVector = cartToSphere(p);

	WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition) ;// * ( float(sunElevation > 1e-5)*2.0-1.0 );

	vec3 sky = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy)-ivec2(257,0),0).rgb/150.0;	
	sky = mix(dot(sky, vec3(0.333)) * vec3(0.5), sky,  pow(clamp(viewVector.y+1.0,0.0,1.0),5));
	
	vec3 suncol = lightSourceColor;
	#ifdef ambientLight_only
		suncol = vec3(0.0);
	#endif
	
	vec3 cloudDepth = vec3(0.0);
	vec4 clouds = renderClouds(mat3(gbufferModelView)*viewVector*1024., vec2(fract(frameCounter/1.6180339887),1-fract(frameCounter/1.6180339887)), suncol*2.0, skyGroundCol/30.0, cloudDepth);
	
	float atmosphereAlpha = 1.0;
	vec4 VL_Fog = GetVolumetricFog(mat3(gbufferModelView)*viewVector*1024.,  vec2(fract(frameCounter/1.6180339887),1-fract(frameCounter/1.6180339887)), suncol*2.0, skyGroundCol/30.0, averageSkyCol_Clouds*5.0, atmosphereAlpha);

	sky = sky*clouds.a + clouds.rgb / 5.0;
	sky *= atmosphereAlpha;
	sky = sky * VL_Fog.a + VL_Fog.rgb / 5.0;

	gl_FragData[0] = vec4(sky,1.0);
}
#endif

#if defined NETHER_SHADER || defined END_SHADER
	vec2 fogPos = vec2(256.0 - 256.0*0.12,1.0);

	//Sky gradient with clouds
	if (gl_FragCoord.x > (fogPos.x - fogPos.x*0.22) && gl_FragCoord.y > 0.4 && gl_FragCoord.x < 535){
		vec2 p = clamp(floor(gl_FragCoord.xy-fogPos)/256.+tempOffsets/256.,-0.2,1.2);
		vec3 viewVector = cartToSphere(p);

	 	vec3 BackgroundColor = vec3(0.0);

		vec4 VL_Fog = GetVolumetricFog(mat3(gbufferModelView)*viewVector*256.,  fract(frameCounter/1.6180339887), fract(frameCounter/2.6180339887));

		BackgroundColor += VL_Fog.rgb/5.0;

	  	gl_FragData[0] = vec4(BackgroundColor, 1.0);

	}
#endif

#ifdef END_SHADER
	/* ---------------------- TIMER ---------------------- */

	float flash = 0.0;
	float maxWaitTime = 5;

	float Timer = texelFetch2D(colortex4, ivec2(3,1), 0).x/150.0;
	Timer -= frameTime;

	if(Timer <= 0.0){
		flash = 1.0;

		Timer = pow(hash11(frameCounter), 5) * maxWaitTime;
	}

	vec2 pixelPos0 = vec2(3,1);
	if (gl_FragCoord.x > pixelPos0.x && gl_FragCoord.x < pixelPos0.x + 1 && gl_FragCoord.y > pixelPos0.y && gl_FragCoord.y < pixelPos0.y + 1){
		mixhistory = 1.0;
		gl_FragData[0] = vec4(Timer, 0.0, 0.0, 1.0);
	}

	/* ---------------------- FLASHING ---------------------- */

	vec2 pixelPos1 = vec2(1,1);
	if (gl_FragCoord.x > pixelPos1.x && gl_FragCoord.x < pixelPos1.x + 1 && gl_FragCoord.y > pixelPos1.y && gl_FragCoord.y < pixelPos1.y + 1){
		mixhistory = clamp(4.0 * frameTime,0.0,1.0);
		gl_FragData[0] = vec4(flash, 0.0, 0.0, 1.0);
	}

	/* ---------------------- POSITION ---------------------- */

	vec2 pixelPos2 = vec2(2,1);
	if (gl_FragCoord.x > pixelPos2.x && gl_FragCoord.x < pixelPos2.x + 1 && gl_FragCoord.y > pixelPos2.y && gl_FragCoord.y < pixelPos2.y + 1){
		mixhistory = clamp(500.0 * frameTime,0.0,1.0);

		vec3 LastPos = (texelFetch2D(colortex4,ivec2(2,1),0).xyz/150.0) * 2.0 - 1.0;
		
		LastPos += (hash31(frameCounter / 50) * 2.0 - 1.0);
		LastPos = LastPos * 0.5 + 0.5;

		if(Timer > maxWaitTime * 0.7 ){ 
			LastPos = vec3(0.0);
		}

		gl_FragData[0] = vec4(LastPos, 1.0);
	}

#endif




//Temporally accumulate sky and light values
vec3 temp = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy),0).rgb;
vec3 curr = gl_FragData[0].rgb*150.;

if(accumuteSpeed < 1.0) mixhistory = 1.0;

gl_FragData[0].rgb = clamp(mix(temp, curr, mixhistory),0.0,65000.);

//Exposure values
if (gl_FragCoord.x > 10. && gl_FragCoord.x < 11.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(exposure, avgBrightness, avgL2,1.0);
if (gl_FragCoord.x > 14. && gl_FragCoord.x < 15.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(rodExposure, centerDepth,0.0, 1.0);
}