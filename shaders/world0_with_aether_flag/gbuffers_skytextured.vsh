#version 120
#include "/lib/settings.glsl"

#if RESOURCEPACK_SKY != 0
	#include "/lib/res_params.glsl"
	/*
	!! DO NOT REMOVE !!
	This code is from Chocapic13' shaders
	Read the terms of modification and sharing before changing something below please !
	!! DO NOT REMOVE !!
	*/
	varying vec4 color;
	varying vec2 texcoord;
	uniform vec2 texelSize;
	uniform int framemod8;
	const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
								vec2(-1.,3.)/8.,
								vec2(5.0,1.)/8.,
								vec2(-3,-5.)/8.,
								vec2(-5.,5.)/8.,
								vec2(-7.,-1.)/8.,
								vec2(3,7.)/8.,
								vec2(7.,-7.)/8.);

#endif

void main() {
	gl_Position = ftransform();
	
	#if RESOURCEPACK_SKY != 0

		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
		color = gl_Color;

		#ifdef TAA_UPSCALING
			gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
		#endif
		#ifdef TAA
			gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
		#endif
		
	#endif
}