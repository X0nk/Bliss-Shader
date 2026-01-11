#define ANTIALIASING_RELATED_SETTINGS
#define SHADOWMAP_CONSTANT_RELATED_SETTINGS
#include "/lib/settings.glsl"
#include "/lib/util.glsl"
#include "/lib/res_params.glsl"

flat varying vec4 lightCol;
flat varying vec3 averageSkyCol;
flat varying vec3 averageSkyCol_Clouds;

#include "/lib/scene_controller.glsl"


flat varying vec3 WsunVec;
flat varying vec3 refractedSunVec;

uniform vec2 texelSize;

uniform sampler2D colortex4;

uniform float sunElevation;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform mat4 gbufferModelViewInverse;
uniform int frameCounter;

uniform float frameTimeCounter;
#include "/lib/Shadow_Params.glsl"
#include "/lib/sky_gradient.glsl"


//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	gl_Position = ftransform();

	gl_Position.xy = (gl_Position.xy*0.5+0.5)*(0.01+VL_RENDERING_RESOLUTION_SCALE)*2.0-1.0;

	
	#ifdef OVERWORLD_SHADER
		lightCol.rgb = texelFetch(colortex4,ivec2(6,37),0).rgb;
		averageSkyCol = texelFetch(colortex4,ivec2(1,37),0).rgb;
		averageSkyCol_Clouds = texelFetch(colortex4,ivec2(0,37),0).rgb;

		#define READ_SCENE_CONTROLLER_PARAMETERS
		#include "/lib/scene_controller.glsl"
		// readSceneControllerParameters(colortex4, parameters.smallCumulus, parameters.largeCumulus, parameters.altostratus, parameters.fog);
	#endif

	#ifdef NETHER_SHADER
		lightCol.rgb = vec3(0.0);
		averageSkyCol = vec3(0.0);
		averageSkyCol_Clouds = vec3(0.0);
	#endif

	#ifdef END_SHADER
		lightCol.rgb = vec3(0.0);
		averageSkyCol = vec3(0.0);
		averageSkyCol_Clouds = vec3(5.0);
	#endif

	lightCol.a = float(sunElevation > 1e-5)*2.0 - 1.0;
	WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);

	vec3 moonVec = normalize(mat3(gbufferModelViewInverse) * moonPosition);
	vec3 WmoonVec = moonVec;
	if(dot(-moonVec, WsunVec) < 0.9999) WmoonVec = -moonVec;

	WsunVec = mix(WmoonVec, WsunVec, clamp(lightCol.a,0,1));

	refractedSunVec = refract(lightCol.a*WsunVec, -vec3(0.0,1.0,0.0), 1.0/1.33333);
}