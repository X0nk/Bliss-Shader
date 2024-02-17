#version 120
//#extension GL_ARB_shader_texture_lod : disable

#include "/lib/settings.glsl"


varying vec2 texcoord;
uniform sampler2D tex;
uniform sampler2D noisetex;
uniform int frameCounter;
// varying vec4 color;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////


float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 );
}
// float R2_dither(){
// 	vec2 coord = gl_FragCoord.xy;
// 	vec2 alpha = vec2(0.75487765, 0.56984026);
// 	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
// }
void main() {
	gl_FragData[0] = texture2D(tex,texcoord.xy);
	
	#ifdef SHADOW_DISABLE_ALPHA_MIPMAPS
		gl_FragData[0].a = texture2DLod(tex,texcoord.xy, 0).a;
	#endif

  	#ifdef Stochastic_Transparent_Shadows
		if(gl_FragData[0].a < blueNoise()) { discard; return;}
  	#endif

	#ifdef RENDER_ENTITY_SHADOWS
	#endif
}
