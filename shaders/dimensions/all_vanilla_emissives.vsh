#include "/lib/settings.glsl"
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
#include "/lib/TAA_jitter.glsl"
					
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

uniform sampler2D colortex4;

void main() {
	color = gl_Color;

	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;

	gl_Position = ftransform();

	#ifdef BEACON_BEAM
		if(gl_Color.a < 1.0) gl_Position = vec4(10,10,10,0);
	#endif

	#if TAA_MODE == 3
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
	#if TAA_MODE > 0
	    gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
	#endif
}
