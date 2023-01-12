#version 120
#extension GL_EXT_gpu_shader4 : enable


//Prepares sky textures (2 * 256 * 256), computes light values and custom lightmaps
#define Ambient_Mult 1.0 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.5 2.0 3.0 4.0 5.0 6.0 10.0]
#define Sky_Brightness 1.0 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.5 2.0 3.0 4.0 5.0 6.0 10.0]

#define MIN_LIGHT_AMOUNT 1.0 //[0.0 0.5 1.0 1.5 2.0 3.0 4.0 5.0]
#define TORCH_AMOUNT 1.0 //[0.0 0.5 0.75 1. 1.2 1.4 1.6 1.8 2.0]
#define TORCH_R 1.0 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define TORCH_G 0.75 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define TORCH_B 0.5 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define ambient_temp 9000 // [1000 2000 3000 4000 5000 6000 7000 8000 9000 10000 15000 50000]


flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;
flat varying float avgL2;
flat varying vec3 lightSourceColor;
flat varying vec3 sunColor;
flat varying vec3 sunColorCloud;
flat varying vec3 moonColor;
flat varying vec3 moonColorCloud;
flat varying vec3 zenithColor;
flat varying vec3 avgSky;
flat varying vec2 tempOffsets;
flat varying float exposure;
flat varying float rodExposure;
flat varying float avgBrightness;
flat varying float exposureF;
flat varying float fogAmount;
flat varying float VFAmount;
flat varying float centerDepth;

// uniform sampler2D colortex4;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow;

uniform int frameCounter;
uniform float rainStrength;
uniform float eyeAltitude;
uniform float nightVision;
uniform vec3 sunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float sunElevation;
uniform vec3 cameraPosition;
uniform float far;
uniform ivec2 eyeBrightnessSmooth;

#include "lib/Shadow_Params.glsl"
#include "/lib/util.glsl"
#include "/lib/ROBOBO_sky.glsl"
#include "lib/sky_gradient.glsl"

#define TIMEOFDAYFOG
#include "lib/volumetricClouds.glsl"

// #include "lib/biome_specifics.glsl"

vec3 toShadowSpaceProjected(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    p3 = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
    p3 = diagonal3(shadowProjection) * p3 + shadowProjection[3].xyz;

    return p3;
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter);
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
vec4 lightCol = vec4(lightSourceColor, float(sunElevation > 1e-5)*2-1.);
#include "lib/volumetricFog.glsl"
const float[17] Slightmap = float[17](14.0,17.,19.0,22.0,24.0,28.0,31.0,40.0,60.0,79.0,93.0,110.0,132.0,160.0,197.0,249.0,249.0);

void main() {
/* DRAWBUFFERS:4 */
gl_FragData[0] = vec4(0.0);
float minLight = (MIN_LIGHT_AMOUNT + nightVision*5) * 0.007/ (exposure + rodExposure/(rodExposure+1.0)*exposure*1.);
// vec3 minLight_col = MIN_LIGHT_AMOUNT * 0.007/ (exposure + rodExposure/(rodExposure+1.0)*exposure*1.)    * vec3(0.8,0.9,1.0);
//Lightmap for forward shading (contains average integrated sky color across all faces + torch + min ambient)
vec3 avgAmbient = (ambientUp + ambientLeft + ambientRight + ambientB + ambientF + ambientDown)/6.;

// avgAmbient *= blackbody(ambient_temp);

if (gl_FragCoord.x < 17. && gl_FragCoord.y < 17.){
  float torchLut = clamp(16.0-gl_FragCoord.x,0.5,15.5);
  torchLut = torchLut+0.712;
  float torch_lightmap = max(1.0/torchLut/torchLut - 1/17.212/17.212,0.0);
  torch_lightmap = pow(torch_lightmap*2.5,1.5)*TORCH_AMOUNT*10.;
  float sky_lightmap = (Slightmap[int(gl_FragCoord.y)]-14.0)/235.;
  sky_lightmap = pow(sky_lightmap,1.4);
  vec3 ambient = (ambientUp * blackbody(ambient_temp))*sky_lightmap+torch_lightmap*vec3(TORCH_R,TORCH_G,TORCH_B)*TORCH_AMOUNT;
  
  gl_FragData[0] = vec4(max(ambient*Ambient_Mult,minLight/5),1.0);
}

//Lightmap for deferred shading (contains only torch + min ambient)
if (gl_FragCoord.x < 17. && gl_FragCoord.y > 19. && gl_FragCoord.y < 19.+17. ){
	float torchLut = clamp(16.0-gl_FragCoord.x,0.5,15.5);
  torchLut = torchLut+0.712;
  float torch_lightmap = max(1.0/torchLut/torchLut - 1/17.212/17.212,0.0);
  float ambient = pow(torch_lightmap*2.5,1.5)*TORCH_AMOUNT*10.;
  float sky_lightmap = (Slightmap[int(gl_FragCoord.y-19.0)]-14.0)/235./150.;
  
  gl_FragData[0] = vec4(sky_lightmap,ambient,minLight,1.0)*Ambient_Mult;
}

//Save light values
if (gl_FragCoord.x < 1. && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(ambientUp * blackbody(ambient_temp),1.0);
if (gl_FragCoord.x > 1. && gl_FragCoord.x < 2.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(ambientUp,1.0);
if (gl_FragCoord.x > 2. && gl_FragCoord.x < 3.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(ambientLeft,1.0);
if (gl_FragCoord.x > 3. && gl_FragCoord.x < 4.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(ambientRight,1.0);
if (gl_FragCoord.x > 4. && gl_FragCoord.x < 5.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(ambientB,1.0);
if (gl_FragCoord.x > 5. && gl_FragCoord.x < 6.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(ambientF,1.0);
if (gl_FragCoord.x > 6. && gl_FragCoord.x < 7.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(lightSourceColor,1.0);
if (gl_FragCoord.x > 7. && gl_FragCoord.x < 8.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(avgAmbient,1.0);
if (gl_FragCoord.x > 8. && gl_FragCoord.x < 9.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(sunColor,1.0);
if (gl_FragCoord.x > 9. && gl_FragCoord.x < 10.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(moonColor,1.0);
if (gl_FragCoord.x > 11. && gl_FragCoord.x < 12.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(avgSky,1.0);
if (gl_FragCoord.x > 12. && gl_FragCoord.x < 13.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(sunColorCloud,1.0);
if (gl_FragCoord.x > 13. && gl_FragCoord.x < 14.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(moonColorCloud,1.0);
//Sky gradient (no clouds)
const float pi = 3.141592653589793238462643383279502884197169;
if (gl_FragCoord.x > 18. && gl_FragCoord.y > 1. && gl_FragCoord.x < 18+257){
  vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.,1.))/256.+tempOffsets/256.,0.0,1.0);
  vec3 viewVector = cartToSphere(p);

	vec2 planetSphere = vec2(0.0);
	vec3 sky = vec3(0.0);
	vec3 skyAbsorb = vec3(0.0);
  vec3 WsunVec = mat3(gbufferModelViewInverse)*sunVec;
	sky = calculateAtmosphere(avgSky*4000./2.0, viewVector, vec3(0.0,1.0,0.0), WsunVec, -WsunVec, planetSphere, skyAbsorb, 10, blueNoise());

  sky = mix(sky, vec3(0.5,0.5,0.5)*avgSky * 4000., clamp(1 - viewVector.y,0.0,1.0) * rainStrength  );
  // sky *= max(abs(viewVector.y+0.05),0.25);
  gl_FragData[0] = vec4(sky/4000.*Sky_Brightness,1.0);
}

//Sky gradient with clouds
if (gl_FragCoord.x > 18.+257. && gl_FragCoord.y > 1. && gl_FragCoord.x < 18+257+257.){
	vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.+257,1.))/256.+tempOffsets/256.,0.0,1.0);
	vec3 viewVector = cartToSphere(p);
	vec4 clouds = renderClouds(mat3(gbufferModelView)*viewVector*1024.,vec3(0.), blueNoise(),sunColorCloud,moonColor,ambientUp,blueNoise());
  mat2x3 vL = getVolumetricRays(fract(frameCounter/1.6180339887),mat3(gbufferModelView)*viewVector*1024.);
  float absorbance = dot(vL[1],vec3(0.22,0.71,0.07));
  vec3 skytex = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy)-ivec2(257,0),0).rgb/150.;

  if(viewVector.y < -0.025) skytex = skytex * clamp( exp(viewVector.y - 1.0),0.,1.) ;
  
  skytex = skytex*clouds.a + clouds.rgb;

	// gl_FragData[0] = vec4(skytex,1.0);
	gl_FragData[0] = vec4(skytex*absorbance+vL[0].rgb,1.0);
}

//Temporally accumulate sky and light values
vec3 temp = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy),0).rgb;
vec3 curr = gl_FragData[0].rgb*150.;
gl_FragData[0].rgb = clamp(mix(temp,curr,0.06),0.0,65000.);

//Exposure values
if (gl_FragCoord.x > 10. && gl_FragCoord.x < 11.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(exposure,avgBrightness,avgL2,1.0);
if (gl_FragCoord.x > 14. && gl_FragCoord.x < 15.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(rodExposure,centerDepth,0.0, 1.0);

}
