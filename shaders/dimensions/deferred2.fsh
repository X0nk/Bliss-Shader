#include "/lib/settings.glsl"

uniform sampler2D depthtex0;
uniform sampler2D dhDepthTex;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex7;
uniform vec2 texelSize;


float interleaved_gradientNoise(){
	// vec2 coord = gl_FragCoord.xy + (frameCounter%40000);
	vec2 coord = gl_FragCoord.xy ;
	// vec2 coord = gl_FragCoord.xy;
	float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715)) );
	return noise ;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

	#if RESOURCEPACK_SKY != 0
	/* RENDERTARGETS:1,2 */
	#endif


void main() {

	ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
	float depth = texelFetch2D(depthtex0, pixelCoord, 0).x;
	gl_FragData[0] = texelFetch2D(colortex1, pixelCoord, 0);

	bool isSkyPixel = depth >= 1.0;
	#ifdef DISTANT_HORIZONS
		float dhDepth = texelFetch2D(dhDepthTex, pixelCoord, 0).x;
		isSkyPixel = isSkyPixel && dhDepth >= 1.0;
	#endif

#if RESOURCEPACK_SKY != 0
	vec4 forwardSample = texelFetch2D(colortex2, pixelCoord, 0);
	float translucentMask = texelFetch2D(colortex7, pixelCoord, 0).a;

	if(isSkyPixel){
		vec3 skyColor = forwardSample.rgb;
		skyColor.rgb = max(skyColor.rgb - skyColor.rgb * interleaved_gradientNoise()*0.05, 0.0);

		gl_FragData[0].rgb = skyColor/50.0;
		gl_FragData[0].a = 0.0;
	}
#endif

#if RESOURCEPACK_SKY != 0
	gl_FragData[1] = isSkyPixel ? vec4(0.0) : (translucentMask > 0.0 ? forwardSample : vec4(0.0));
#else
	gl_FragData[1] = vec4(0.0);
#endif

}
