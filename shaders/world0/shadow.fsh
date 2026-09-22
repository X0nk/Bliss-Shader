#version 120
#define DIRECT_LIGHT_RELATED_SETTINGS
#define SHADOWMAP_CONSTANT_RELATED_SETTINGS
#include "/lib/settings.glsl"
#include "/lib/blocks.glsl"

varying vec4 color;
varying float shadowBlockId;

varying vec2 texcoord;
uniform sampler2D tex;
uniform sampler2D noisetex;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

float blueNoise(){
  return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 );
}

void main() {
	if (!gl_FrontFacing && shadowBlockId >= float(BLOCK_GLASS) && shadowBlockId <= float(BLOCK_GLASS_YELLOW)) discard;
	
	vec4 shadowColor = vec4(texture(tex,texcoord.xy).rgb * color.rgb,  texture2DLod(tex, texcoord.xy, 0).a);

	gl_FragData[0] = shadowColor;

  	#if defined Stochastic_Transparent_Shadows
		if(gl_FragData[0].a < blueNoise()) { discard; return;}
  	#endif
}
