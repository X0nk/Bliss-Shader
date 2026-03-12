#define ANTIALIASING_RELATED_SETTINGS
#define SKY_RELATED_SETTINGS
#define DISTANCE_BASED_FOG_RELATED_SETTINGS
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



//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	#ifdef OVERWORLD_SHADER
		#ifdef BorderFog
			skyGroundColor = texelFetch(colortex4,ivec2(1,37),0).rgb / 1200.0 * Sky_Brightness;
		#endif
		WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	#endif

	zMults = vec3(1.0/(far * near),far+near,far-near);

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
}
