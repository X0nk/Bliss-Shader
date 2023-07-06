#version 120
//#extension GL_EXT_gpu_shader4 : enable

#include "/lib/settings.glsl"

varying vec2 texcoord;
flat varying vec4 exposure;
flat varying float rodExposure;
uniform sampler2D colortex4;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
	exposure=vec4(texelFetch2D(colortex4,ivec2(10,37),0).r*vec3(FinalR,FinalG,FinalB),texelFetch2D(colortex4,ivec2(10,37),0).r);
	rodExposure = texelFetch2D(colortex4,ivec2(14,37),0).r;
}
