#version 120
#extension GL_EXT_gpu_shader4 : enable

flat varying float tempOffsets;
uniform int frameCounter;
flat varying vec2 TAA_Offset;

#include "/lib/util.glsl"
#include "/lib/res_params.glsl"

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);

void main() {
	gl_Position = ftransform();
	

	TAA_Offset = offsets[frameCounter%8];
	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	#endif

}
