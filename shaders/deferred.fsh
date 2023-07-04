#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "lib/settings.glsl"
//Prepares sky textures (2 * 256 * 256), computes light values and custom lightmaps
#define ReflectedFog

flat varying vec3 averageSkyCol_Clouds;
flat varying vec3 averageSkyCol;

flat varying vec3 lightSourceColor;
flat varying vec3 sunColor;
flat varying vec3 moonColor;
flat varying vec3 zenithColor;

flat varying float avgL2;
flat varying vec2 tempOffsets;
flat varying float exposure;
flat varying float rodExposure;
flat varying float avgBrightness;
flat varying float centerDepth;

// uniform sampler2D colortex4;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow;

uniform int frameCounter;
uniform float rainStrength;
uniform float eyeAltitude;
uniform vec3 sunVec;
flat varying vec3 WsunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float sunElevation;
uniform vec3 cameraPosition;
uniform float far;
uniform ivec2 eyeBrightnessSmooth;

#include "lib/Shadow_Params.glsl"
#include "/lib/util.glsl"
#include "/lib/ROBOBO_sky.glsl"
#include "lib/sky_gradient.glsl"

// uniform int worldTime; 

#define TIMEOFDAYFOG
#include "lib/volumetricClouds.glsl"

// #include "lib/biome_specifics.glsl"

vec3 toShadowSpaceProjected(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    p3 = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
    p3 = diagonal3(shadowProjection) * p3 + shadowProjection[3].xyz;

    return p3;
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter);
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y + 1.0/1.6180339887 * frameCounter));
	return noise;
}
vec4 lightCol = vec4(lightSourceColor, float(sunElevation > 1e-5)*2-1.);

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

#include "lib/volumetricFog.glsl"

const float[17] Slightmap = float[17](14.0,17.,19.0,22.0,24.0,28.0,31.0,40.0,60.0,79.0,93.0,110.0,132.0,160.0,197.0,249.0,249.0);

uniform sampler2D depthtex1;//depth
// #define ffstep(x,y) clamp((y - x) * 1e35,0.0,1.0)
// #define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
// #define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);

void main() {
/* DRAWBUFFERS:4 */
gl_FragData[0] = vec4(0.0);

//Save light values
if (gl_FragCoord.x < 1. && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(averageSkyCol_Clouds,1.0);
if (gl_FragCoord.x > 1. && gl_FragCoord.x < 2.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(averageSkyCol,1.0);

if (gl_FragCoord.x > 6. && gl_FragCoord.x < 7.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(lightSourceColor,1.0);

if (gl_FragCoord.x > 8. && gl_FragCoord.x < 9.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(sunColor,1.0);
if (gl_FragCoord.x > 13. && gl_FragCoord.x < 14.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(moonColor,1.0);

const float pi = 3.141592653589793238462643383279502884197169;

//Sky gradient (no clouds)
if (gl_FragCoord.x > 18. && gl_FragCoord.y > 1. && gl_FragCoord.x < 18+257){
	vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.,1.))/256.+tempOffsets/256.,0.0,1.0);
	vec3 viewVector = cartToSphere(p);

	vec2 planetSphere = vec2(0.0);
	vec3 sky = vec3(0.0);
	vec3 skyAbsorb = vec3(0.0);

	vec3 WsunVec = mat3(gbufferModelViewInverse)*sunVec;

	sky = calculateAtmosphere(averageSkyCol*4000./2.0, viewVector, vec3(0.0,1.0,0.0), WsunVec, -WsunVec, planetSphere, skyAbsorb, 10, blueNoise());

	#ifdef AEROCHROME_MODE
		sky *= vec3(0.0, 0.18, 0.35);
	#endif

  gl_FragData[0] = vec4(sky/4000.*Sky_Brightness,1.0);
}

//Sky gradient with clouds
if (gl_FragCoord.x > 18.+257. && gl_FragCoord.y > 1. && gl_FragCoord.x < 18+257+257.){
	vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.+257,1.))/256.+tempOffsets/256.,0.0,1.0);
	vec3 viewVector = cartToSphere(p);

	vec3 WsunVec = mat3(gbufferModelViewInverse)*sunVec;
	vec3 sky = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy)-ivec2(257,0),0).rgb/150. ;	

	if(viewVector.y < -0.025) sky = sky * clamp( exp(viewVector.y) - 1.0,0.25,1.0) ;
  
	vec4 clouds = renderClouds(mat3(gbufferModelView)*viewVector*1024.,vec2(fract(frameCounter/1.6180339887),1-fract(frameCounter/1.6180339887)), sunColor, moonColor, averageSkyCol*5.0);
	sky = sky*clouds.a + clouds.rgb/5.0; 

	vec4 VL_Fog = getVolumetricRays(mat3(gbufferModelView)*viewVector*1024.,  fract(frameCounter/1.6180339887), averageSkyCol);
	sky = sky*VL_Fog.a + VL_Fog.rgb*20;

	gl_FragData[0] = vec4(sky,1.0);
}

//Temporally accumulate sky and light values
vec3 temp = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy),0).rgb;
vec3 curr = gl_FragData[0].rgb*150.;
gl_FragData[0].rgb = clamp(mix(temp,curr,0.07),0.0,65000.);

//Exposure values
if (gl_FragCoord.x > 10. && gl_FragCoord.x < 11.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(exposure,avgBrightness,avgL2,1.0);
if (gl_FragCoord.x > 14. && gl_FragCoord.x < 15.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(rodExposure,centerDepth,0.0, 1.0);

}
