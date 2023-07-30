#version 120
//#extension GL_EXT_gpu_shader4 : disable


#include "/lib/settings.glsl"

flat varying vec2 tempOffsets;

flat varying float exposure;
flat varying float avgBrightness;
flat varying float rodExposure;
flat varying float avgL2;
flat varying float centerDepth;

uniform sampler2D colortex4;
uniform sampler2D noisetex;

uniform int frameCounter;
uniform float rainStrength;
uniform float eyeAltitude;
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


#include "/lib/util.glsl"


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

#include "/lib/nether_fog.glsl"

void main() {
/* DRAWBUFFERS:4 */

gl_FragData[0] = vec4(0.0,0.0,0.0,0.0);

vec2 fogPos = vec2(256.0 - 256.0*0.12,1.0);
//Sky gradient with clouds
if (gl_FragCoord.x > (fogPos.x - fogPos.x*0.22) && gl_FragCoord.y > 0.4 && gl_FragCoord.x < 535){

	// vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.+257,1.))/256.+tempOffsets/256.,0.0,1.0);
	vec2 p = clamp(floor(gl_FragCoord.xy-fogPos)/256.+tempOffsets/256.,-0.2,1.2);
	vec3 viewVector = cartToSphere(p);

  // vec3 BackgroundColor = (gl_Fog.color.rgb / max(dot(gl_Fog.color.rgb,vec3(0.3333)),0.01)) / 30.0;
	// BackgroundColor *= abs(viewVector.y+0.5);
  vec3 BackgroundColor = vec3(0.0);
  
  vec4 VL_Fog = GetVolumetricFog(mat3(gbufferModelView)*viewVector*256.,  fract(frameCounter/1.6180339887));
	BackgroundColor += VL_Fog.rgb/5.0;

  gl_FragData[0] = vec4(BackgroundColor,1.0);
}

//Temporally accumulate sky and light values
vec3 temp = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy),0).rgb;
vec3 curr = gl_FragData[0].rgb*150.;
gl_FragData[0].rgb = clamp(mix(temp,curr,0.05),0.0,65000.);

//Exposure values
if (gl_FragCoord.x > 10. && gl_FragCoord.x < 11.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(exposure,avgBrightness,avgL2,1.0);
if (gl_FragCoord.x > 14. && gl_FragCoord.x < 15.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
gl_FragData[0] = vec4(rodExposure,centerDepth,0.0, 1.0);

}
