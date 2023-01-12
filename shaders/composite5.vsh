#version 120
#extension GL_EXT_gpu_shader4 : enable
#define TAA
#define VL_CLOUDS_SHADOWS // Casts shadows from clouds on VL (slow)
#define BASE_FOG_AMOUNT 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0 10.0 20.0 30.0 50.0 100.0 150.0 200.0]  Base fog amount amount (does not change the "cloudy" fog)
#define CLOUDY_FOG_AMOUNT 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0]
#define FOG_TOD_MULTIPLIER 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0] //Influence of time of day on fog amount
#define FOG_RAIN_MULTIPLIER 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0] //Influence of rain on fog amount

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

	sunColor = texelFetch2D(colortex4,ivec2(12,37),0).rgb;
	moonColor = texelFetch2D(colortex4,ivec2(13,37),0).rgb;
	avgAmbient = texelFetch2D(colortex4,ivec2(11,37),0).rgb;


	ambientUp = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
	ambientDown = texelFetch2D(colortex4,ivec2(1,37),0).rgb;
	ambientLeft = texelFetch2D(colortex4,ivec2(2,37),0).rgb;
	ambientRight = texelFetch2D(colortex4,ivec2(3,37),0).rgb;
	ambientB = texelFetch2D(colortex4,ivec2(4,37),0).rgb;
	ambientF = texelFetch2D(colortex4,ivec2(5,37),0).rgb;


	lightCol.a = float(sunElevation > 1e-5)*2-1.;
	lightCol.rgb = sc;

	TAA_Offset = offsets[frameCounter%8];
	#ifndef TAA
	TAA_Offset = vec2(0.0);
	#endif

	#ifndef VL_Clouds_Shadows
		lightCol.rgb *= (1.0-rainStrength*0.9);
	#endif
	// float Time = worldTime%24000;

	// FogSchedule = 	clamp( (Time - 9000)/9000 ,0,1);
	// // float fogAmount0 = 1/3000.+FOG_TOD_MULTIPLIER*(1/100.*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.))*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.)) + 1/120.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.));
	
	// float fogAmount0 = TimeOfDayFog;
	
	// // VFAmount = CLOUDY_FOG_AMOUNT*(fogAmount0*fogAmount0+FOG_RAIN_MULTIPLIER*1.0/20000.*rainStrength);
	// VFAmount = fogAmount0;
	// fogAmount = BASE_FOG_AMOUNT*(fogAmount0+max(FOG_RAIN_MULTIPLIER*1/10.*rainStrength , FOG_TOD_MULTIPLIER*1/50.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.)));
	
	
	
	
	WsunVec = lightCol.a*normalize(mat3(gbufferModelViewInverse) *sunPosition);
	refractedSunVec = refract(WsunVec, -vec3(0.0,1.0,0.0), 1.0/1.33333);
}
