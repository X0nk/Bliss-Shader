#include "/lib/settings.glsl"

flat varying vec3 dailyWeatherParams0;
flat varying vec3 dailyWeatherParams1;
flat varying vec3 averageSkyCol;
flat varying vec3 sunColor;
// flat varying vec3 moonColor;


flat varying float tempOffsets;
flat varying vec3 WsunVec;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float sunElevation;

uniform sampler2D colortex4;
uniform int frameCounter;
uniform float frameTimeCounter;

#include "/lib/util.glsl"
#include "/lib/res_params.glsl"

#include "/lib/Shadow_Params.glsl"

void main() {

	gl_Position = ftransform();
	gl_Position.xy = (gl_Position.xy*0.5+0.5)*clamp(CLOUDS_QUALITY+0.01,0.0,1.0)*2.0-1.0;

	dailyWeatherParams0 = texelFetch2D(colortex4,ivec2(1,1),0).rgb/150.0;
	dailyWeatherParams1 = texelFetch2D(colortex4,ivec2(2,1),0).rgb/150.0;

	averageSkyCol = texelFetch2D(colortex4,ivec2(1,37),0).rgb;
	sunColor = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
	// moonColor = texelFetch2D(colortex4,ivec2(13,37),0).rgb;
	
	// sunColor = texelFetch2D(colortex4,ivec2(8,37),0).rgb;
	// moonColor = texelFetch2D(colortex4,ivec2(9,37),0).rgb;
	

	WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition) * (float(sunElevation > 1e-5)*2.0-1.0);
	// WsunVec = normalize(LightDir);

	tempOffsets = HaltonSeq2(frameCounter%10000);
	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	#endif
}