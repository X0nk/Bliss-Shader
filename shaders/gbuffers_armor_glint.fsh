#version 120
//#extension GL_EXT_gpu_shader4 : enable
#include "lib/settings.glsl"

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;


uniform sampler2D texture;
uniform sampler2D gaux1;
uniform vec4 lightCol;
uniform vec3 sunVec;

uniform vec2 texelSize;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform float sunElevation;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

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


	gl_FragData[0] = texture2D(texture, lmtexcoord.xy);

	vec3 albedo = toLinear(gl_FragData[0].rgb*color.rgb);

	float exposure = texelFetch2D(gaux1,ivec2(10,37),0).r;

	vec3 col = albedo*exp(-exposure*4.) * 255.0;

	gl_FragData[0].rgb = col*color.a;
	gl_FragData[0].a = gl_FragData[0].a*0.1;
}
