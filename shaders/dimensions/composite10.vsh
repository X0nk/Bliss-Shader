#include "/lib/settings.glsl"

varying vec2 texcoord;

uniform sampler2D colortex4;

flat varying vec4 exposure;
flat varying vec2 rodExposureDepth;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;

	exposure = vec4(vec3(texelFetch2D(colortex4,ivec2(10,37),0).r),texelFetch2D(colortex4,ivec2(10,37),0).r);
	rodExposureDepth = texelFetch2D(colortex4,ivec2(14,37),0).rg;
	rodExposureDepth.y = sqrt(rodExposureDepth.y/65000.0);
}