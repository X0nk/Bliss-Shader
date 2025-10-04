#include "/lib/settings.glsl"

flat varying vec3 zMults;

flat varying vec2 TAA_Offset;
flat varying vec3 WsunVec;

#ifdef OVERWORLD_SHADER
  flat varying vec3 skyGroundColor;
#endif

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
#endif

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
// uniform sampler2D colortex13;
// uniform sampler2D colortex14;
// uniform sampler2D colortex15;
uniform vec2 texelSize;

// uniform float viewHeight;
// uniform float viewWidth;
// uniform vec3 sunVec;
uniform float frameTimeCounter;
uniform int frameCounter;

uniform float far;
uniform float near;
uniform float farPlane;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform int dhRenderDistance;

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
  		return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887);
	#endif
}

vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord)%512 , 0) ;
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
  return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
}

float DH_inv_ld (float lindepth){
	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
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
  // return uv;

  // get the gradient when a refracted axis and non refracted axis go above 1.0 or below 0.0
  // use this gradient to lerp between refracted and non refracted uv
  // the goal of this is to stretch the uv back to normal when the refracted image exposes off screen uv
  // emphasis on *stretch*, as i want the transition to remain looking like refraction, not a sharp cut.
  
  float vignette = max(uv.x * texcoord.x, 0.0);
  vignette = max(uv.y * texcoord.y, vignette);
  vignette = max((uv.x-1.0) * (texcoord.x-1.0), vignette);
  vignette = max((uv.y-1.0) * (texcoord.y-1.0), vignette);

  vignette *= vignette*vignette*vignette*vignette;

  return clamp(mix(uv, texcoord, vignette),0.0,0.9999999);
}

vec3 doRefractionEffect( inout vec2 passTexcoord, vec2 normal, float linearDistance, bool isReflectiveEntity, bool underwater){
  // correct normal directions to match texcoord directions (right facing X, up facing Y)
  normal.y = -normal.y;
  vec2 texcoord = passTexcoord;

  vec3 color = vec3(0.0);

  float refractAmount = float(FAKE_REFRACTION_AMOUNT)/4.0;
  float dispersionAmount = float(FAKE_DISPERSION_AMOUNT)/4.0;
  float smudgeAmount = float(REFRACTION_SMUDGE_AMOUNT)/4.0;

  refractAmount *= 0.5 / (1.0 + pow(linearDistance,0.8) * (underwater ? 0.1 : 1.0));
  if(isReflectiveEntity) refractAmount *= 0.5;

  dispersionAmount *= 0.035;
  smudgeAmount *= 0.035;

  vec2 dispersion = (clamp(normal, -0.2, 0.2) / 0.2);
  
  #if REFRACTION_SMUDGE_AMOUNT > 0
    vec2 smudge = smudgeAmount * dispersion * (blueNoise()-0.5);
  #else
    vec2 smudge = vec2(0.0, 0.0);
  #endif

  dispersion *= dispersionAmount;

  #if FAKE_DISPERSION_AMOUNT > 0
    // do not offset texcoord if alpha is 1.0
    refractAmount *= min(  decodeVec2(texelFetch2D(colortex11, ivec2(clampUV(texcoord - ((normal + dispersion) + smudge)*refractAmount, texcoord)/texelSize),0).b).g,
                           decodeVec2(texelFetch2D(colortex11, ivec2(clampUV(texcoord - ((normal - dispersion) + smudge)*refractAmount, texcoord)/texelSize),0).b).g  ) > 0.0 ? 1.0 : 0.0;

    // create offsets
    vec2 offsetTexcoord = clampUV(texcoord - (normal + smudge)*refractAmount, texcoord);
    passTexcoord = offsetTexcoord;

    // sample color with offsetted texcoord. in this case, the red and blue channels have offsets in opposite directions for a dispersion effect.
    color.g = texture2D(colortex3, offsetTexcoord).g;

    offsetTexcoord = clampUV(texcoord - ((normal + dispersion) + smudge)*refractAmount, texcoord);
    color.r = texture2D(colortex3, offsetTexcoord).r;

    offsetTexcoord = clampUV(texcoord - ((normal - dispersion) + smudge)*refractAmount, texcoord);
    color.b = texture2D(colortex3, offsetTexcoord).b;
  #else
    // do not offset texcoord if alpha is 1.0
    refractAmount *= decodeVec2(texelFetch2D(colortex11, ivec2(clampUV(texcoord - (normal + smudge)*refractAmount, texcoord)/texelSize),0).b).g > 0.0 ? 1.0 : 0.0; 

    // create offsets
    vec2 offsetTexcoord = clampUV(texcoord - (normal + smudge)*refractAmount, texcoord);
    passTexcoord = offsetTexcoord;

    // sample color with distorted texcoords
    color.rgb = texture2D(colortex3, offsetTexcoord).rgb;
  #endif

  return color;
}

vec3 toClipSpace3Prev(vec3 viewSpacePosition) {
    return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 toClipSpace3Prev_DH( vec3 viewSpacePosition, bool depthCheck ) {

	#ifdef DISTANT_HORIZONS
		mat4 projectionMatrix = depthCheck ? dhPreviousProjection : gbufferPreviousProjection;
   		return projMAD(projectionMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#else
    	return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#endif
}

vec4 bilateralUpsample(out float outerEdgeResults, float referenceDepth, sampler2D depth, bool hand){

  vec4 colorSum = vec4(0.0);
  float edgeSum = 0.0;
  float threshold = 0.005;
  
  vec2 coord = gl_FragCoord.xy - 1.5;

  vec2 UV = coord;
  const ivec2 SCALE = ivec2(1.0/VL_RENDER_RESOLUTION);
  ivec2 UV_DEPTH = ivec2(UV*VL_RENDER_RESOLUTION)*SCALE;
  ivec2 UV_COLOR = ivec2(UV*VL_RENDER_RESOLUTION);
  ivec2 UV_NOISE = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 OFFSET[5] = ivec2[](
    ivec2(-1,-1),
	 	ivec2( 1, 1),
		ivec2(-1, 1),
		ivec2( 1,-1),
		ivec2( 0, 0)
  );

  for(int i = 0; i < 5; i++) {

		#ifdef DISTANT_HORIZONS
		  float offsetDepth = sqrt(texelFetch2D(depth, UV_DEPTH + (OFFSET[i] + UV_NOISE) * SCALE,0).a/65000.0);
    #else
      float offsetDepth = linearize(texelFetch2D(depth, UV_DEPTH + (OFFSET[i] + UV_NOISE) * SCALE, 0).r);
    #endif

    float edgeDiff = abs(offsetDepth - referenceDepth) < threshold ? 1.0 : 1e-7;
    outerEdgeResults = max(outerEdgeResults, abs(referenceDepth - offsetDepth));

    vec4 offsetColor = texelFetch2D(colortex0, UV_COLOR + OFFSET[i] + UV_NOISE, 0).rgba;
    colorSum += offsetColor*edgeDiff;
    edgeSum += edgeDiff;

  }

  outerEdgeResults = outerEdgeResults > (hand ? 0.005 : referenceDepth*0.05 + 0.1) ? 1.0 : 0.0;
  
  return colorSum / edgeSum;
}

vec4 VLTemporalFiltering(vec3 viewPos, in float referenceDepth, sampler2D depth, bool hand){
  vec2 offsetTexcoord = gl_FragCoord.xy*texelSize;
  vec2 VLtexCoord = offsetTexcoord * VL_RENDER_RESOLUTION;
  
	// get previous frames position stuff for UV
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * playerPos + gbufferPreviousModelView[3].xyz;
	previousPosition = toClipSpace3Prev(previousPosition);

	vec2 velocity = previousPosition.xy - offsetTexcoord;
	previousPosition.xy = offsetTexcoord + velocity;

  vec4 currentFrame = texture2D(colortex0, VLtexCoord);

  // to fill pixel gaps in geometry edges, do a bilateral upsample.
  // pass a mask to only show upsampled color around the edges of blocks. this is so it doesnt blur reprojected results.
  float outerEdgeResults = 0.0;
  vec4 upsampledCurrentFrame = bilateralUpsample(outerEdgeResults, referenceDepth, depth, hand);
  // vec4 upsampledCurrentFrame = BilateralUpscale(colortex0, depth, gl_FragCoord.xy - 1.5, referenceDepth);

  // return vec4(outerEdgeResults,0,0,1);
  // return upsampledCurrentFrame;

  if (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0) return currentFrame;
  
	vec4 col1 = texture2D(colortex0, VLtexCoord + vec2( texelSize.x,  texelSize.y));
	vec4 col2 = texture2D(colortex0, VLtexCoord + vec2( texelSize.x, -texelSize.y));
	vec4 col3 = texture2D(colortex0, VLtexCoord + vec2(-texelSize.x, -texelSize.y));
	vec4 col4 = texture2D(colortex0, VLtexCoord + vec2(-texelSize.x,  texelSize.y));
	vec4 col5 = texture2D(colortex0, VLtexCoord + vec2( 0.0,			    texelSize.y));
	vec4 col6 = texture2D(colortex0, VLtexCoord + vec2( 0.0,			   -texelSize.y));
	vec4 col7 = texture2D(colortex0, VLtexCoord + vec2(-texelSize.x,  		    0.0));
	vec4 col8 = texture2D(colortex0, VLtexCoord + vec2( texelSize.x,  		    0.0));

	vec4 colMax = max(currentFrame,max(col1,max(col2,max(col3, max(col4, max(col5, max(col6, max(col7, col8))))))));
	vec4 colMin = min(currentFrame,min(col1,min(col2,min(col3, min(col4, min(col5, min(col6, min(col7, col8))))))));
  
  vec4 frameHistory = texture2D(colortex10, previousPosition.xy*RENDER_SCALE);
  vec4 clampedFrameHistory = clamp(frameHistory, colMin, colMax);

  float blendingFactor = 0.1;

  // variance
  if(abs(clampedFrameHistory.a  - frameHistory.a) > 0.1) blendingFactor = 1.0;

  vec4 reprojectFrame = mix(clampedFrameHistory, currentFrame, blendingFactor);

  // return clamp(reprojectFrame,0.0,65000.0);
  return clamp(mix(reprojectFrame, upsampledCurrentFrame, outerEdgeResults),0.0,65000.0);

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
  if(isEyeInWater == 1){
    vec3 totEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 scatterCoef = Dirt_Amount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

	  float distanceFromWaterSurface = playerPos.y + 1.0 + (cameraPosition.y - waterEnteredAltitude)/waterEnteredAltitude;
    distanceFromWaterSurface = clamp(distanceFromWaterSurface,0,1);

    vec3 transmittance = exp(-totEpsilon * linearDistance);
    color.rgb *= transmittance;

    vec3 transmittance2 = exp(-totEpsilon * 50.0);
    float fogfade = 1.0 - max((1.0 - linearDistance / min(far, 16.0*7.0) ),0);
    color.rgb += (transmittance2 * scatterCoef) * fogfade;
    
    bloomyFogMult *= dot(transmittance,vec3(0.3333))*0.5;
  }

  /// blend volumetrics
  color = color * volumetrics.a + volumetrics.rgb;
  
  // make bloomy fog only work outside of the overworld (unless underwater)
  #if !defined OVERWORLD_SHADER
    bloomyFogMult *= volumetrics.a;
  #endif

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

  #ifdef DISTANT_HORIZONS
  	float borderFogDensity = smoothstep(1.0, 0.0, min(max(1.0 - linearDistance / dhRenderDistance,0.0)*3.0,1.0)   );
  #else
  	float borderFogDensity = smoothstep(1.0, 0.0, min(max(1.0 - linearDistance / far,0.0)*3.0,1.0)   );
  #endif
  
  borderFogDensity *= exp(-10.0 * pow(clamp(playerPos.y,0.0,1.0)*4.0,2.0));
  borderFogDensity *= (1.0-caveDetection);

  return borderFogDensity;
}
void main() {
  /* RENDERTARGETS:7,3,10 */

	////// --------------- SETUP STUFF --------------- //////
  vec2 texcoord = gl_FragCoord.xy*texelSize;
  
  #if DEBUG_VIEW == debug_DEFERRED_RENDERING
    gl_FragData[0].r = 1.0; // pass fog alpha so bloom can do bloomy fog
    gl_FragData[1].rgb = clamp(texture2D(colortex3, texcoord).rgb, 0.0,68000.0);
    return;
  #endif
  
  float depth = texelFetch2D(depthtex0, ivec2(gl_FragCoord.xy),0).x;
  bool hand = depth < 0.56;
  float z = depth;

  float z2 = texture2D(depthtex1, texcoord).x;
  float frDepth = linearize(z);

	float swappedDepth = z;

	#ifdef DISTANT_HORIZONS
    float DH_depth0 = texture2D(dhDepthTex,texcoord).x;
		float depthOpaque = z;
		float depthOpaqueL = linearizeDepthFast(depthOpaque, near, farPlane);
		
		float dhDepthOpaque = DH_depth0;
		float dhDepthOpaqueL = linearizeDepthFast(dhDepthOpaque, dhNearPlane, dhFarPlane);
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

	////// --------------- UNPACK OPAQUE GBUFFERS --------------- //////
	// float opaqueMasks = decodeVec2(texture2D(colortex1,texcoord).a).y;
	// bool isOpaque_entity = abs(opaqueMasks-0.45) < 0.01;

	////// --------------- UNPACK TRANSLUCENT GBUFFERS --------------- //////
	vec4 data = texelFetch2D(colortex11,ivec2(texcoord/texelSize),0).rgba;
	vec4 unpack0 = vec4(decodeVec2(data.r),decodeVec2(data.g)) ;
	vec4 unpack1 = vec4(decodeVec2(data.b),decodeVec2(data.a)) ;
	
	vec4 albedo = vec4(unpack0.ba,unpack1.rg);
	vec2 tangentNormals = unpack0.xy*2.0-1.0;
  
	bool nameTagMask = abs(unpack1.a - 0.1) < 0.01;
  float nametagbackground = nameTagMask ? 0.25 : 1.0;

  if(albedo.a < 0.01) tangentNormals = vec2(0.0);

	////// --------------- UNPACK MISC --------------- //////
	// 1.0 = water mask
	// 0.9 = entity mask
	// 0.8 = reflective entities
	// 0.7 = reflective blocks
  float translucentMasks = texture2D(colortex7, texcoord).a;

	bool isWater = translucentMasks > 0.99;
	bool isReflectiveEntity = abs(translucentMasks - 0.8) < 0.01;
	bool isReflective = abs(translucentMasks - 0.7) < 0.01 || isWater || isReflectiveEntity;
	bool isEntity = abs(translucentMasks - 0.9) < 0.01 || isReflectiveEntity;

  ////// --------------- get volumetrics
  #ifdef DISTANT_HORIZONS
	  float DH_mixedLinearZ = sqrt(texelFetch2D(colortex12,ivec2(gl_FragCoord.xy),0).a/65000.0);
    vec4 temporallyFilteredVL = VLTemporalFiltering(viewPos, DH_mixedLinearZ, colortex12,hand);
  #else
    vec4 temporallyFilteredVL = VLTemporalFiltering(viewPos, frDepth, depthtex0, hand);
  #endif

  gl_FragData[2] = temporallyFilteredVL;
  float bloomyFogMult = 1.0;

  ////// --------------- MAIN COLOR BUFFER
  ////// --------------- distort texcoords as a refraction effect
  vec2 refractedCoord = texcoord;
  #if FAKE_REFRACTION_AMOUNT > 0
    vec3 color = doRefractionEffect(refractedCoord, tangentNormals.xy, linearDistance, isReflectiveEntity, isWater && isEyeInWater == 1);
  #else
    vec3 color = texture2D(colortex3, texcoord).rgb;
  #endif

  ////// --------------- START BLENDING FOGS AND FORWARD RENDERED COLOR
  vec4 TranslucentShader = texture2D(colortex2, texcoord);

  // blend border fog. be sure to blend before and after forward rendered color blends.
  #if defined BorderFog && defined OVERWORLD_SHADER
    vec4 borderFog = vec4(skyGroundColor, getBorderFogDensity(linearDistance_cylinder, playerPos_normalized, swappedDepth >= 1.0));

    #if !defined SKY_GROUND
      borderFog.rgb = skyFromTex(playerPos_normalized, colortex4)/1200.0 * Sky_Brightness;
    #endif
    #if !defined DISTANT_HORIZONS
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

  #if defined BorderFog && defined OVERWORLD_SHADER
    color = mix(color, borderFog.rgb, getBorderFogDensity(linearDistance_cylinder, playerPos_normalized, swappedDepth >= 1.0));
  #endif
  
  // tweaks to VL for nametag rendering
	#if defined IS_IRIS
    temporallyFilteredVL.a = min(temporallyFilteredVL.a + (1.0-nametagbackground),1.0);
    temporallyFilteredVL.rgb *= nametagbackground;
  #endif

  // blend all fog types. volumetric fog, volumetric clouds, distance based fogs for lava, powdered snow, blindness, and darkness.
  blendAllFogTypes(color, bloomyFogMult, temporallyFilteredVL, linearDistance, playerPos_normalized, cameraPosition, isSky);

////// --------------- bloomy rain effect
  #ifdef OVERWORLD_SHADER
    float rainDrops =  clamp(texture2D(colortex9,texcoord).a,0.0,1.0); 
    if(rainDrops > 0.0) bloomyFogMult *= clamp(1.0 - pow(rainDrops*5.0,2),0.0,1.0);
  #endif

////// --------------- FINALIZE
  #ifdef display_LUT
      float zoomLevel = 1.0;
      vec3 thingy = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy/zoomLevel),0).rgb /1200.0;

      if(luma(thingy) > 0.0){
        color.rgb =  thingy;
        bloomyFogMult = 1.0;
      }

    #if defined OVERWORLD_SHADER
      if( hideGUI == 1) color.rgb = skyCloudsFromTex(playerPos_normalized, colortex4).rgb/1200.0;
    #else
      if( hideGUI == 1) color.rgb = volumetricsFromTex(playerPos_normalized, colortex4, 0.0).rgb/1200.0;
    #endif

  #endif
  gl_FragData[0].r = bloomyFogMult; // pass fog alpha so bloom can do bloomy fog
  gl_FragData[1].rgb = clamp(color.rgb, 0.0,68000.0);

  #if DEBUG_VIEW == debug_FORWARD_RENDERING
    gl_FragData[1].rgb = vec3(1.0) * (1.0-TranslucentShader.a) + TranslucentShader.rgb*10.0;
  #endif
  #if DEBUG_VIEW == debug_FORWARD_COLOR_TINT
    gl_FragData[1].rgb = vec3(1.0) * (1.0-albedo.a) + albedo.rgb ;
  #endif
  // gl_FragData[1].rgb =  vec3(tangentNormals.xy,0.0) * 0.1  ;
  // gl_FragData[1].rgb =  vec3(1.0) * ld(    (data.a > 0.0 ? data.a : texture2D(depthtex0, texcoord).x   )              )   ;
  // gl_FragData[1].rgb = gl_FragData[1].rgb * (1.0-TranslucentShader.a) + TranslucentShader.rgb*10.0;
  // gl_FragData[1].rgb = 1-(texcoord.x > 0.5 ? vec3(TranslucentShader.a) : vec3(data.a));

}