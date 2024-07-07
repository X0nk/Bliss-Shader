#include "/lib/settings.glsl"
//Computes volumetric clouds at variable resolution (default 1/4 res)


flat varying vec3 sunColor;
// flat varying vec3 moonColor;
flat varying vec3 averageSkyCol;

flat varying float tempOffsets;
// uniform float far;
uniform float near;
uniform sampler2D depthtex0;

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
#endif


// uniform sampler2D colortex4;
uniform sampler2D noisetex;

uniform sampler2D colortex12;

flat varying vec3 WsunVec;
uniform float sunElevation;
uniform vec3 sunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int frameCounter;
uniform int framemod8;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
// flat varying vec2 TAA_Offset;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)


vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}


#include "/lib/DistantHorizons_projections.glsl"

float R2_dither(){
	#ifdef TAA
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	#else

	vec2 coord = gl_FragCoord.xy;
	#endif
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}
float interleaved_gradientNoise(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	vec2 coord = vec2(alpha.x * gl_FragCoord.x,alpha.y * gl_FragCoord.y)+ 1.0/1.6180339887 * frameCounter;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}



#include "/lib/TAA_jitter.glsl"

float blueNoise(){
  #ifdef TAA
  	return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
  #else
 	return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a);
  #endif
}


vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}
uniform float far;


float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

uniform int dhRenderDistance;

#include "/lib/lightning_stuff.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/res_params.glsl"

#define CLOUDS_INTERSECT_TERRAIN
uniform float eyeAltitude;
#include "/lib/volumetricClouds.glsl"







//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////


void main() {
/* DRAWBUFFERS:0 */



	#if defined OVERWORLD_SHADER && defined VOLUMETRIC_CLOUDS && !defined  CLOUDS_INTERSECT_TERRAIN
		vec2 halfResTC = vec2(floor(gl_FragCoord.xy)/CLOUDS_QUALITY/RENDER_SCALE+0.5+offsets[framemod8]*CLOUDS_QUALITY*RENDER_SCALE*0.5);

		vec2 halfResTC2 = vec2(floor(gl_FragCoord.xy)/CLOUDS_QUALITY+0.5+offsets[framemod8]*CLOUDS_QUALITY*0.5);
		
		#ifdef CLOUDS_INTERSECT_TERRAIN
			float depth = texture2D(depthtex0, halfResTC2*texelSize).x;

			#ifdef DISTANT_HORIZONS
				float DH_depth =  texture2D(dhDepthTex, halfResTC2*texelSize).x;
				vec3 viewPos = toScreenSpace_DH(halfResTC*texelSize, depth, DH_depth);
			#else
				vec3 viewPos = toScreenSpace(vec3(halfResTC*texelSize, depth));
			#endif
		#else
			vec3 viewPos = toScreenSpace(vec3(halfResTC*texelSize, 1.0));
		#endif

		vec3 tesvar = vec3(0.0);
		vec4 VolumetricClouds = renderClouds(viewPos, vec2(R2_dither(), blueNoise()), sunColor/80.0, averageSkyCol/30.0,tesvar);

		gl_FragData[0] = VolumetricClouds;
	#else
		gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);
	#endif
}