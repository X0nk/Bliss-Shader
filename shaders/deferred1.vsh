#version 120
#extension GL_EXT_gpu_shader4 : enable
#include "lib/settings.glsl"


flat varying vec3 sunColor;
flat varying vec3 moonColor;
flat varying vec4 lightCol;
flat varying vec3 avgAmbient;
flat varying float tempOffsets;

flat varying vec3 WsunVec;
flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float sunElevation;

uniform sampler2D colortex4;
uniform int frameCounter;
#include "/lib/util.glsl"
#include "/lib/res_params.glsl"
void main() {

	// TAA_Offset = offsets[frameCounter%8];
	// #ifndef TAA
	// TAA_Offset = vec2(0.0);
	// #endif

	tempOffsets = HaltonSeq2(frameCounter%10000);
	gl_Position = ftransform();
	gl_Position.xy = (gl_Position.xy*0.5+0.5)*clamp(CLOUDS_QUALITY+0.01,0.0,1.0)*2.0-1.0;
	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	#endif
	sunColor = texelFetch2D(colortex4,ivec2(12,37),0).rgb;
	moonColor = texelFetch2D(colortex4,ivec2(13,37),0).rgb;
	// avgAmbient = texelFetch2D(colortex4,ivec2(11,37),0).rgb;
	
	vec3 sc = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
	lightCol.a = float(sunElevation > 1e-5)*2-1.;
	lightCol.rgb = sc;

	WsunVec = lightCol.a*normalize(mat3(gbufferModelViewInverse) *sunPosition);

	// ambientUp = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
	// ambientDown = texelFetch2D(colortex4,ivec2(1,37),0).rgb;
	// ambientLeft = texelFetch2D(colortex4,ivec2(2,37),0).rgb;
	// ambientRight = texelFetch2D(colortex4,ivec2(3,37),0).rgb;
	// ambientB = texelFetch2D(colortex4,ivec2(4,37),0).rgb;
	// ambientF = texelFetch2D(colortex4,ivec2(5,37),0).rgb;

	avgAmbient = texelFetch2D(colortex4,ivec2(1,37),0).rgb;
}
