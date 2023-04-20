#version 120


varying vec4 color;
varying vec2 texcoord;

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
/* DRAWBUFFERS:18 */

void main() {

	vec3 albedo = (texture2D(texture, texcoord).rgb * color.rgb);
   
    gl_FragData[0].rgb = albedo;
   
   gl_FragData[1].a = 0.5;
}