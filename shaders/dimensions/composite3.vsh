#include "/lib/settings.glsl"

varying vec2 texcoord;
flat varying vec3 zMults;
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
const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);


#ifdef BorderFog
	uniform sampler2D colortex4;
	flat varying vec3 skyGroundColor;
#endif

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	#ifdef BorderFog
		skyGroundColor = texelFetch2D(colortex4,ivec2(1,37),0).rgb / 30.0;
	#endif

	#ifdef TAA
		TAA_Offset = offsets[framemod8];
	#else
		TAA_Offset = vec2(0.0);
	#endif

	float lightCola = float(sunElevation > 1e-5)*2.0 - 1.0;
	WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);

	zMults = vec3(1.0/(far * near),far+near,far-near);

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;

}
