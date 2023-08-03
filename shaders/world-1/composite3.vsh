#version 120
//#extension GL_EXT_gpu_shader4 : disable

flat varying float tempOffsets;

uniform int frameCounter;

#include "/lib/util.glsl"

flat varying vec2 TAA_Offset;
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
	gl_Position = ftransform();

	tempOffsets = HaltonSeq2(frameCounter%10000);
	TAA_Offset = offsets[frameCounter%8];
	
	#ifndef TAA
		TAA_Offset = vec2(0.0);
	#endif

	gl_Position.xy = (gl_Position.xy*0.5+0.5)*0.51*2.0-1.0;
}
