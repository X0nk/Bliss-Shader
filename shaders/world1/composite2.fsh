#version 120
//Volumetric fog rendering
//#extension GL_EXT_gpu_shader4 : disable

#include "/lib/settings.glsl"

flat varying vec4 lightCol;
// flat varying vec3 ambientUp;
// flat varying vec3 ambientLeft;
// flat varying vec3 ambientRight;
// flat varying vec3 ambientB;
// flat varying vec3 ambientF;
// flat varying vec3 ambientDown;
flat varying float tempOffsets;
flat varying float fogAmount;
flat varying float VFAmount;
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


#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/projections.glsl"
#include "/lib/end_fog.glsl"


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

varying vec2 texcoord;

void main() {
/* DRAWBUFFERS:0 */

	if (isEyeInWater == 0){
		vec2 tc = floor(gl_FragCoord.xy)*2.0*texelSize+0.5*texelSize;
		float z = texture2D(depthtex0,tc).x;
		vec3 fragpos = toScreenSpace(vec3(tc,z));
		
  		vec3 fragpos_ALT = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z));

		float noise = blueNoise();
		mat2x3 vl = getVolumetricRays(noise,fragpos, interleaved_gradientNoise());

		float absorbance = dot(vl[1],vec3(0.22,0.71,0.07));
		
		gl_FragData[0] = clamp(vec4(vl[0],absorbance),0.000001,65000.);

	} else {
		gl_FragData[0] = vec4(0.0);
	}
}
