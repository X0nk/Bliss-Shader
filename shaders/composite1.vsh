#version 120
#extension GL_EXT_gpu_shader4 : enable
#include "lib/settings.glsl"

flat varying vec3 averageSkyCol_Clouds;
flat varying vec4 lightCol;

flat varying vec3 WsunVec;
flat varying float tempOffsets;
flat varying vec2 TAA_Offset;
flat varying vec3 zMults;

attribute vec4 mc_Entity;
uniform sampler2D colortex4;
varying vec4 lmtexcoord;
// varying float vanilla_ao;

uniform float far;
uniform float near;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float sunElevation;
uniform int frameCounter;

// uniform float sandStorm;

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);
float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

#include "/lib/util.glsl"
#include "/lib/res_params.glsl"





#define SEASONS_VSH
#include "/lib/climate_settings.glsl"

flat varying float WinterTimeForSnow;




void main() {
	gl_Position = ftransform();
	
	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	#endif

	tempOffsets = HaltonSeq2(frameCounter%10000);
	TAA_Offset = offsets[frameCounter%8];
	#ifndef TAA
	TAA_Offset = vec2(0.0);
	#endif

	averageSkyCol_Clouds = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
	// averageSkyCol = texelFetch2D(colortex4,ivec2(1,37),0).rgb;
	// sunColor = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
	// moonColor = texelFetch2D(colortex4,ivec2(13,37),0).rgb;


	vec3 sc = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
	lightCol.a = float(sunElevation > 1e-5)*2-1.;
	lightCol.rgb = sc;

	WsunVec = lightCol.a*normalize(mat3(gbufferModelViewInverse) *sunPosition);
	zMults = vec3((far * near)*2.0,far+near,far-near);


	WinterTimeForSnow = 0.0;
	
	#ifdef Seasons
		#ifdef Snowy_Winter
			vec3 color1 = vec3(0.0);
			vec3 color2 = color1;
			YearCycleColor(color1, color2, WinterTimeForSnow);
		#endif
	#endif
}
