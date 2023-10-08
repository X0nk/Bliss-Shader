#version 120
//#extension GL_ARB_shader_texture_lod : disable
#extension GL_EXT_gpu_shader4 : enable
#include "/lib/settings.glsl"


varying vec2 texcoord;
uniform sampler2D tex;
uniform sampler2D noisetex;
uniform int frameCounter;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////


float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 );
}
void main() {
	gl_FragData[0] = texture2D(tex,texcoord.xy);
	
	#ifdef SHADOW_DISABLE_ALPHA_MIPMAPS
		gl_FragData[0].a = texture2DLod(tex,texcoord.xy,0).a;
	#endif

	#ifdef RENDER_ENTITY_SHADOWS
	#endif

  #ifdef Stochastic_Transparent_Shadows
		gl_FragData[0].a = float(gl_FragData[0].a >= blueNoise());
  #endif
}
