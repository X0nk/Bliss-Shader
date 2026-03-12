#version 120
#define ANTIALIASING_RELATED_SETTINGS
#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/TAA_jitter.glsl"

#if RESOURCEPACK_SKY != 0
	/*
	!! DO NOT REMOVE !!
	This code is from Chocapic13' shaders
	Read the terms of modification and sharing before changing something below please !
	!! DO NOT REMOVE !!
	*/
	varying vec4 color;
	varying vec2 texcoord;
	uniform vec2 texelSize;
#endif

void main() {
	gl_Position = ftransform();
	
	#if RESOURCEPACK_SKY != 0

		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
		color = gl_Color;

		#if TAA_MODE == 3
			gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
		#endif
		#if TAA_MODE > 0
			gl_Position.xy += taaJitter * gl_Position.w*texelSize;
		#endif
		
	#endif
}