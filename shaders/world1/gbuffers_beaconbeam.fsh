#version 120

#include "/lib/settings.glsl"

varying vec4 lmtexcoord;
varying vec2 texcoord;
varying vec4 color;
uniform sampler2D texture;

//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* DRAWBUFFERS:28 */

void main() {

	vec4 Albedo = texture2D(texture, texcoord.xy) * color * 1.5;
    
    gl_FragData[0] = vec4(toLinear(Albedo.rgb), 1.0);
    gl_FragData[1] = vec4(0.0, 0.0, 0.0, 0.5);

}
