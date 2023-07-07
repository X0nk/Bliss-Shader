#version 120
//#extension GL_EXT_gpu_shader4 : disable
#include "/lib/settings.glsl"

flat varying vec3 averageSkyCol_Clouds;
flat varying vec3 sunColor;
flat varying vec3 moonColor;


flat varying float tempOffsets;
flat varying vec3 WsunVec;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float sunElevation;

uniform sampler2D colortex4;
uniform int frameCounter;

#include "/lib/util.glsl"
#include "/lib/res_params.glsl"

void main() {


	tempOffsets = HaltonSeq2(frameCounter%10000);
	gl_Position = ftransform();
	gl_Position.xy = (gl_Position.xy*0.5+0.5)*clamp(CLOUDS_QUALITY+0.01,0.0,1.0)*2.0-1.0;

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	#endif

	averageSkyCol_Clouds = texelFetch2D(colortex4,ivec2(1,37),0).rgb;
	sunColor = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
	moonColor = texelFetch2D(colortex4,ivec2(13,37),0).rgb;

	WsunVec = ( float(sunElevation > 1e-5)*2-1. )*normalize(mat3(gbufferModelViewInverse) *sunPosition);

}
