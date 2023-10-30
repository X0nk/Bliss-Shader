#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

varying vec4 color;
varying vec2 texcoord;

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

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}
					
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

uniform sampler2D colortex4;
flat varying float exposure;

void main() {
	color = gl_Color;

	#ifdef ENCHANT_GLINT
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	#else
		texcoord = (gl_MultiTexCoord0).xy;
	#endif

	#if defined ENCHANT_GLINT || defined SPIDER_EYES
		exposure = texelFetch2D(colortex4,ivec2(10,37),0).r;

		vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
		gl_Position = toClipSpace3(position);
	#else
		gl_Position = ftransform();
	#endif


	#ifdef BEACON_BEAM
		if(gl_Color.a < 1.0) gl_Position = vec4(10,10,10,0);
	#endif


	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
	#ifdef TAA
	    gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
	#endif
}
