#include "/lib/settings.glsl"

#include "/lib/macro_lod_mod.glsl"

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
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

	vec2 texcoord = gl_FragCoord.xy * texelSize;

	gl_FragData[0] = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);

	if(
		texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x < 1.0 
		
		#ifdef USING_LOD_MOD
			|| texelFetch(LOD_DEPTHTEX0, ivec2(gl_FragCoord.xy), 0).x < 1.0
		#endif

	) {
		// doing this for precision reasons, DH does NOT like depth => 1.0
	}else{
		
		vec3 skyColor = texelFetch(colortex2, ivec2(gl_FragCoord.xy),0).rgb;
		skyColor.rgb = max(skyColor.rgb - skyColor.rgb * interleaved_gradientNoise()*0.05, 0.0);

		gl_FragData[0].rgb = skyColor/50.0;
		gl_FragData[0].a = 0.0;

	}

	gl_FragData[1] = vec4(0,0,0,0);

}