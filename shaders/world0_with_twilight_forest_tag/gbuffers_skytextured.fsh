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

		vec4 COLOR = texture2D(texture, texcoord.xy) * color;

		bool isSun = renderStage == MC_RENDER_STAGE_SUN || renderStage == 4;
		bool isMoon = renderStage == MC_RENDER_STAGE_MOON || renderStage == 5;
		bool isSkyBox = (renderStage == MC_RENDER_STAGE_SKY || renderStage == MC_RENDER_STAGE_CUSTOM_SKY) || (renderStage == 1 || renderStage == 3);

		#if RESOURCEPACK_SKY == 1
			if(isMoon || isSun) { discard; return; }
		#endif

		#if RESOURCEPACK_SKY == 3
			if(isSkyBox) { discard; return; }
		#endif


		vec3 NEWCOLOR = COLOR.rgb;

		if(isSun) NEWCOLOR.rgb = COLOR.rgb * 10.0;
		if(isMoon) NEWCOLOR.rgb = COLOR.rgb * 5.0;
		if(isSkyBox) NEWCOLOR.rgb = COLOR.rgb * 2.0;

		NEWCOLOR.rgb = toLinear(NEWCOLOR.rgb);

		NEWCOLOR.rgb = max(NEWCOLOR.rgb - NEWCOLOR.rgb * interleaved_gradientNoise()*0.05, 0.0);
		
		gl_FragData[0] = vec4(NEWCOLOR.rgb*0.1, COLOR.a);
	#else
		discard;
	#endif
}
