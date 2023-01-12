#version 120
#extension GL_ARB_shader_texture_lod : enable
#extension GL_EXT_gpu_shader4 : enable
#define SHADOW_DISABLE_ALPHA_MIPMAPS // Disables mipmaps on the transparency of alpha-tested things like foliage, may cost a few fps in some cases
#define Stochastic_Transparent_Shadows // Highly recommanded to enable SHADOW_DISABLE_ALPHA_MIPMAPS with it. Uses noise to simulate transparent objects' shadows (not colored). It is also recommended to increase Min_Shadow_Filter_Radius with this.
varying vec2 texcoord;
uniform sampler2D tex;
uniform sampler2D noisetex;
uniform int frameCounter;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
// float blueNoise(){
//   return texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a;
// }
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 ) ;
}
void main() {
	gl_FragData[0] = texture2D(tex,texcoord.xy);
	#ifdef SHADOW_DISABLE_ALPHA_MIPMAPS
	 gl_FragData[0].a = texture2DLod(tex,texcoord.xy,0).a;
	#endif
  #ifdef Stochastic_Transparent_Shadows
	 gl_FragData[0].a = float(gl_FragData[0].a >= R2_dither());
  #endif
}
