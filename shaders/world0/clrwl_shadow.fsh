#version 330 compatibility

#define DIRECT_LIGHT_RELATED_SETTINGS
#define SHADOWMAP_CONSTANT_RELATED_SETTINGS
#include "/lib/settings.glsl"

varying vec4 color;
varying vec2 texcoord;
uniform sampler2D gtexture;
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
	
	vec4 shadowColor = vec4(texture(gtexture,texcoord.xy).rgb * color.rgb,  texture2DLod(gtexture, texcoord.xy, 0).a);
    vec2 lmcoord;
    float ao;
    vec4 overlayColor;

    clrwl_computeFragment(shadowColor, shadowColor, lmcoord, ao, overlayColor);

	gl_FragData[0] = shadowColor;

  	#if defined Stochastic_Transparent_Shadows
		if(gl_FragData[0].a < blueNoise()) { discard; return;}
  	#endif
}
