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
	// const bool colortex3MipmapEnabled = true;

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
uniform sampler2D colortex15;
uniform sampler2D colortex16;

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
#include "/lib/water_absorbance_effects.glsl"

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}

vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 playerPos = p * 2. - 1.;
    vec4 fragposition = iProjDiag * playerPos.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

#include "/lib/DistantHorizons_projections.glsl"

float interleaved_gradientNoise_temporal(){
	#if TAA_MODE > 0
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887);
	#endif
}
float interleaved_gradientNoise_temporal2(){
	vec2 coord = (gl_FragCoord.xy + 5.588238 * float(frameCounter%64));
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)) ;
	return noise;
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}

float R2_dither(){
	vec2 coord = gl_FragCoord.xy ;

	#if TAA_MODE > 0
		coord +=  (frameCounter%40000) * 2.0;
	#endif
	
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}

float blueNoise(){
	#if TAA_MODE > 0
  		return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887);
	#endif
}

vec4 blueNoise(vec2 coord){
  return texelFetch(colortex6, ivec2(coord)%512 , 0) ;
}

vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

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

vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}

vec3 decode (vec2 encn){
    vec3 n = vec3(0.0);
    encn = encn * 2.0 - 1.0;
    n.xy = abs(encn);
    n.z = 1.0 - n.x - n.y;
    n.xy = n.z <= 0.0 ? (1.0 - n.yx) * sign(encn) : encn;
    return clamp(normalize(n.xyz),-1.0,1.0);
}

vec2 clampUV(in vec2 uv, vec2 texcoord){
//  uv /= vec2(aspectRatio,1.0);
//  texcoord /= vec2(aspectRatio,1.0);
  
  // return uv;

  // get the gradient when a refracted axis and non refracted axis go above 1.0 or below 0.0
  // use this gradient to lerp between refracted and non refracted uv
  // the goal of this is to stretch the uv back to normal when the refracted image exposes off screen uv
  // emphasis on *stretch*, as i want the transition to remain looking like refraction, not a sharp cut.
  
  float vignette = max(uv.x * texcoord.x, 0.0);
  vignette = max(uv.y * texcoord.y, vignette);
  vignette = max((uv.x-1.0) * (texcoord.x-1.0), vignette);
  vignette = max((uv.y-1.0) * (texcoord.y-1.0), vignette);

  vignette *= vignette*vignette*vignette*vignette*vignette*vignette;

  return clamp(mix(uv, texcoord, vignette),0.0,0.9999999);
}

vec3 projectanddivide(mat4 projectionMatrix, vec3 position){
	vec4 homopos = projectionMatrix *vec4(position,1.0);

	return homopos.xyz / homopos.w;
}

vec3 doRefractionEffect( inout vec2 passTexcoord, vec3 viewPos, vec3 normal, float refractAmount){
  // settings
  refractAmount *= float(FAKE_REFRACTION_AMOUNT)/50.0;
  float dispersionAmount = float(FAKE_DISPERSION_AMOUNT)/50.0;
  float smudgeAmount = float(REFRACTION_SMUDGE_AMOUNT)/50.0;

  // GRAAAAAAAAAAAAH
  vec3 incidentRay = refract(normalize(viewPos), normal.xyz, 0.5) * refractAmount;

  #if REFRACTION_SMUDGE_AMOUNT > 0
    incidentRay += incidentRay*(blueNoise()-0.5)*smudgeAmount;
  #endif

  // RAYTRACINNG!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! RTX!!!!!!!!!!
  vec3 refractedPos = viewPos + incidentRay;
	vec2 refractedTexcoord = (projectanddivide(gbufferProjection, refractedPos).xy*0.5+0.5) *RENDER_SCALE;

  // lerp to undistorted tc when out of screen bounds
  // make sure the origin is the center of the screen
  refractedTexcoord = clampUV(refractedTexcoord, passTexcoord);

  #if FAKE_DISPERSION_AMOUNT > 0
    // make sure tc is centered on screen
    refractedTexcoord -= 0.5;
    passTexcoord -= 0.5;
    // fake dispersion
    vec2 dispersion =  refractedTexcoord - passTexcoord;
    dispersion /= (1.0+dot(dispersion,dispersion)*1000.0) * 6.0;
    dispersion *= dispersionAmount;

    // force back to undistorted tc when occluded by opaque geometry
    float alphaCheck = min( decodeVec2(texelFetch(colortex11, ivec2((refractedTexcoord - dispersion + 0.5)/texelSize),0).a).r,
                            decodeVec2(texelFetch(colortex11, ivec2((refractedTexcoord + dispersion + 0.5)/texelSize),0).a).r
                          ) > 0.0 ? 1.0 : 0.0;

    refractedTexcoord = mix(passTexcoord, refractedTexcoord, alphaCheck);

    vec3 color = vec3(0.0);
    color.r = texture(colortex3, refractedTexcoord + dispersion  + 0.5).r;
    color.b = texture(colortex3, refractedTexcoord - dispersion  + 0.5).b;
    color.g = texture(colortex3, refractedTexcoord + 0.5).g;

    passTexcoord = refractedTexcoord+0.5;
  #else
    float alphaCheck = decodeVec2(texelFetch(colortex11, ivec2(refractedTexcoord/texelSize),0).a).r > 0.0 ? 1.0 : 0.0;
    
    refractedTexcoord = mix(passTexcoord, refractedTexcoord, alphaCheck);

    vec3 color = texture(colortex3, refractedTexcoord).rgb;
    
    passTexcoord = refractedTexcoord;
  #endif

  return color;
}

vec3 toClipSpace3Prev(vec3 viewSpacePosition) {
    return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 toClipSpace3Prev_DH( vec3 viewSpacePosition, bool depthCheck ) {

	#ifdef USING_LOD_MOD
		  mat4 projectionMatrix = depthCheck ? LOD_PROJECTION_PREV : gbufferPreviousProjection;
   		return projMAD(projectionMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#else
    	return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#endif
}

vec4 doEdgeAwareBlur_best(
	in vec2 uv, sampler2D colortex, sampler2D depth, float referenceDepth, bool hand, float z
){
  vec4 vl = vec4(0.0);
  float sum = 0.0;
  

  #ifdef USING_LOD_MOD
    float threshHold = referenceDepth*0.06 + 1e-6;
  #else
    float threshHold = referenceDepth*0.06 + 1e-6;
  #endif

	vec2 offsets[4] = vec2[](
    vec2(-1.0,-1.0),
		vec2(-1.0, 1.0),
	 	vec2( 1.0, 1.0),
		vec2( 1.0,-1.0)
  );

  const ivec2 scaling = ivec2(1.0/VL_RENDERING_RESOLUTION_SCALE);
  
  float scaleRadius = min(1.0/VL_RENDERING_RESOLUTION_SCALE,3.0);
  

  for(int i = 0; i < 4; i++) {
    
    vec2 offsetArray = offsets[i]*scaleRadius;
    ivec2 offsetTC2 = ivec2((uv + 0.5 + offsetArray)*VL_RENDERING_RESOLUTION_SCALE);
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
  // return texelFetch(colortex, ivec2(uv*VL_RENDERING_RESOLUTION_SCALE ), 0);
  return vl/sum;
}

bool edgeAgainstSkyCheck(
	sampler2D depth, float referenceDepth, in float motion
){

	const vec2 offsets[4] = vec2[](
    // vec2(-1.0,-1.0),
		// vec2(-1.0, 1.0),
	 	// vec2( 1.0, 1.0),
		// vec2( 1.0,-1.0)
    vec2(-1.0, 0.0),
		vec2( 1.0, 0.0),
	 	vec2( 0.0, 1.0),
		vec2( 0.0,-1.0)
  );

  float edgeArea = 0.0;

  for(int i = 0; i < 4; i++) {
    ivec2 offsetTC = ivec2(gl_FragCoord.xy + offsets[i]*motion);
    
	  #ifdef USING_LOD_MOD
		  float depthSample = sqrt(texelFetch(depth, offsetTC ,0).a/65000.0);
    #else
    	float depthSample = linearize(texelFetch(depth, offsetTC ,0).r);
    #endif
 
    edgeArea = max(edgeArea, abs(referenceDepth - depthSample));
  }
  
  return edgeArea > referenceDepth*0.06;
}

uniform bool windowResizeCheck;
// uniform int frameCounter;
// uniform vec2 taaJitter;
vec4 VLTemporalFiltering(vec3 viewPos, in float referenceDepth, sampler2D depth, bool hand){

  vec2 VLtexCoord = gl_FragCoord.xy*texelSize;

	// get previous frames position stuff for UV
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * playerPos + gbufferPreviousModelView[3].xyz;
	previousPosition = toClipSpace3Prev(previousPosition);
  previousPosition.xy *= RENDER_SCALE;

	vec2 velocity = previousPosition.xy - VLtexCoord;
	previousPosition.xy = VLtexCoord + velocity;
  
  bool edgeCheck = edgeAgainstSkyCheck(depth, referenceDepth, mix(1.0, 1.0, clamp(length(velocity/texelSize),0.0,1.0)) );
  
  // ensure that the center pixel is being sampled (except around edges because the offset creates a gap)
  vec2 VLtexCoordCenter = VLtexCoord - (edgeCheck ? vec2(0.0) : texelSize*0.5);
  
  if(hand) previousPosition.xy = VLtexCoord;

  vec4 currentFrame = texture(colortex0, VLtexCoordCenter);

  // return currentFrame;

  // make sure to clamp proportional to the VL textures resolution, not only screen resolution
  vec4 col0 = currentFrame;
  vec4 col1 = texture(colortex0, VLtexCoordCenter + (vec2( texelSize.x,  texelSize.y)/VL_RENDERING_RESOLUTION_SCALE));
  vec4 col2 = texture(colortex0, VLtexCoordCenter + (vec2( texelSize.x, -texelSize.y)/VL_RENDERING_RESOLUTION_SCALE));
  vec4 col3 = texture(colortex0, VLtexCoordCenter + (vec2(-texelSize.x, -texelSize.y)/VL_RENDERING_RESOLUTION_SCALE));
  vec4 col4 = texture(colortex0, VLtexCoordCenter + (vec2(-texelSize.x,  texelSize.y)/VL_RENDERING_RESOLUTION_SCALE));
  vec4 col5 = texture(colortex0, VLtexCoordCenter + (vec2( 0.0,			     texelSize.y)/VL_RENDERING_RESOLUTION_SCALE));
  vec4 col6 = texture(colortex0, VLtexCoordCenter + (vec2( 0.0,			    -texelSize.y)/VL_RENDERING_RESOLUTION_SCALE));
  vec4 col7 = texture(colortex0, VLtexCoordCenter + (vec2(-texelSize.x,  		     0.0)/VL_RENDERING_RESOLUTION_SCALE));
  vec4 col8 = texture(colortex0, VLtexCoordCenter + (vec2( texelSize.x,  		     0.0)/VL_RENDERING_RESOLUTION_SCALE));

	vec4 moments1 = (col0+col1+col2+col3+col4+col5+col6+col7+col8)/9.0;
	vec4 moments2 = (col0*col0+col1*col1+col2*col2+col3*col3+col4*col4+col5*col5+col6*col6+col7*col7+col8*col8)/9.0;
	
  // helps resolve quicker on edges of the screen as it moves.
  if (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0 ) return moments1;
  
  float tuner = 1.5;
	vec4 standardDev = sqrt(max(moments2 - moments1*moments1,0.0));
	vec4 colMax = moments1 - tuner*standardDev;
	vec4 colMin = moments1 + tuner*standardDev;

  vec4 frameHistory = texture(colortex10, previousPosition.xy);
	vec4 clampedFrameHistory = clamp(frameHistory, colMin, colMax);
  
	// return the first moments instead of history if the difference across frames in the neighborhood is enough for it. helps reduces ghosting without looking too grainy/flickery
  clampedFrameHistory = mix(clampedFrameHistory, moments1, clamp(abs(clampedFrameHistory - frameHistory)/clampedFrameHistory,0.0,1.0));

  float blendingFactor = 0.1;

  // reduce history reliance
  if(
    windowResizeCheck
    || frameCounter < 2 
    || edgeCheck
  ) blendingFactor = 1.0;
  
  vec4 reprojectFrame = mix(clampedFrameHistory, currentFrame, blendingFactor);
  
  return clamp(reprojectFrame,0.0,65000.0);
}

void blendAllFogTypes( inout vec3 color, inout float bloomyFogMult, vec4 volumetrics, float linearDistance, vec3 playerPos, vec3 cameraPosition, bool isSky ){

  // blend cave fog
  #if defined OVERWORLD_SHADER && defined CAVE_FOG
    if (isEyeInWater == 0 && eyeAltitude < 1500){
      vec3 cavefogCol = vec3(CaveFogColor_R, CaveFogColor_G, CaveFogColor_B) * 0.3;
      cavefogCol *= 1.0-pow(1.0-pow(1.0 - max(1.0 - linearDistance/far,0),2),CaveFogFallOff);
      cavefogCol *= exp(-7.0*clamp(playerPos.y*0.5+0.5,0,1)) * 0.999 + 0.001;

      #ifdef CAVE_FOG_DARKEN_SKY
        float skyhole = pow(clamp(1.0-pow(max(playerPos.y - 0.6,0.0)*5.0,2.0),0.0,1.0),2);
        color.rgb = mix(color.rgb + cavefogCol * caveDetection, cavefogCol, isSky ? skyhole * caveDetection : 0.0);
      #else
        color.rgb += cavefogCol * caveDetection;
      #endif
    }
  #endif

  /// water absorption; it is completed when volumetrics are blended.
  if(isEyeInWater == 1) underWaterAbsorbance_insidePOV(linearDistance, color, bloomyFogMult);
  
  /// blend volumetrics
  color = color * volumetrics.a + volumetrics.rgb;
  

  // blend vanilla fogs (blindness, darkness, lava, powdered snow)
  if(isEyeInWater > 1 || blindness > 0 || darknessFactor > 0){
    float enviornmentFogDensity = 1.0 - clamp(linearDistance/fogEnd,0,1);
    enviornmentFogDensity = 1.0 - enviornmentFogDensity*enviornmentFogDensity;
    enviornmentFogDensity *= enviornmentFogDensity;
    enviornmentFogDensity =  mix(enviornmentFogDensity, 1.0, min(darknessLightFactor*2.0,1));

    color = mix(color, toLinear(fogColor), enviornmentFogDensity);
  }
}

void blendForwardRendering( inout vec3 color, vec4 translucentShader ){
  // REMEMBER that forward rendered color is written as color.rgb/10.0, invert it.
  if(translucentShader.a > 0) {
    color = color * (1.0 - translucentShader.a) + translucentShader.rgb * 10.0;
  }
}

float getBorderFogDensity(float linearDistance, vec3 playerPos, bool sky){

  if(sky) return 0.0;

  #ifdef USING_LOD_MOD
  	float borderFogDensity = smoothstep(1.0, 0.0, min(max(1.0 - linearDistance / LOD_RENDERDISTANCE,0.0)*3.0,1.0)   );
  #else
  	float borderFogDensity = smoothstep(1.0, 0.0, min(max(1.0 - linearDistance / far,0.0)*3.0,1.0)   );
  #endif
  
  borderFogDensity *= exp(-10.0 * pow(clamp(playerPos.y,0.0,1.0)*4.0,2.0));
  borderFogDensity *= (1.0-caveDetection);

  return borderFogDensity;
}

vec3 allocatePrecision_TangentNormal(vec3 normals){
	// return normals;
  vec3 newNormal = normals;

  if(normals.x < 0.0) {
		newNormal.x = -(1.0-sqrt(1-pow(clamp(-newNormal.x,0.0,1.0),2)));
	}else{
		newNormal.x =  (1.0-sqrt(1-pow(clamp( newNormal.x,0.0,1.0),2)));
  }
  if(normals.y < 0.0) {
		newNormal.y = -(1.0-sqrt(1-pow(clamp(-newNormal.y,0.0,1.0),2)));
	}else{
		newNormal.y =  (1.0-sqrt(1-pow(clamp( newNormal.y,0.0,1.0),2)));
  }
  if(normals.z < 0.0) {
		newNormal.z = -(1.0-sqrt(1-pow(clamp(-newNormal.z,0.0,1.0),2)));
	}else{
		newNormal.z =  (1.0-sqrt(1-pow(clamp( newNormal.z,0.0,1.0),2)));
  }

	return newNormal;
}


float maxof3(vec3 color) {
  return max(color.x, max(color.y, color.z));
}

float thercp(float color){
  return 1.0 / color;
}

vec3 tonemap(vec3 c) {
  return c * thercp(maxof3(c) + 1.0);
}

vec3 invTonemap(vec3 c) { 
  return c * thercp(1.0 - maxof3(c));
}


#define clamp01(x) clamp(x, 0.0, 1.0)
#define fsign(x) (clamp01(x * 1e35) * 2.0 - 1.0)

float triangularize(float dither)
{
    float center = dither*2.0-1.0;
    dither = center*inversesqrt(abs(center));
    return clamp(dither-fsign(center),0.0,1.0);
}

vec4 fp10Dither(vec4 color ,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color.rgb));
	return vec4(color.rgb + dither*exp2(-mantissaBits)*exp2(exponent), color.a);
}
void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}
void main() {
  /* RENDERTARGETS:7,3,10 */

	////// --------------- SETUP STUFF --------------- //////
  vec2 texcoord = gl_FragCoord.xy*texelSize;
  
  #if DEBUG_VIEW == debug_DEFERRED_RENDERING
    gl_FragData[0].r = 1.0; // pass fog alpha so bloom can do bloomy fog
    gl_FragData[1].rgb = clamp(texture(colortex3, texcoord).rgb, 0.0,68000.0);
    return;
  #endif
  
  float depth = texelFetch(depthtex0, ivec2(gl_FragCoord.xy),0).x;
  bool hand = depth < 0.56;
  float z = depth;
  float z2 = texelFetch(depthtex1, ivec2(gl_FragCoord.xy),0).x;
  
		if(hand){
			convertHandDepth(z);
			convertHandDepth(z2);
		}
    
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

  bool isSky = swappedDepth >= 1.0;

	vec3 viewPos = toScreenSpace_DH(texcoord/RENDER_SCALE, z, DH_depth0);
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;

  float linearDistance = length(playerPos);
  float linearDistance_cylinder = length(playerPos.xz);
	vec3 playerPos_normalized = normalize(playerPos);

	vec3 viewPos_alt = toScreenSpace(vec3(texcoord/RENDER_SCALE, z2));
	vec3 playerPos_alt = mat3(gbufferModelViewInverse) * viewPos_alt + gbufferModelViewInverse[3].xyz;
  float linearDistance_cylinder_alt = length(playerPos_alt.xz);

	float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2) ,0.0,1.0);
	float lightleakfixfast = clamp(eyeBrightness.y/240.,0.0,1.0);

  float testingthing = distance(viewPos,viewPos_alt);
	////// --------------- UNPACK OPAQUE GBUFFERS --------------- //////
	// float opaqueMasks = decodeVec2(texture(colortex1,texcoord).a).y;
	// bool isOpaque_entity = abs(opaqueMasks-0.45) < 0.01;

	////// --------------- UNPACK TRANSLUCENT GBUFFERS --------------- //////
	vec4 data = texelFetch(colortex11,ivec2(texcoord/texelSize),0).rgba;
	vec4 unpack0 = vec4(decodeVec2(data.r),decodeVec2(data.g)) ;
	vec4 unpack1 = vec4(decodeVec2(data.b),decodeVec2(data.a)) ;
	
	vec4 albedo = vec4(unpack0.a,unpack1.rgb);

	vec3 tangentNormals = unpack0.xyz* 2.0 - 1.0;
	// this was written with a curve applied to the normal to put denser bits where finer detail is needed. this is the inverse.
  tangentNormals.xyz = allocatePrecision_TangentNormal(tangentNormals.xyz);
  // if(hand) tangentNormals.z = abs(tangentNormals.z);

  
	bool nameTagMask = abs(unpack1.a - 0.1) < 0.01;
  float nametagbackground = nameTagMask ? 0.25 : 1.0;

  // if(albedo.a < 0.01) tangentNormals = vec3(0.0);

	////// --------------- UNPACK MISC --------------- //////
	// 1.0 = water mask
	// 0.9 = entity mask
	// 0.8 = reflective entities
	// 0.7 = reflective blocks
  float translucentMasks = texelFetch(colortex7,ivec2(gl_FragCoord.xy),0).a;

  // float translucentMasks = texture(colortex7,texcoord).a;

	bool isWater = translucentMasks > 0.99;
	bool isReflectiveEntity = abs(translucentMasks - 0.8) < 0.01;
	bool isReflective = abs(translucentMasks - 0.7) < 0.01 || isWater || isReflectiveEntity;
	bool isEntity = abs(translucentMasks - 0.9) < 0.01 || isReflectiveEntity;

  float blank = 0.0;
  ////// --------------- get volumetrics
  #ifdef USING_LOD_MOD
	  float DH_mixedLinearZ = sqrt(texelFetch(colortex12,ivec2(gl_FragCoord.xy),0).a/65000.0);
    vec4 temporallyFilteredVL = VLTemporalFiltering(viewPos, DH_mixedLinearZ, colortex12, hand);
  #else
    vec4 temporallyFilteredVL = VLTemporalFiltering(viewPos, frDepth, depthtex0, hand);
  #endif
  gl_FragData[2] = temporallyFilteredVL;

  float bloomyFogMult = 1.0;

  ////// --------------- MAIN COLOR BUFFER
  ////// --------------- distort texcoords as a refraction effect

  vec2 refractedCoord = texcoord;
  ////// --------------- START BLENDING FOGS AND FORWARD RENDERED COLOR
  vec4 TranslucentShader = texture(colortex2, texcoord).rgba;
  
  #if FAKE_REFRACTION_AMOUNT > 0 
    vec3 color = doRefractionEffect(refractedCoord, viewPos, tangentNormals.xyz, testingthing > 0.01 && albedo.a > 0.01 ? 1.0 : 0.0);
    // vec3 color = doRefractionEffect(refractedCoord, viewPos, tangentNormals.xyz, linearDistance, isReflectiveEntity, isWater && isEyeInWater == 1, TranslucentShader.a>0.01, testingthing);
  #else
    vec3 color = texture(colortex3, texcoord).rgb;
  #endif
  
  ////// --------------- get volumetrics
  #ifdef USING_LOD_MOD
    vec4 VLBehindTranslucents = doEdgeAwareBlur_best(refractedCoord/texelSize, colortex13, depthtex1, DH_mixedLinearZ, hand, z);
  #else
    vec4 VLBehindTranslucents = doEdgeAwareBlur_best(refractedCoord/texelSize, colortex13, depthtex1, linearize(texelFetch(depthtex1, ivec2(refractedCoord/texelSize),0).x), hand, z);
    // vec4 VLBehindTranslucents =  bilateralUpsample(refractedCoord/texelSize, colortex13, blank, linearize(texelFetch(depthtex1, ivec2(refractedCoord/texelSize),0).x), depthtex1, hand);
  #endif
  

  // ensure that bloomy fog mask in this VLBehindTranslucents.a does not darken outside of glass areas.
  if(TranslucentShader.a > 0.0 &&  TranslucentShader.a < 1.0) color.rgb = color.rgb * VLBehindTranslucents.a + VLBehindTranslucents.rgb;
  
  #if defined OVERWORLD_SHADER
    // to avoid bloomy fog applying to the surface of water, and the clouds, swap between high and low quality VL buffers.
    bloomyFogMult *= isWater ? temporallyFilteredVL.a : (TranslucentShader.a < 0.9995 ? VLBehindTranslucents.a : 1.0);
  #else
    bloomyFogMult *= temporallyFilteredVL.a;
  #endif

  // blend border fog. be sure to blend before and after forward rendered color blends.
  #if defined BorderFog && defined OVERWORLD_SHADER
    vec4 borderFog = vec4(skyGroundColor, getBorderFogDensity(linearDistance_cylinder, playerPos_normalized, swappedDepth >= 1.0));

    #if !defined SKY_GROUND
      borderFog.rgb = skyFromTex(playerPos_normalized, colortex4)/1200.0 * Sky_Brightness;
    #endif
    
    #if !defined USING_LOD_MOD
     if(!isWater) color = mix(color, borderFog.rgb, getBorderFogDensity(linearDistance_cylinder_alt, normalize(playerPos_alt), z2 >= 1.0 || TranslucentShader.a <= 0));
    #endif
  #else
    vec4 borderFog = vec4(0.0);
  #endif

  // apply block breaking effect.
  if(albedo.a > 0.01 && !isWater && TranslucentShader.a <= 0.0 && !isEntity) color = mix(color*6.0, color, luma(albedo.rgb)) * albedo.rgb;
  
  // apply multiplicative color blend for glass n stuff
  #ifdef Glass_Tint
    if(!isWater) color *= mix(normalize(albedo.rgb+1e-7), vec3(1.0), max(borderFog.a, min(max(0.1-albedo.a,0.0) * 10.0,1.0))) ;
  #endif

  // blend forward rendered programs onto the color.
  blendForwardRendering(color, TranslucentShader);

  #if defined BorderFog && defined OVERWORLD_SHADER && !defined AERIAL_PERSPECTIVE_TEST
    color = mix(color, borderFog.rgb, getBorderFogDensity(linearDistance_cylinder, playerPos_normalized, swappedDepth >= 1.0));
  #endif

  #ifdef AERIAL_PERSPECTIVE_TEST
    vec3 testPos = playerPos_normalized;
    float density = exp(-AERIAL_PERSPECTIVE_DENSITY*0.00045*length(playerPos));

	  float position = clamp(density*256.0,1.5,257.0);
	  // vec3 samplesky = texture(colortex4, vec2(16.5, position)*texelSize).rgb / 1200.0 ;
    vec3 samplesky = skyFromTex(mix(testPos, vec3(testPos.x,-1.0,testPos.z),  density), colortex4).rgb/1200.0;


    if(!isSky && isEyeInWater == 0) color.rgb = color.rgb * density + (samplesky - samplesky * density);
    // color.rgb = samplesky;
  #endif
  
  // tweaks to VL for nametag rendering
	#if defined IS_IRIS
    temporallyFilteredVL.a = min(temporallyFilteredVL.a + (1.0-nametagbackground),1.0);
    temporallyFilteredVL.rgb *= nametagbackground;
  #endif

  // if(isSky) color = vec3(1,0,0);

  // if(swappedDepth >= 1.0) color = vec3(1,0,0);
  // blend all fog types. volumetric fog, volumetric clouds, distance based fogs for lava, powdered snow, blindness, and darkness.
  blendAllFogTypes(color, bloomyFogMult, temporallyFilteredVL, linearDistance, playerPos_normalized, cameraPosition, isSky);

////// --------------- bloomy rain effect

#ifdef OVERWORLD_SHADER
  float rainDrops = texelFetch(colortex9,ivec2(texcoord/texelSize),0).a;
  
  if(rainDrops > 0.0) {
    // bloomyFogMult *= mix(1.0, clamp(1.0 - pow(rainDrops*5.0,2),0.0,1.0), RAIN_SNOW_BLOOMY_FOG);
    // color.rgb += color.rgb * RAIN_SNOW_BRIGHTNESS;
    float newrainDrops = 1.0/(1.0+rainDrops*25.0);
    bloomyFogMult *= mix(1.0, newrainDrops, RAIN_SNOW_BLOOMY_FOG);
    
    newrainDrops = 1.0/(1.0+rainDrops*100.0);
    color.rgb += color.rgb * RAIN_SNOW_BRIGHTNESS * (1.0-newrainDrops);
  }
#endif

////// --------------- FINALIZE
  #ifdef display_LUT
      float scale = 540.0 * 1.0;
      vec2 coord = (gl_FragCoord.xy-vec2(5,5)) * texelSize * vec2(scale,scale/aspectRatio);
      vec3 thingy = texelFetch(colortex4,ivec2(coord),0).rgb /1200.0;


      if(hideGUI == 0){
        color.rgb = thingy;
        bloomyFogMult = 1.0;
      }

    #if defined OVERWORLD_SHADER
      // if( hideGUI == 1) color.rgb = skyCloudsFromTex(playerPos_normalized, colortex4).rgb/1200.0;
    #else
      if( hideGUI == 1) color.rgb = volumetricsFromTex(playerPos_normalized, colortex4, 0.0).rgb/1200.0;
    #endif
  #endif

  gl_FragData[0] = vec4(bloomyFogMult,0.0,0.0,1.0); // pass fog alpha so bloom can do bloomy fog

  // if(hideGUI == 0) color.rgb = tangentNormals.xyz * 0.1;
  // color.rgb =  vec3(texcoord.xy*2-1,0.0);// * 0.1  ;

  #if defined TAA_MODE > 0
    // invertible tonemap for TAA.
    // put the 0.0-1.0 range to 0.0-65000.0 range to keep color precision for better inversion.
    color.rgb = tonemap(color.rgb)*65000.0;
    
    color = fp10Dither(vec4(color,1.0), triangularize(interleaved_gradientNoise_temporal2())).rgb;
  #endif
  
  gl_FragData[1].rgb = clamp(color.rgb, 0.0,68000.0);

  #if DEBUG_VIEW == debug_FORWARD_RENDERING
    gl_FragData[1].rgb = vec3(1.0) * (1.0-TranslucentShader.a) + TranslucentShader.rgb*10.0;
  #endif
  #if DEBUG_VIEW == debug_FORWARD_COLOR_TINT
    gl_FragData[1].rgb = vec3(1.0) * (1.0-albedo.a) + albedo.rgb ;
  #endif
  
  // gl_FragData[1].rgb =  vec3(1.0) * ld(    (data.a > 0.0 ? data.a : texture(depthtex0, texcoord).x   )              )   ;
  // gl_FragData[1].rgb = gl_FragData[1].rgb * (1.0-TranslucentShader.a) + TranslucentShader.rgb*10.0;
  // gl_FragData[1].rgb = 1-(texcoord.x > 0.5 ? vec3(TranslucentShader.a) : vec3(data.a));
}