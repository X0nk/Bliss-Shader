#version 120
#include "/lib/settings.glsl"

#if RESOURCEPACK_SKY != 0
	varying vec4 color;
	varying vec2 texcoord;
	uniform sampler2D texture;
	uniform sampler2D depthtex0;
	
	uniform int renderStage;
	uniform vec2 texelSize;

	float interleaved_gradientNoise(){
		// vec2 coord = gl_FragCoord.xy + (frameCounter%40000);
		vec2 coord = gl_FragCoord.xy ;
		// vec2 coord = gl_FragCoord.xy;
		float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715)) );
		return noise ;
	}

	vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
	}

#endif


void main() {

	#if RESOURCEPACK_SKY != 0
		/* RENDERTARGETS:2 */

		gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);
		vec4 COLOR = texture2D(texture, texcoord.xy);
		COLOR.rgb = toLinear(COLOR.rgb);
		COLOR *= color;

		#if RESOURCEPACK_SKY == 3
			if(renderStage == 1 || renderStage == 3) { discard; return; }
		#endif

		#if RESOURCEPACK_SKY == 1
			if(renderStage == 4 || renderStage == 5) { discard; return; }
		#else
			if(renderStage == 4 || renderStage == MC_RENDER_STAGE_SUN) COLOR.rgb *= 5.0;
		#endif

		COLOR.rgb = max(COLOR.rgb - COLOR.rgb * interleaved_gradientNoise()*0.05, 0.0);
		
		gl_FragData[0] = vec4(COLOR.rgb*0.1, COLOR.a);
	#else
		discard;
	#endif
}
