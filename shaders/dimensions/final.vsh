#include "/lib/settings.glsl"

uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;

out vec2 texcoord;

flat out vec3 WsunVec;
flat out vec4 dailyWeatherParams0;
flat out vec4 dailyWeatherParams1;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;

	WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);

	#ifdef Daily_Weather
		dailyWeatherParams0 = vec4(texelFetch2D(colortex4,ivec2(1,1),0).rgb / 1500.0, 0.0);
		dailyWeatherParams1 = vec4(texelFetch2D(colortex4,ivec2(2,1),0).rgb / 1500.0, 0.0);
	#else
		dailyWeatherParams0 = vec4(CloudLayer0_coverage, CloudLayer1_coverage, CloudLayer2_coverage, 0.0);
		dailyWeatherParams1 = vec4(CloudLayer0_density, CloudLayer1_density, CloudLayer2_density, 0.0);
	#endif
}
