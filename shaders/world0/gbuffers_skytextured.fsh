#version 120
#include "/lib/settings.glsl"

#if RESOURCEPACK_SKY != 0
	varying vec4 color;
	varying vec2 texcoord;
	uniform sampler2D texture;
	
	uniform int renderStage;

	float interleaved_gradientNoise(){
		// vec2 coord = gl_FragCoord.xy + (frameCounter%40000);
		vec2 coord = gl_FragCoord.xy ;
		// vec2 coord = gl_FragCoord.xy;
		float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715)) );
		return noise ;
	}
#endif

void main() {

	#if RESOURCEPACK_SKY != 0
		/* RENDERTARGETS:10 */

		vec4 COLOR = texture2D(texture, texcoord.xy)*color;

		if(renderStage == 4) COLOR.rgb *= 5.0;
		// if(renderStage == 5) COLOR.rgb *= 1.5;

		COLOR.rgb = max(COLOR.rgb * (0.9+0.1*interleaved_gradientNoise()), 0.0);
		
		gl_FragData[0] = vec4(COLOR.rgb/255.0, COLOR.a);
	#else
		discard;
	#endif
}
