#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/settings.glsl"

varying vec2 texcoord;

flat varying vec3 avgAmbient;

flat varying float tempOffsets;
flat varying vec2 TAA_Offset;
flat varying vec3 zMults;

uniform sampler2D colortex4;

uniform float far;
uniform float near;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform float sunElevation;
uniform int frameCounter;

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);


#include "/lib/util.glsl"

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;

	tempOffsets = HaltonSeq2(frameCounter%10000);

	TAA_Offset = offsets[frameCounter%8];
	
	#ifndef TAA
		TAA_Offset = vec2(0.0);
	#endif


	avgAmbient = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
	zMults = vec3((far * near)*2.0,far+near,far-near);
}
