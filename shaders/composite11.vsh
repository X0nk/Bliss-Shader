#version 120
#extension GL_EXT_gpu_shader4 : enable
#include "lib/settings.glsl"


varying vec2 texcoord;
flat varying vec4 exposure;
flat varying vec2 rodExposureDepth;
uniform sampler2D colortex4;

uniform vec2 texelSize;
uniform int framemod8;
const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {


	gl_Position = ftransform();


	texcoord = gl_MultiTexCoord0.xy;
	exposure=vec4(texelFetch2D(colortex4,ivec2(10,37),0).r*vec3(FinalR,FinalG,FinalB),texelFetch2D(colortex4,ivec2(10,37),0).r);
	rodExposureDepth = texelFetch2D(colortex4,ivec2(14,37),0).rg;
	rodExposureDepth.y = sqrt(rodExposureDepth.y/65000.0);
}
