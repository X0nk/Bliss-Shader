#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "lib/settings.glsl"

flat varying vec3 averageSkyCol_Clouds;
flat varying vec3 averageSkyCol;

flat varying vec4 lightCol;
flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;


flat varying vec3 sunColor;
flat varying vec3 moonColor;
flat varying vec3 avgAmbient;

flat varying vec2 TAA_Offset;

flat varying float tempOffsets;

flat varying float fogAmount;
flat varying float VFAmount;
flat varying float FogSchedule;


flat varying vec3 WsunVec;
flat varying vec3 refractedSunVec;

uniform sampler2D colortex4;
uniform vec3 sunPosition;
uniform float sunElevation;
uniform float rainStrength;
uniform int isEyeInWater;
uniform int frameCounter;
// uniform int worldTime;
uniform mat4 gbufferModelViewInverse;


#include "/lib/util.glsl"
#include "/lib/res_params.glsl"
// #include "lib/biome_specifics.glsl"


float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	tempOffsets = HaltonSeq2(frameCounter%10000);
	gl_Position = ftransform();
	gl_Position.xy = (gl_Position.xy*0.5+0.5)*(0.01+VL_RENDER_RESOLUTION)*2.0-1.0;
	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	#endif
	vec3 sc = texelFetch2D(colortex4,ivec2(6,37),0).rgb;


	averageSkyCol_Clouds = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
	averageSkyCol = texelFetch2D(colortex4,ivec2(1,37),0).rgb;
	
	sunColor = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
	moonColor = texelFetch2D(colortex4,ivec2(13,37),0).rgb;

	lightCol.a = float(sunElevation > 1e-5)*2-1.;
	lightCol.rgb = sc;

	// #ifdef VOLUMETRIC_CLOUDS
	// 	#ifndef VL_Clouds_Shadows
	// 		lightCol.rgb *= (1.0-rainStrength*0.9);
	// 	#endif
	// #endif



	TAA_Offset = offsets[frameCounter%8];
	#ifndef TAA
		TAA_Offset = vec2(0.0);
	#endif

	WsunVec = lightCol.a*normalize(mat3(gbufferModelViewInverse) *sunPosition);
	refractedSunVec = refract(WsunVec, -vec3(0.0,1.0,0.0), 1.0/1.33333);
}
