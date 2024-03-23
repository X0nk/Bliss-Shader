#version 120
//#extension GL_ARB_shader_texture_lod : disable

#include "/lib/settings.glsl"


varying vec2 texcoord;
uniform sampler2D tex;
uniform sampler2D noisetex;
uniform int frameCounter;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
varying vec4 color;

#include "/lib/waterBump.glsl"
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 );
}


void main() {
	gl_FragData[0] = texture2D(tex,texcoord.xy) * color;

	
	
	#ifdef SHADOW_DISABLE_ALPHA_MIPMAPS
		gl_FragData[0].a = texture2DLod(tex, texcoord.xy, 0).a;
	#endif

  	#ifdef Stochastic_Transparent_Shadows
		if(gl_FragData[0].a < blueNoise()) { discard; return;}
  	#endif

	#ifdef RENDER_ENTITY_SHADOWS
	#endif

	// if(materials > 0.95){
	// 	// gl_FragData[0] = vec4(0.3,0.8,1.0,0.1);
	// 	gl_FragData[0] = vec4(1.0,1.0,1.0,0.1);
	// }
}
