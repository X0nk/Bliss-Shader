#include "/lib/settings.glsl"

varying vec2 texcoord;
flat varying vec3 zMults;

#ifdef BorderFog
	uniform sampler2D colortex4;
	flat varying vec3 skyGroundColor;
#endif

flat varying vec3 WsunVec;

uniform float far;
uniform float near;
uniform float dhFarPlane;
uniform float dhNearPlane;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float sunElevation;
flat varying vec2 TAA_Offset;
uniform int framemod8;
#include "/lib/TAA_jitter.glsl"



#ifdef OVERWORLD_SHADER

#endif
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	#ifdef OVERWORLD_SHADER
		#ifdef BorderFog
			skyGroundColor = texelFetch2D(colortex4,ivec2(1,37),0).rgb / 30.0 * Sky_Brightness;
		#endif
		WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	#endif

	#ifdef TAA
		TAA_Offset = offsets[framemod8];
	#else
		TAA_Offset = vec2(0.0);
	#endif
	zMults = vec3(1.0/(far * near),far+near,far-near);

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
}
