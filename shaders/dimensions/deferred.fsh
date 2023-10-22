#include "/lib/settings.glsl"

#define ReflectedFog

flat varying vec3 averageSkyCol_Clouds;
flat varying vec3 averageSkyCol;

flat varying vec3 lightSourceColor;
flat varying vec3 sunColor;
flat varying vec3 moonColor;
// flat varying vec3 zenithColor;

// flat varying vec3 WsunVec;

flat varying vec2 tempOffsets;
flat varying float exposure;
flat varying float rodExposure;
flat varying float avgBrightness;
flat varying float exposureF;

uniform sampler2D noisetex;

uniform float frameTime;
uniform int frameCounter;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float eyeAltitude;
uniform vec3 sunVec;
uniform vec2 texelSize;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float sunElevation;
uniform vec3 cameraPosition;
// uniform float far;
uniform ivec2 eyeBrightnessSmooth;

vec4 lightCol = vec4(lightSourceColor, float(sunElevation > 1e-5)*2-1.);

#include "/lib/util.glsl"
#include "/lib/ROBOBO_sky.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/Shadow_Params.glsl"

vec3 WsunVec = mat3(gbufferModelViewInverse)*sunVec;
// vec3 WsunVec = normalize(LightDir);

vec3 toShadowSpaceProjected(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    p3 = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
    p3 = diagonal3(shadowProjection) * p3 + shadowProjection[3].xyz;

    return p3;
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)+frameCounter/1.6180339887);
	return noise;
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}


#ifdef OVERWORLD_SHADER
	// const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;
	#define TEST
	#define TIMEOFDAYFOG
	#include "/lib/lightning_stuff.glsl"
	#include "/lib/volumetricClouds.glsl"
	#include "/lib/overworld_fog.glsl"
	
#endif
#ifdef NETHER_SHADER
	uniform sampler2D colortex4;
	#include "/lib/nether_fog.glsl"
#endif
#ifdef END_SHADER
	uniform sampler2D colortex4;
	#include "/lib/end_fog.glsl"
#endif


void main() {
/* DRAWBUFFERS:4 */

gl_FragData[0] = vec4(0.0);
float mixhistory = 0.07;

#ifdef OVERWORLD_SHADER
	///////////////////////////////
	/// --- STORE COLOR LUT --- ///
	///////////////////////////////

	vec3 AmbientLightTint = vec3(AmbientLight_R, AmbientLight_G, AmbientLight_B);

	// --- the color of the atmosphere + the average color of the atmosphere.
	vec3 skyGroundCol = skyFromTex(vec3(0, -1 ,0), colortex4).rgb  ;

	/// --- Save light values
	if (gl_FragCoord.x < 1. && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
	gl_FragData[0] = vec4(averageSkyCol_Clouds * AmbientLightTint,1.0);

	if (gl_FragCoord.x > 1. && gl_FragCoord.x < 2.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
	gl_FragData[0] = vec4((skyGroundCol/150.0) * AmbientLightTint,1.0);

	#ifdef ambientLight_only
		if (gl_FragCoord.x > 6. && gl_FragCoord.x < 7.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);

		if (gl_FragCoord.x > 8. && gl_FragCoord.x < 9.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);

		if (gl_FragCoord.x > 13. && gl_FragCoord.x < 14.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(0.0,0.0,0.0,1.0);
	#else
		if (gl_FragCoord.x > 6. && gl_FragCoord.x < 7.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(lightSourceColor,1.0);

		if (gl_FragCoord.x > 8. && gl_FragCoord.x < 9.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(sunColor,1.0);
		
		if (gl_FragCoord.x > 13. && gl_FragCoord.x < 14.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
		gl_FragData[0] = vec4(moonColor,1.0);
	#endif
	

////////////////////////////////
/// --- ATMOSPHERE IMAGE --- ///
////////////////////////////////

/// --- Sky only
if (gl_FragCoord.x > 18. && gl_FragCoord.y > 1. && gl_FragCoord.x < 18+257){
	vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.,1.))/256.+tempOffsets/256.,0.0,1.0);
	vec3 viewVector = cartToSphere(p);

	vec2 planetSphere = vec2(0.0);
	vec3 sky = vec3(0.0);
	vec3 skyAbsorb = vec3(0.0);
	// vec3 WsunVec = mat3(gbufferModelViewInverse)*sunVec;
	// vec3 WsunVec = normalize(LightDir);

	sky = calculateAtmosphere(averageSkyCol*4000./2.0, viewVector, vec3(0.0,1.0,0.0), WsunVec, -WsunVec, planetSphere, skyAbsorb, 10, blueNoise());

	// sky = mix(sky, (averageSkyCol + skyAbsorb)*4000./2.0  ,(1.0 - exp(pow(clamp(-viewVector.y+0.5,0.0,1.0),2) * -25)));

	// fade atmosphere conditions for rain away when you pass above the cloud plane.
	float heightRelativeToClouds = clamp(1.0 - max(eyeAltitude - Cumulus_height,0.0) / 200.0 ,0.0,1.0);
	if(rainStrength > 0.0) sky = mix(sky, 3.0 + averageSkyCol*4000 * (skyAbsorb*0.7+0.3), clamp(1.0 - exp(pow(clamp(-viewVector.y+0.9,0.0,1.0),2) * -5.0),0.0,1.0) * heightRelativeToClouds * rainStrength);
	
	#ifdef AEROCHROME_MODE
		sky *= vec3(0.0, 0.18, 0.35);
	#endif

  gl_FragData[0] = vec4(sky / 4000.0 * Sky_Brightness, 1.0);
}

/// --- Sky + clouds + fog 
if (gl_FragCoord.x > 18.+257. && gl_FragCoord.y > 1. && gl_FragCoord.x < 18+257+257.){
	vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.+257,1.))/256.+tempOffsets/256.,0.0,1.0);
	vec3 viewVector = cartToSphere(p);

	// vec3 WsunVec = mat3(gbufferModelViewInverse)*sunVec;
	// vec3 WsunVec = normalize(LightDir);
	vec3 sky = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy)-ivec2(257,0),0).rgb/150.0;	

	if(viewVector.y < -0.025) sky = sky * clamp( exp(viewVector.y) - 1.0,0.25,1.0) ;

	vec4 clouds = renderClouds(mat3(gbufferModelView)*viewVector*1024.,vec2(fract(frameCounter/1.6180339887),1-fract(frameCounter/1.6180339887)), sunColor, moonColor, skyGroundCol/30.0);
	sky = sky*clouds.a + clouds.rgb / 5.0; 

	vec4 VL_Fog = GetVolumetricFog(mat3(gbufferModelView)*viewVector*1024.,  fract(frameCounter/1.6180339887), lightSourceColor*1.75, skyGroundCol/30.0);
	sky = sky * VL_Fog.a + VL_Fog.rgb / 5.0;

	gl_FragData[0] = vec4(sky,1.0);

}
#endif

#if defined NETHER_SHADER || defined END_SHADER || defined FALLBACK_SHADER
	vec2 fogPos = vec2(256.0 - 256.0*0.12,1.0);

	//Sky gradient with clouds
	if (gl_FragCoord.x > (fogPos.x - fogPos.x*0.22) && gl_FragCoord.y > 0.4 && gl_FragCoord.x < 535){
		vec2 p = clamp(floor(gl_FragCoord.xy-fogPos)/256.+tempOffsets/256.,-0.2,1.2);
		vec3 viewVector = cartToSphere(p);

	 	vec3 BackgroundColor = vec3(0.0);

		vec4 VL_Fog = GetVolumetricFog(mat3(gbufferModelView)*viewVector*256.,  fract(frameCounter/1.6180339887), fract(frameCounter/2.6180339887));

		BackgroundColor += VL_Fog.rgb/5.0;

	  	gl_FragData[0] = vec4(BackgroundColor, 1.0);

	}
#endif


	// /* ---------------------- FOG SHADER ---------------------- */
	// vec2 fogPos = vec2(256.0 - 256.0*0.12,1.0);
	
	// //Sky gradient with clouds
	// if (gl_FragCoord.x > (fogPos.x - fogPos.x*0.22) && gl_FragCoord.y > 0.4 && gl_FragCoord.x < 535){
	// 	vec2 p = clamp(floor(gl_FragCoord.xy-fogPos)/256.+tempOffsets/256.,-0.2,1.2);
	// 	vec3 viewVector = cartToSphere(p);
	
	//  	vec3 BackgroundColor = vec3(0.0);
	
	// 	vec4 VL_Fog = GetVolumetricFog(mat3(gbufferModelView)*viewVector*256.,  fract(frameCounter/1.6180339887), fract(frameCounter/2.6180339887));
		
	// 	BackgroundColor += VL_Fog.rgb/5.0;
	
	//   	gl_FragData[0] = vec4(BackgroundColor, 1.0);
	
	// }

#ifdef END_SHADER
	/* ---------------------- TIMER ---------------------- */

	float flash = 0.0;
	float maxWaitTime = 10;

	float Timer = texelFetch2D(colortex4, ivec2(3,1), 0).x/150.0;
	Timer -= frameTime;

	if(Timer <= 0.0){
		flash = 1.0;

		Timer = pow(hash11(frameCounter), 5) * maxWaitTime;
	}

	vec2 pixelPos0 = vec2(3,1);
	if (gl_FragCoord.x > pixelPos0.x && gl_FragCoord.x < pixelPos0.x + 1 && gl_FragCoord.y > pixelPos0.y && gl_FragCoord.y < pixelPos0.y + 1){
		mixhistory = 1.0;
		gl_FragData[0] = vec4(Timer, 0.0, 0.0, 1.0);
	}

	/* ---------------------- FLASHING ---------------------- */

	vec2 pixelPos1 = vec2(1,1);
	if (gl_FragCoord.x > pixelPos1.x && gl_FragCoord.x < pixelPos1.x + 1 && gl_FragCoord.y > pixelPos1.y && gl_FragCoord.y < pixelPos1.y + 1){
		mixhistory = clamp(5.0 * frameTime,0.0,1.0);
		gl_FragData[0] = vec4(flash, 0.0, 0.0, 1.0);
	}

	/* ---------------------- POSITION ---------------------- */

	vec2 pixelPos2 = vec2(2,1);
	if (gl_FragCoord.x > pixelPos2.x && gl_FragCoord.x < pixelPos2.x + 1 && gl_FragCoord.y > pixelPos2.y && gl_FragCoord.y < pixelPos2.y + 1){
		mixhistory = clamp(500.0 * frameTime,0.0,1.0);

		vec3 LastPos = (texelFetch2D(colortex4,ivec2(2,1),0).xyz/150.0) * 2.0 - 1.0;
		
		LastPos += (hash31(frameCounter / 75) * 2.0 - 1.0);
		LastPos = LastPos * 0.5 + 0.5;

		if(Timer > maxWaitTime * 0.7 ){ 
			LastPos = vec3(0.0);
		}

		gl_FragData[0] = vec4(LastPos, 1.0);
	}

#endif




//Temporally accumulate sky and light values
vec3 temp = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy),0).rgb;
vec3 curr = gl_FragData[0].rgb*150.;
gl_FragData[0].rgb = clamp(mix(temp, curr, mixhistory),0.0,65000.);

//Exposure values
if (gl_FragCoord.x > 10. && gl_FragCoord.x < 11.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(exposure,avgBrightness,exposureF,1.0);
if (gl_FragCoord.x > 14. && gl_FragCoord.x < 15.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(rodExposure,0.0,0.0,1.0);

}