#include "/lib/settings.glsl"
#include "/lib/util.glsl"

flat varying vec4 lightCol;
flat varying vec3 averageSkyCol;

flat varying vec3 WsunVec;
flat varying vec3 refractedSunVec;

flat varying float tempOffsets;

uniform sampler2D colortex4;

uniform float sunElevation;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
uniform int frameCounter;



//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////


#include "/lib/Shadow_Params.glsl"
void main() {
	gl_Position = ftransform();

	gl_Position.xy = (gl_Position.xy*0.5+0.5)*0.51*2.0-1.0;
	
	tempOffsets = HaltonSeq2(frameCounter%10000);

	averageSkyCol = texelFetch2D(colortex4,ivec2(1,37),0).rgb;
	
	lightCol.a = float(sunElevation > 1e-5)*2.0 - 1.0;
	lightCol.rgb = texelFetch2D(colortex4,ivec2(6,37),0).rgb;

	WsunVec = lightCol.a * normalize(mat3(gbufferModelViewInverse) * sunPosition);
	// WsunVec = normalize(LightDir);
	
	refractedSunVec = refract(WsunVec, -vec3(0.0,1.0,0.0), 1.0/1.33333);
}
