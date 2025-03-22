#include "/lib/settings.glsl"

uniform sampler2D depthtex0;
uniform sampler2D dhDepthTex;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform vec2 texelSize;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

#if defined OVERWORLD_SHADER
	/* RENDERTARGETS:1,2 */
#endif

void main() {

	vec2 texcoord = gl_FragCoord.xy * texelSize;

	gl_FragData[0] = texelFetch2D(colortex1, ivec2(gl_FragCoord.xy),0);

	if(texelFetch2D(depthtex0, ivec2(gl_FragCoord.xy), 0).x < 1.0 || texelFetch2D(dhDepthTex, ivec2(gl_FragCoord.xy), 0).x < 1.0) {
		// doing this for precision reasons, DH does NOT like depth => 1.0
	}else{

		gl_FragData[0].rgb = texelFetch2D(colortex2, ivec2(gl_FragCoord.xy),0).rgb * 10.0;
		gl_FragData[0].a = 0.0;

	}

	gl_FragData[1] = vec4(0,0,0,0);

}