#define ANTIALIASING_RELATED_SETTINGS
#define SKY_RELATED_SETTINGS
#define DISTANCE_BASED_FOG_RELATED_SETTINGS
#define SEASONS_RELATED_SETTINGS
#define WATER_RELATED_SETTINGS
#include "/lib/settings.glsl"
#include "/lib/macro_lod_mod.glsl"

flat varying vec3 zMults;


flat varying vec3 WsunVec;

#ifdef OVERWORLD_SHADER
  flat varying vec3 skyGroundColor;
#endif

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex0;
// uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
// uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
// uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex13;

uniform vec2 texelSize;
uniform float viewHeight;
uniform float viewWidth;
uniform float aspectRatio;
// uniform vec3 sunVec;
uniform float frameTimeCounter;
uniform int frameCounter;

uniform float far;
uniform float near;
uniform float farPlane;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int hideGUI;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform float nightVision;
uniform float rainStrength;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float caveDetection;
uniform float waterEnteredAltitude;
uniform float fogEnd;
uniform vec3 fogColor;
uniform float eyeAltitude;

#include "/lib/waterBump.glsl"
#include "/lib/res_params.glsl"

#ifdef OVERWORLD_SHADER
  #include "/lib/climate_settings.glsl"
#endif

#include "/lib/sky_gradient.glsl"

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 playerPos = p * 2. - 1.;
    vec4 fragposition = iProjDiag * playerPos.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

#include "/lib/DistantHorizons_projections.glsl"

float ld(float depth) {
  return 1.0 / (zMults.y - depth * zMults.z);		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}

float linearize(float dist) {
  return (2.0 * near) / (far + near - dist * (far - near));
}

float DH_ld(float dist) {
  return (2.0 * LOD_NEARPLANE) / (LOD_FARPLANE + LOD_NEARPLANE - dist * (LOD_FARPLANE - LOD_NEARPLANE));
}

float DH_inv_ld (float lindepth){
	return -((2.0*LOD_NEARPLANE/lindepth)-LOD_FARPLANE-LOD_NEARPLANE)/(LOD_FARPLANE-LOD_NEARPLANE);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}

vec4 doEdgeAwareBlur(
	sampler2D colortex, sampler2D depth, float referenceDepth, bool hand
){
  vec4 vl = vec4(0.0);
  float sum = 0.0;
  
  #ifdef USING_LOD_MOD
    float threshHold = referenceDepth*0.06 + 1e-6;
  #else
    float threshHold = referenceDepth*0.06 + 1e-3;
  #endif

  if(hand) threshHold = 1e-6;

	vec2 offsets[4] = vec2[](
    vec2(-1.0,-1.0),
		vec2(-1.0, 1.0),
	 	vec2( 1.0, 1.0),
		vec2( 1.0,-1.0)
  );

  const ivec2 scaling = ivec2(1.0/VL_RENDERING_RESOLUTION_SCALE);

  for(int i = 0; i < 4; i++) {
    
    vec2 offsetArray = offsets[i];
    ivec2 offsetTC2 = ivec2((gl_FragCoord.xy + 0.5 + offsetArray)*VL_RENDERING_RESOLUTION_SCALE);
    ivec2 offsetTC = offsetTC2*scaling;
    
	  #ifdef USING_LOD_MOD
		  float depthSample = sqrt(texelFetch(depth, offsetTC ,0).a/65000.0);
    #else
    	float depthSample = linearize(texelFetch(depth, offsetTC,0).r);
    #endif

    float w = abs(referenceDepth - depthSample) < threshHold ? 1.0 : 1e-7;

    vl += texelFetch(colortex, offsetTC2, 0)*w;

    sum += w;
  }
  return vl/sum;
}

/* RENDERTARGETS:0 */
void main() {

	////// --------------- SETUP STUFF --------------- //////
  vec2 texcoord = gl_FragCoord.xy*texelSize;
  
  float depth = texelFetch(depthtex0, ivec2(gl_FragCoord.xy),0).x;
  bool hand = depth < 0.56;
  float z = depth;
  float z2 = texelFetch(depthtex1, ivec2(gl_FragCoord.xy),0).x;
  float frDepth = linearize(z);

	float swappedDepth = z;

	#ifdef USING_LOD_MOD
    float DH_depth0 = texture(LOD_DEPTHTEX0,texcoord).x;
		float depthOpaque = z;
		float depthOpaqueL = linearizeDepthFast(depthOpaque, near, farPlane);
		
		float dhDepthOpaque = DH_depth0;
		float dhDepthOpaqueL = linearizeDepthFast(dhDepthOpaque, LOD_NEARPLANE, LOD_FARPLANE);
	  if (depthOpaque >= 1.0 || (dhDepthOpaqueL < depthOpaqueL && dhDepthOpaque > 0.0)){
		  depthOpaque = dhDepthOpaque;
		  depthOpaqueL = dhDepthOpaqueL;
		}

		swappedDepth = depthOpaque;
	#else
		float DH_depth0 = 0.0;
	#endif

  ////// --------------- get volumetrics
  #ifdef USING_LOD_MOD
	  float DH_mixedLinearZ = sqrt(texelFetch(colortex12,ivec2(gl_FragCoord.xy),0).a/65000.0);
    // vec4 temporallyFilteredVL = VLTemporalFiltering(viewPos, DH_mixedLinearZ, colortex12, hand);
    vec4 temporallyFilteredVL = doEdgeAwareBlur(colortex0, colortex12, DH_mixedLinearZ, hand);
  #else
    // vec4 temporallyFilteredVL = VLTemporalFiltering(viewPos, frDepth, depthtex0, hand);
    vec4 temporallyFilteredVL = doEdgeAwareBlur(colortex0, depthtex0, frDepth, hand);
  #endif

  gl_FragData[0] = temporallyFilteredVL;
}