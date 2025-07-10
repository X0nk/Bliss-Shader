#version 120

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/
#include "/lib/settings.glsl"

#define SHADOW_MAP_BIAS 0.5
const float PI = 3.1415927;
varying vec2 texcoord;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

flat varying int water;




#include "/lib/Shadow_Params.glsl"

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

// uniform float far;
uniform float dhFarPlane;

#include "/lib/DistantHorizons_projections.glsl"

vec4 toClipSpace3(vec3 viewSpacePosition) {

	// mat4 projection = DH_shadowProjectionTweak(gl_ProjectionMatrix);

    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),1.0);
}



varying float overdrawCull;
// uniform int renderStage;

void main() {
    water = 0;

    if(gl_Color.a < 1.0) water = 1;

	texcoord.xy = gl_MultiTexCoord0.xy;

	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
	#ifdef DH_OVERDRAW_PREVENTION
  		vec3 worldpos = mat3(shadowModelViewInverse) * position + shadowModelViewInverse[3].xyz;
		overdrawCull = 1.0 - clamp(1.0 - length(worldpos) / far,0.0,1.0);
	#else
		overdrawCull = 1.0;
	#endif

	#ifdef DISTORT_SHADOWMAP
		gl_Position = BiasShadowProjection(toClipSpace3(position));
	#else
		gl_Position = toClipSpace3(position);
	#endif

  	gl_Position.z /= 6.0;
}