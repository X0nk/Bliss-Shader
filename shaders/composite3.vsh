#version 120
#extension GL_EXT_gpu_shader4 : disable

#include "lib/settings.glsl"
flat varying vec4 lightCol;
flat varying vec3 WsunVec;

uniform mat4 gbufferModelViewInverse;
uniform int frameCounter;
uniform vec3 sunPosition;
uniform float sunElevation;

flat varying vec2 TAA_Offset;
uniform sampler2D colortex4;
flat varying vec3 zMults;
uniform float far;
uniform float near;
#include "/lib/res_params.glsl"
const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);

							
flat varying vec3 noooormal;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	zMults = vec3(1.0/(far * near),far+near,far-near);
	gl_Position = ftransform();
	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	#endif
		TAA_Offset = offsets[frameCounter%8];

	#ifndef TAA
		TAA_Offset = vec2(0.0);
	#endif

	vec3 sc = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
	lightCol.a = float(sunElevation > 1e-5)*2-1.;
	lightCol.rgb = sc;

	WsunVec = lightCol.a*normalize(mat3(gbufferModelViewInverse) *sunPosition);

	vec3 noooormal = normalize(gl_NormalMatrix * gl_Normal);
}
