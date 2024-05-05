#version 120

#include "/lib/settings.glsl"

varying vec4 color;

varying vec2 texcoord;
uniform sampler2D tex;
uniform sampler2D noisetex;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 );
}


void main() {
	gl_FragData[0] = vec4(texture2D(tex,texcoord.xy).rgb * color.rgb,  texture2DLod(tex, texcoord.xy, 0).a);

  	#ifdef Stochastic_Transparent_Shadows
		if(gl_FragData[0].a < blueNoise()) { discard; return;}
  	#endif
}
