#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "lib/settings.glsl"

varying vec4 lmtexcoord;
varying vec4 color;

uniform sampler2D texture;
uniform sampler2D gaux1;

//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* DRAWBUFFERS:2 */
void main() {

	vec4 Albedo = texture2D(texture, lmtexcoord.xy)*color;
	Albedo.a = 1.0;

	float exposure = texelFetch2D(gaux1,ivec2(10,37),0).r;
	Albedo.rgb *= 25.0 ;
	Albedo.rgb *= clamp(0.5-exposure,0.05,1.0);


	gl_FragData[0] = Albedo;

}