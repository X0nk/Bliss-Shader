#version 120
//Volumetric fog rendering
//#extension GL_EXT_gpu_shader4 : disable

#include "/lib/settings.glsl"

flat varying float tempOffsets;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;

uniform sampler2D colortex2;
uniform sampler2D colortex3;
// uniform sampler2D colortex4;

uniform vec3 sunVec;
uniform float far;
uniform int frameCounter;
uniform float rainStrength;
uniform float sunElevation;
uniform ivec2 eyeBrightnessSmooth;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform vec2 texelSize;

uniform vec3 previousCameraPosition;
varying vec2 texcoord;

#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/projections.glsl"


#include "/lib/nether_fog.glsl"


#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)

float interleaved_gradientNoise(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+tempOffsets);
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////




void main() {
/* DRAWBUFFERS:0 */

	// if (isEyeInWater == 0){
		vec2 tc = floor(gl_FragCoord.xy)*2.0*texelSize+0.5*texelSize;
		float z = texture2D(depthtex0,tc).x;
		vec3 fragpos = toScreenSpace(vec3(tc,z));
		
		vec4 VolumetricFog = GetVolumetricFog(fragpos, blueNoise());

		gl_FragData[0] = clamp(VolumetricFog, 0.0, 65000.0);

	// } else {
	// 	gl_FragData[0] = vec4(0.0);
	// }
}
