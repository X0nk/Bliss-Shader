#include "/lib/settings.glsl"
//Computes volumetric clouds at variable resolution (default 1/4 res)

#define USE_WEATHER_PARAMS

#ifdef Daily_Weather
	flat varying vec3 dailyWeatherParams0;
	flat varying vec3 dailyWeatherParams1;
#endif

flat varying vec3 sunColor;
// flat varying vec3 moonColor;
flat varying vec3 averageSkyCol;

flat varying float tempOffsets;
// uniform float far;
uniform float near;
uniform sampler2D depthtex0;
uniform sampler2D dhDepthTex;
// uniform sampler2D colortex4;
uniform sampler2D noisetex;

uniform sampler2D colortex12;

flat varying vec3 WsunVec;
uniform vec3 sunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int frameCounter;
uniform int framemod8;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
// flat varying vec2 TAA_Offset;


vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

float R2_dither(){
	#ifdef TAA
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	#else

	vec2 coord = gl_FragCoord.xy;
	#endif
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}
float interleaved_gradientNoise(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	vec2 coord = vec2(alpha.x * gl_FragCoord.x,alpha.y * gl_FragCoord.y)+ 1.0/1.6180339887 * frameCounter;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}



const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);
float blueNoise(){
  #ifdef TAA
  	return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
  #else
 	return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a);
  #endif
}


vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

#include "/lib/lightning_stuff.glsl"

#include "/lib/sky_gradient.glsl"
#include "/lib/volumetricClouds.glsl"
#include "/lib/res_params.glsl"


//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////


void main() {
/* DRAWBUFFERS:0 */

#ifdef OVERWORLD_SHADER
	#ifdef VOLUMETRIC_CLOUDS
		vec2 halfResTC = vec2(floor(gl_FragCoord.xy)/CLOUDS_QUALITY/RENDER_SCALE+0.5+offsets[framemod8]*CLOUDS_QUALITY*RENDER_SCALE*0.5);

		vec3 viewPos = toScreenSpace(vec3(halfResTC*texelSize,1.0));

		vec4 VolumetricClouds = renderClouds(viewPos, vec2(R2_dither(), blueNoise()), sunColor/80.0, averageSkyCol/30.0);

		// gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);
		gl_FragData[0] = VolumetricClouds;


	#else
		gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);
	#endif
#else
	gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);
#endif 
}