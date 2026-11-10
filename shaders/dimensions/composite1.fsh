#define NETHER_RELATED_SETTINGS
#define END_RELATED_SETTINGS
#define HANDHELD_LIGHTSOURCE_RELATED_SETTINGS
#define ANTIALIASING_RELATED_SETTINGS
#define SKY_RELATED_SETTINGS
#define WETNESS_RELATED_SETTINGS
#define EMISSION_RELATED_SETTINGS
#define DEFFERRED_LIGHTING_PASS_RELATED_SETTINGS
#define SUB_SURFACE_SCATTERING_RELATED_SETTINGS
#define SPECULAR_RELATED_SETTINGS
#define DEFERRED_SPECULAR_RELATED_SETTINGS
#define SHADOWMAP_CONSTANT_RELATED_SETTINGS
#define DIRECT_LIGHT_RELATED_SETTINGS
#define INDIRECT_EFFECT_RELATED_SETTINGS
#define AMBIENT_LIGHT_RELATED_SETTINGS
#define VOLUMETRIC_CLOUD_RELATED_SETTINGS
#define WATER_RELATED_SETTINGS
#define PARALLAX_OCCLUSION_MAPPING_RELATED_SETTINGS
#include "/lib/settings.glsl"
#include "/lib/macro_lod_mod.glsl"
#include "/lib/TAA_jitter.glsl"

// #if defined END_SHADER || defined NETHER_SHADER
// 	#undef IS_LPV_ENABLED
// #endifs

#ifdef IS_LPV_ENABLED
	#extension GL_ARB_shader_image_load_store: enable
	#extension GL_ARB_shading_language_packing: enable
#endif

#include "/lib/util.glsl"
#include "/lib/res_params.glsl"

#define diagonal3_old(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD_old(m, v) (diagonal3_old(m) * (v) + (m)[3].xyz)

vec3 toClipSpace3_test(vec3 viewSpacePosition) {
    return projMAD(gl_ProjectionMatrix, viewSpacePosition);
}	

const bool colortex5MipmapEnabled = true;
uniform float nightVision;

#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;
	
	#ifdef IS_IRIS
		uniform sampler2DShadow shadowtex0HW;
		uniform sampler2DShadow shadowtex1HW;
	#endif

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif

	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
	flat varying vec3 moonCol;
#endif

#ifdef NETHER_SHADER
	const bool colortex4MipmapEnabled = true;
#endif

#ifdef END_SHADER
	flat varying float Flashing;
#endif
uniform int hideGUI;
uniform sampler2D noisetex; //noise
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D colortex0; //clouds
uniform sampler2D colortex1; //albedo(rgb),material(alpha) RGBA16
uniform sampler2D colortex2; //translucents(rgba)
uniform sampler2D colortex3; //filtered shadowmap(VPS)
uniform sampler2D colortex4; //LUT(rgb), quarter res depth(alpha)
uniform sampler2D colortex5; //TAA buffer/previous frame
uniform sampler2D colortex6; //Noise
uniform sampler2D colortex7; //water?
uniform sampler2D colortex8; //Specular
// uniform sampler2D colortex9; //Specular
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex14;

#ifdef IS_LPV_ENABLED
	uniform usampler1D texBlockData;
	uniform sampler3D texLpv1;
	uniform sampler3D texLpv2;
#endif

uniform mat4 gbufferPreviousModelView;

// uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float updateFadeTime;

// uniform float far;
uniform float near;
uniform float farPlane;
uniform float dhFarPlane;
uniform float dhNearPlane;

flat varying vec3 zMults;

uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;


uniform float eyeAltitude;


uniform int frameCounter;
uniform float frameTimeCounter;

uniform float rainStrength;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;

uniform vec3 sunVec;
flat varying vec3 WsunVec;
flat varying vec3 unsigned_WsunVec;
flat varying vec3 WmoonVec;

// #ifdef FLASHLIGHT
// 	flat varying vec3 albedoSmooth;
// #endif

uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int heldItemId;
uniform int heldItemId2;

// // #ifdef IS_LPV_ENABLED
// 	uniform int heldItemId;
// 	uniform int heldItemId2;
// 	uniform int heldBlockLightValue;
// 	uniform int heldBlockLightValue2;
// #endif

uniform float waterEnteredAltitude;

void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}

float convertHandDepth_2(in float depth, bool hand) {
	if(!hand) return depth;

    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    return ndcDepth * 0.5 + 0.5;
}

#include "/lib/projections.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/Shadows.glsl"
#include "/lib/stars.glsl"
#include "/lib/sky_gradient.glsl"

#ifdef OVERWORLD_SHADER
	#include "/lib/scene_controller.glsl"
	#define CLOUDSHADOWSONLY
	#include "/lib/volumetricClouds.glsl"
#endif

#ifdef IS_LPV_ENABLED
	#include "/lib/hsv.glsl"
	#include "/lib/voxel_common.glsl"
	#include "/lib/lpv_render.glsl"
#endif

#define LIGHTNINGFLASH_DIFFUSE
#include "/lib/lightning_stuff.glsl"
#include "/lib/end_fog.glsl"
#include "/lib/DistantHorizons_projections.glsl"
#include "/lib/water_absorbance_effects.glsl"
#include "/lib/diffuse_lighting.glsl"

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

vec3 decode (vec2 encn){
    vec3 n = vec3(0.0);
    encn = encn * 2.0 - 1.0;
    n.xy = abs(encn);
    n.z = 1.0 - n.x - n.y;
    n.xy = n.z <= 0.0 ? (1.0 - n.yx) * sign(encn) : encn;
    return clamp(normalize(n.xyz),-1.0,1.0);
}

vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}
float DH_ld(float dist) {
    return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
}

#include "/lib/specular.glsl"
float DH_inv_ld (float lindepth){
	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
	// return (2.0 * near) / (far + near - depth * (far - near));
}

float invertlinearDepthFast(const in float depth, const in float near, const in float far) {
	return ((2.0*near/depth)-far-near)/(far-near);
}


float triangularize(float dither)
{
    float center = dither*2.0-1.0;
    dither = center*inversesqrt(abs(center));
    return clamp(dither-fsign(center),0.0,1.0);
}

vec3 fp10Dither(vec3 color,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}

float interleaved_gradientNoise_temporal(){
	vec2 coord = gl_FragCoord.xy;
	
	#if TAA_MODE > 0
		coord += (frameCounter%40000) * 2.0;
	#endif

	return fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y ) + 1.0/1.6180339887);
	// #if TAA_MODE > 0
	// 	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887 * frameCounter);
	// #else
	// 	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887);
	// #endif
}

float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}

float R2_dither(){
	vec2 coord = gl_FragCoord.xy ;

	#if TAA_MODE > 0
		coord += (frameCounter%40000) * 2.0;
	#endif
	
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}

float R2_dither2(){
	vec2 coord = gl_FragCoord.xy ;

	#if TAA_MODE > 0
		coord += (frameCounter*8)%40000;
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
  return texelFetch(colortex6, ivec2(coord)%512, 0) ;
}

vec2 CleanSample(
	int samples, float totalSamples, float noise
){

	// this will be used to make 1 full rotation of the spiral. the mulitplication is so it does nearly a single rotation, instead of going past where it started
	float variance = noise * 0.897;

	// for every sample input, it will have variance applied to it.
	float variedSamples = float(samples) + variance;
	
	// for every sample, the sample position must change its distance from the origin.
	// otherwise, you will just have a circle.
    float spiralShape = sqrt(variedSamples / (totalSamples + variance));

	float shape = 2.26; // this is very important. 2.26 is very specific
    float theta = variedSamples * (PI * shape);

	float x =  cos(theta) * spiralShape;
	float y =  sin(theta) * spiralShape;

    return vec2(x, y);
}

vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}

vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}

float swapperlinZ(float depth, float _near, float _far) {
    return (2.0 * _near) / (_far + _near - depth * (_far - _near));
	// l = (2*n)/(f+n-d(f-n))
	// f+n-d(f-n) = 2n/l
	// -d(f-n) = ((2n/l)-f-n)
	// d = -((2n/l)-f-n)/(f-n)

}

vec2 SSRT_Shadows(vec3 viewPos, bool depthCheck, vec3 lightDir, float noise, bool isSSS, bool hand, in float NdotL){

	// return 1.0;

	float shadows = 1.0;
	int samples = 16;
	float SSS = 0.0;

	float _near = near; float _far = far*4.0;

	if (depthCheck) {
		_near = LOD_NEARPLANE;
		_far = LOD_FARPLANE;
	}
    
    vec3 position = toClipSpace3_DH(viewPos, depthCheck) ;
	
	//prevents the ray from going behind the camera
	float rayLength = ((viewPos.z + lightDir.z * _far * sqrt(3.)) > -_near) ? (-_near - viewPos.z) / lightDir.z : _far * sqrt(3.);

    vec3 direction = toClipSpace3_DH(viewPos + lightDir*rayLength, depthCheck) - position;
	direction.xyz = direction.xyz / max(max(abs(direction.x)/0.0005, abs(direction.y)/0.0005),400.0);	//fixed step size
	direction *= 6.0;

	position.xy *= RENDER_SCALE;
	direction.xy *= RENDER_SCALE;
	
	vec3 newPos = position + direction*noise;
	// literally shadow bias to fight shadow acne due to precision problems when comparing sampled depth and marched position
	newPos += (direction * 0.3) / (RENDER_SCALE.x*RENDER_SCALE.x);

	float distanceScale2 = 1.0 + length(viewPos) / 100.0;
	float SSSdistanceScale = 1.0 / distanceScale2;

	for (int i = 0; i < int(samples); i++) {

		if(newPos.x < 0 || newPos.x > 1 || newPos.y < 0 || newPos.y > 1) break;
		
		#ifdef USING_LOD_MOD
			float sampleDepth = 0.0;
			if(depthCheck){
				sampleDepth = texelFetch(LOD_DEPTHTEX1, ivec2(newPos.xy/texelSize),0).x;
			}else{
				sampleDepth = convertHandDepth_2(texelFetch(depthtex1, ivec2(newPos.xy/texelSize),0).x,hand);
			}
		#else
			float sampleDepth = convertHandDepth_2(texelFetch(depthtex1, ivec2(newPos.xy/texelSize),0).x,hand);
		#endif

		float linearCurrentPos = swapperlinZ(newPos.z, _near, _far);
		float linearSampledDepth = swapperlinZ(sampleDepth, _near, _far);
		float dist = abs(linearSampledDepth - linearCurrentPos) / linearCurrentPos;
		
		if(sampleDepth < newPos.z){
			if (dist < 0.035/(1.0+linearCurrentPos)) shadows = 0.0;
			if (dist < SSSdistanceScale) SSS += distanceScale2;
		}else{
			if (dist < SSSdistanceScale*0.05) SSS += distanceScale2 * NdotL;
		}
		newPos += direction;
	}
	return vec2(shadows, SSS / float(samples));
}
#if HANDHELD_LIGHTSOURCE_SSRT_SHADOWS > 0
float handHeldLight_SSRT_Shadows(vec3 viewPos, vec3 shadowHandPos, float noise){

	vec3 shadowHandViewPos = mat3(gbufferModelView) * shadowHandPos;

	// funnt little thing to exaggerate the effec to shadows
	shadowHandViewPos.xy += (shadowHandViewPos.xy / (1.0+length(shadowHandPos)))*0.5;//*min(max(centerDepthSmooth-0.99,0.0)/0.01,1.0);
	vec3 lightDir = -shadowHandViewPos;

    float steps = 16.0;
	float _near = near; 
	float _far = far*4.0;

	vec3 position = toClipSpace3_DH(viewPos, false);
	//prevents the ray from going behind the camera
	float rayLength = ((viewPos.z + lightDir.z * _far*sqrt(3.)) > -_near) ?
      				  (-_near -viewPos.z) / lightDir.z : _far*sqrt(3.);

    vec3 direction = toClipSpace3_DH(viewPos + lightDir*rayLength, false) - position;
    
	if(firstPersonCamera){
		direction *= 0.001;
	}else{
		direction.xyz = direction.xyz / max(abs(direction.x)/0.0005, abs(direction.y)/0.0005);	//fixed step size
		direction *= 12.0;
	}

	position.xy *= RENDER_SCALE;
	direction.xy *= RENDER_SCALE;
	
	vec3 newPos = position + direction*noise;
	newPos += direction*0.3;
	for (int i = 0; i < int(steps); i++) {
		
		float samplePos = texture(depthtex2, newPos.xy).x;

		if(samplePos < newPos.z) return 0.0;

		newPos += direction;
	}

	return 1.0;
}
#endif

void Emission(
	inout vec3 Lighting,
	vec3 Albedo,
	float Emission
){
	if( Emission < 254.5/255.0) Lighting = mix(Lighting, Albedo * 5.0 * Emissive_Brightness, pow(Emission, Emissive_Curve));
}

#include "/lib/indirect_lighting_effects.glsl"

void doEdgeAwareBlur(
	sampler2D colortex_A, sampler2D colortex_B, sampler2D depth
	
	,float referenceDepth, bool hand
	
	,out vec2 ambientEffects, out vec3 filteredShadow
	// ,inout vec3 DEBUG
){
  vec3 result_A = vec3(0.0);
  vec2 result_B = vec2(0.0);
  float sum = 0.0;

//   #ifdef USING_LOD_MOD
//     float threshHold = referenceDepth*0.05 + 0.00001*0;
//   #else
//     float threshHold = referenceDepth*0.075 + 0.00001*0;
//   #endif

  #ifdef USING_LOD_MOD
    float threshHold = referenceDepth*0.005 + 0.00001*0;
  #else
    float threshHold = referenceDepth*0.0175 + 0.00001*0;
  #endif

  if(hand) threshHold = 0.00001;

	vec2 offsets[4] = vec2[](
    	vec2(-1.0,-1.0),
		vec2(-1.0, 1.0),
	 	vec2( 1.0, 1.0),
		vec2( 1.0,-1.0)
  );

  float edgeArea = 0.0;

  for(int i = 0; i < 4; i++) {
    
    ivec2 offsetTC = ivec2(gl_FragCoord.xy + offsets[i]);
    
	#ifdef USING_LOD_MOD
		float depthSample = sqrt(texelFetch(depth, offsetTC,0).a/65000.0);
    #else
    	float depthSample = ld(texelFetch(depth, offsetTC,0).r);
    #endif

    float w = abs(referenceDepth - depthSample) < threshHold ? 1.0 : 1e-7;

    result_A += texelFetch(colortex_A, offsetTC,0).rgb*w;
    result_B += texelFetch(colortex_B, offsetTC,0).rg*w;

    sum += w;
  }

  filteredShadow = result_A/sum * 0.8 + 0.2 * texture(colortex_A,texelSize*gl_FragCoord.xy).rgb;
  ambientEffects = result_B/sum * 0.8 + 0.2 * texture(colortex_B,texelSize*gl_FragCoord.xy).rg; 

//   filteredShadow = texture(colortex_A,texelSize*gl_FragCoord.xy).rgb;
//   ambientEffects = texture(colortex_B,texelSize*gl_FragCoord.xy).rg;

//   DEBUG = vec3(4.0-sum);
}

#ifdef OVERWORLD_SHADER

vec3 ComputeShadowMap_COLOR(
	in vec3 projectedShadowPosition, float distortFactor, float noise, float shadowBlockerDepth, out vec3 DEBUG
){

	// DEBUG = vec3(1.0);
	
	vec3 shadowColor = vec3(0);
	vec3 translucentTint = vec3(0.0);
	
	#if defined BASIC_SHADOW_FILTER
		int samples = SHADOW_FILTER_SAMPLE_COUNT;
		float rdMul = (shadowBlockerDepth*distortFactor*d0*k/shadowMapResolution) * 0.3;
		
		for(int i = 0; i < samples; i++){
			vec2 offsetS = CleanSample(i, samples - 1, noise) * rdMul;
			projectedShadowPosition.xy += offsetS;
	#else
		int samples = 1;
	#endif

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		#ifdef IS_IRIS
			float opaqueShadow = shadow2D(shadowtex0HW, projectedShadowPosition).x;
			float opaqueShadowT = shadow2D(shadowtex1HW, projectedShadowPosition).x;
		#else
			float opaqueShadow = shadow2D(shadowtex0, projectedShadowPosition).x;
			float opaqueShadowT = shadow2D(shadowtex1, projectedShadowPosition).x;
		#endif
		
		if(opaqueShadowT > opaqueShadow){
			shadowColor += texture(shadowcolor0, projectedShadowPosition.xy).rgb;
		}else{
			shadowColor += vec3(opaqueShadowT);
		}
	#else
		shadowColor += vec3(1.0) * shadow2D(shadowtex0HW, projectedShadowPosition).x;
	#endif
	
	#if defined BASIC_SHADOW_FILTER
		}
	#endif

	// #ifdef debug_SHADOWMAP
	// 	shadowDebug = shadow2D(shadow, projectedShadowPosition).x;
	// #endif
	// #ifdef TRANSLUCENT_COLORED_SHADOWS
		// directLightColor *= mix(vec3(1.0), translucentTint.rgb / samples, maxDistFade);
		// tintedSunlight *= translucentTint.rgb / samples;
	// #endif
	
	// return vec3(shadow2D(shadow, nooffset).x) * clamp(1.0-filterZone.x*5.0,0,1);

	return shadowColor.rgb / samples;
	// return mix(directLightColor, shadowColor.rgb / samples, maxDistFade);

}

#endif

float lumaSSS(vec3 color) {
	return dot(color,vec3(0.07, 0.72, 0.3));
}

float CustomPhase(float LightPos){

	float PhaseCurve = 1.0 - LightPos;
	float Final = exp2(sqrt(PhaseCurve) * -25.0);
	Final += exp(PhaseCurve * -10.0)*0.5;

	return Final;
}

vec3 SubsurfaceScattering_sun(vec3 albedo, float Scattering, float Density, float lightPos, float SS_shadows, float distantSSS, bool hand){
	// Density = 0.05;
	Scattering *= DIRECT_SSS_DENSITY_MULT;
	float density = 1e-6 + Density*2.0;

	#ifdef OLD_SSS_MODE
		float scatterGradient = max(1.0 - Scattering/density, 0.0);
		scatterGradient *= exp(-7.0 * (1.0-scatterGradient));
		scatterGradient *=mix(exp(-4.0 * SS_shadows), 1.0, (1.0-SCREENSPACE_DIRECT_SSS_BLENDING) * scatterGradient * distantSSS);
		if(hand) scatterGradient = max(1.0 - Scattering*10.0, 0.0) * exp(-4.0 * SS_shadows);
		vec3 absorbColor = exp(max(luma(albedo) - albedo*vec3(1.0,1.1,1.2), 0.0) * -20.0);
		vec3 scatter = scatterGradient*mix(absorbColor, vec3(1.0), scatterGradient);
		scatter *= albedo;
	#else
		float scatterGradient = exp(-7.0 * (1.0-max(1.0 - Scattering/density, 0.0)));
			// return vec3(scatterGradient);
		vec3 absorbColor = max(albedo + (albedo - lumaSSS(albedo))*(1.0-scatterGradient) * (float(DIRECT_SSS_ABSORBANCE_AMOUNT)/100.0f),0.0);
			// return vec3(absorbColor);
		// SSS for screenspace shadows
		#ifdef DISTANT_SSS
			scatterGradient *= mix(exp(-6.0 * SS_shadows), 1.0, (1.0-SCREENSPACE_DIRECT_SSS_BLENDING) * distantSSS);
		#endif
		// SSS for screenspace shadows on the hand
		if(hand) scatterGradient = max(1.0 - Scattering*10.0, 0.0) * exp(-4.0 * SS_shadows);
		vec3 scatter = scatterGradient*absorbColor;
	#endif


	#if SSS_TYPE == 3
		scatter *= pow(Density, LabSSS_Curve);
	#else
		if(Density < 0.01) scatter = vec3(0.0);
	#endif
	
	scatter *= 1.0 + CustomPhase(lightPos)*6.0; // ~10x brighter at the peak

	return scatter * DIRECT_SSS_BRIGHTNESS;	
}

float indirectSSS_phase(float LightPos){

	float curve = LightPos;

	curve = curve*0.5+0.5;

	curve *= curve;
	curve = 1.0-curve;
	curve *= curve*curve;
	curve = 1.0-curve;

	curve += 1.0;

	return curve;
}

vec3 SubsurfaceScattering_sky(vec3 albedo, float Scattering, float Density, float lightPos){
	// Density = 1.0;

	#ifdef OLD_SSS_MODE
		float scatterDepth = pow(Scattering,3.5);
		scatterDepth = 1.0-pow(1.0-scatterDepth,5.0);
		vec3 absorbColor = exp(max(luma(albedo) - albedo*vec3(1.0,1.1,1.2), 0.0) * -20.0);
		vec3 scatter = scatterDepth * mix(absorbColor, vec3(1.0), scatterDepth);
		scatter *= albedo;
	#else
		//// curve making sins
		float scatterDepth = exp(-7.0*(1.0-pow(1.0-pow(1.0-Scattering,4.0),5.0)))*1.25;
			// return vec3(scatterDepth);
		float saturationGradient = exp(-10.0*exp(-8.0*pow(1.0-Scattering,2.0)));
			// return vec3(saturationGradient);
		vec3 absorbColor = max(albedo + (albedo - lumaSSS(albedo)) * saturationGradient * (float(INDIRECT_SSS_ABSORBANCE_AMOUNT)/100.0f),0.0);
			// return vec3(absorbColor);
		vec3 scatter = scatterDepth*absorbColor;
	#endif


	#if SSS_TYPE == 3
		scatter *= pow(Density, LabSSS_Curve);
	#else
		if(Density < 0.01) scatter = vec3(0.0);
	#endif

	scatter *= indirectSSS_phase(lightPos); // ~2x brighter at the peak

	return scatter;
}

uniform float wetnessAmount;

void applyPuddles(
	in vec3 worldPos, in vec3 flatNormals, in float lightmap, in bool isWater, in float porosity, inout vec3 albedo, inout vec3 normals, inout float roughness, inout float f0
){
#if PUDDLE_MODE > 0
	/* PUDDLE_MODE
		0 = OFF, NO WETNESS
		1 = puddles + full wetness
		2 = only puddles
		3 = only full wetness
	*/
	vec3 unchangedNormals = normals;

	float halfWet = min(wetnessAmount,1.0);
	float fullWet = clamp(wetnessAmount - 2.0,0.0,1.0);
	// halfWet = 1.0;
 	// fullWet = 0.0;

	vec2 driprate = vec2(0.0,frameTimeCounter)*0.05;

	vec2 UV = mix(worldPos.xz, worldPos.xy*vec2(2.0, 0.5)+driprate, pow(abs(flatNormals.z),2));
	UV = mix(UV, worldPos.zy*vec2(2.0, 0.5)+driprate, pow(abs(flatNormals.x),2));

	float noise = texture(noisetex, UV * 0.02).b;

	#ifdef IS_LPV_ENABLED
		vec3 lpvPos = GetVoxelPosition(worldPos - cameraPosition);
		float skyLightMask = SampleLpvLinear(lpvPos).a;
		float skyLightMax = 1.0 - (3./15.)*skyLightMask;

		lightmap = min(lightmap, skyLightMax);
	#endif

	float lightmapMax = min(max(lightmap - 0.9,0.0) * 10.0,1.0) ;
	float lightmapMin = min(max(lightmap - 0.8,0.0) * 5.0,1.0) ;
	lightmap = clamp(lightmapMax + noise*lightmapMin*2.0,0.0,1.0);
	lightmap = pow(1.0-pow(1.0-lightmap,3.0),2.0);
	
	#if PUDDLE_MODE == 1
		float puddles = max(halfWet - noise,0.0);
		puddles = clamp(halfWet - exp(-25.0 * puddles*puddles*puddles*puddles*puddles),0.0,1.0);
		
		float wetnessStages = max(puddles, fullWet) * lightmap;
		float wetnessDarkening = max(puddles, fullWet*0.5) * lightmap;
	#endif

	#if PUDDLE_MODE == 2
		float puddles = max(halfWet - noise,0.0);
		puddles = clamp(halfWet - exp(-25.0 * puddles*puddles*puddles*puddles*puddles),0.0,1.0);
	
		float wetnessStages = puddles * lightmap;
		float wetnessDarkening = wetnessStages;
	#endif

	#if PUDDLE_MODE == 3
		float puddles = 0.0;
		float wetnessStages = fullWet * lightmap;
		float wetnessDarkening = wetnessStages*0.5;
	#endif

	if(isWater) wetnessStages = 0.0;

	normals = mix(normals, flatNormals, puddles * lightmap * clamp(flatNormals.y,0.0,1.0));
	roughness = mix(roughness, 1.0, wetnessStages);

	if(f0 < 229.5/255.0 ) albedo = pow(albedo * (1.0 - 0.08*wetnessDarkening), vec3(1.0 + 0.7*wetnessDarkening));

	//////////////// snow
	
	// float upnormal = clamp(-(normals / dot(abs(normals),vec3(1.0))).y+clamp(flatNormals.y,0.5,1.0),0,1);
	// halfWet = clamp(halfWet - upnormal - (1.0-lightmap),0.0,1.0);
	// float snow = max(halfWet - noise,0.0);
	// snow = clamp(halfWet - exp(-20.0 * snow*snow*snow*snow*snow),0.0,1.0);
	
	// if(isWater || f0 > 229.5/255.0) snow = 0.0;

	// normals = mix(normals, unchangedNormals, snow);
	// roughness = mix(roughness, 0.5, snow);
	// albedo = mix(albedo, vec3(1.0), snow);
#endif
}

// uniform int randomInteger;
uniform float centerDepthSmooth;

void main() {

		vec3 DEBUG = vec3(0.0);

	////// --------------- SETUP STUFF --------------- //////
		vec2 texcoord = (gl_FragCoord.xy*texelSize);
	
		float noise_2 = R2_dither();
		vec2 bnoise = blueNoise(gl_FragCoord.xy).rg;
		float ig_noise = interleaved_gradientNoise_temporal();

		#if TAA_MODE > 0
			int seed = frameCounter*8%40000;
		#else
			int seed = 600;
		#endif

		vec2 r2_sequence = R2_samples(seed).xy;
		vec2 BN = fract(r2_sequence + bnoise);
		float noise = BN.y;


		// float z0 = texture(depthtex0,texcoord).x;
		// float z = texture(depthtex1,texcoord).x;
		float z0 = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x;
		float z =  texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).x;
		float swappedDepth = z;

		bool isDHrange = z >= 1.0;

		#ifdef USING_LOD_MOD
	  		float DH_mixedLinearZ = sqrt(texelFetch(colortex12,ivec2(gl_FragCoord.xy),0).a/65000.0);
			float DH_depth0 = texture(LOD_DEPTHTEX0,texcoord).x;
			float DH_depth1 = texture(LOD_DEPTHTEX1 ,texcoord).x;

			// DEBUG = vec3(DH_mixedLinearZ)*255;

			float depthOpaque = z;
			float depthOpaqueL = linearizeDepthFast(depthOpaque, near, farPlane);
			
			#ifdef USING_LOD_MOD
			    float dhDepthOpaque = DH_depth1;
			    float dhDepthOpaqueL = linearizeDepthFast(dhDepthOpaque, dhNearPlane, dhFarPlane);

				if (depthOpaque >= 1.0 || (dhDepthOpaqueL < depthOpaqueL && dhDepthOpaque > 0.0)){
			        depthOpaque = dhDepthOpaque;
			        depthOpaqueL = dhDepthOpaqueL;
			    }
			#endif

			swappedDepth = depthOpaque;
		#else
			float DH_depth0 = 0.0;
			float DH_depth1 = 0.0;
		#endif

	////// --------------- UNPACK OPAQUE GBUFFERS --------------- //////
	
		vec4 data = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);

		vec3 skyboxCol = data.rgb;

		vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y)); // albedo, masks
		vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w)); // normals, lightmaps
		// vec4 dataUnpacked2 = vec4(decodeVec2(data.z),decodeVec2(data.w));

		vec3 albedo = toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));


		vec3 normal = decode(dataUnpacked0.yw);

		if(isDHrange) normal = viewToWorld(normal);

		vec2 lightmap = dataUnpacked1.yz;
		// special curve to give more precision on high/low values of the gradient. this curve will be inverted after sampling and decoding.
		// lightmap = 1.0-pow(1.0-pow(lightmap,vec2(2)),vec2(2));
		// small offset to hide flickering from precision error in the encoding/decoding on values close to 1.0 or 0.0
		lightmap.xy = min(max(lightmap.xy - 0.05,0.0)*1.06,1.0);
		
		#if MC_VERSION < 12109
			#if !defined OVERWORLD_SHADER
				lightmap.y = 1.0;
			#endif
		#else
			#if !defined OVERWORLD_SHADER && !defined END_SHADER
				lightmap.y = 1.0;
			#endif
		#endif


	////// --------------- UNPACK MISC --------------- //////
	
		vec4 specdata = texelFetch(colortex8, ivec2(gl_FragCoord.xy), 0);
		
		vec4 specdataUnpacked0 = vec4(decodeVec2(specdata.x),decodeVec2(specdata.y));
		vec4 specdataUnpacked1 = vec4(decodeVec2(specdata.z),decodeVec2(specdata.w));

		vec4 SpecularTex = vec4(specdataUnpacked0.xz, specdataUnpacked1.xz);
		vec3 FlatNormals = normalize(vec3(specdataUnpacked0.yw,specdataUnpacked1.y) * 2.0 - 1.0);
		float vanilla_AO = min(max(specdataUnpacked1.w-0.005,0.0)/0.995,1.0);

		float LabSSS = clamp((-65.0 + SpecularTex.z * 255.0) / 190.0 ,0.0,1.0);	
		float labPorosity = clamp(SpecularTex.z * 255.0, 0.0,64.5)/64.5;	

		vec3 slopednormal = normal;
		if(isDHrange){
			FlatNormals = normal;
			slopednormal = normal;
		}


	////// --------------- MASKS/BOOLEANS --------------- //////
		// 1.0-0.8 ???
		// 0.75 = hand mask
		// 0.60 = grass mask
		// 0.55 = leaf mask (for ssao-sss)
		// 0.50 = lightning bolt mask
		// 0.45 = entity mask
		float opaqueMasks = dataUnpacked1.w;
		
		#if defined POM && defined POM_OFFSET_SHADOW_BIAS
			float shadowCutMask = opaqueMasks < 0.45 ? min(max(opaqueMasks/0.45,0.0)*3.0,1.0) : 0.0;
		#endif

		// 1.0 = water mask
		// 0.9 = entity mask
		// 0.8 = reflective entities
		// 0.7 = reflective blocks
  		float translucentMasks = texture(colortex7, texcoord).a;

		bool isWater = translucentMasks > 0.99;

		// bool isReflectiveEntity = abs(translucentMasks - 0.8) < 0.01;
		// bool isReflective = abs(translucentMasks - 0.7) < 0.01 || isWater || isReflectiveEntity;
		// bool isEntity = abs(translucentMasks - 0.9) < 0.01 || isReflectiveEntity;

		bool lightningBolt = abs(opaqueMasks-0.5) <0.01;
		bool isLeaf = abs(opaqueMasks-0.55) <0.01;
		bool entities = abs(opaqueMasks-0.45) < 0.01;	
		bool isGrass = abs(opaqueMasks-0.60) < 0.01;
		bool hand = abs(opaqueMasks-0.75) < 0.01 && z < 1.0;
		// bool handwater = abs(translucentMasks-0.3) < 0.01 ;
		bool opaqueParticles = abs(opaqueMasks-0.8) < 0.01;

		if(hand){
			convertHandDepth(z);
			convertHandDepth(z0);
		}

		#ifdef USING_LOD_MOD
			vec3 viewPos = toScreenSpace_DH(texcoord/RENDER_SCALE - taaJitter*texelSize*0.5/RENDER_SCALE, z, DH_depth1);
			vec3 viewPosNoJitter = toScreenSpace_DH(texcoord/RENDER_SCALE, z, DH_depth1);
		#else
			vec3 viewPos = toScreenSpace(vec3(texcoord/RENDER_SCALE - taaJitter*texelSize*0.5/RENDER_SCALE, z));
			vec3 viewPosNoJitter = toScreenSpace(vec3(texcoord/RENDER_SCALE, z));
		#endif
		
		vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
		vec3 feetPlayerPos_normalized = normalize(playerPos);

		#ifdef POM
			#ifdef Horrible_slope_normals
    			vec3 ApproximatedFlatNormal = normalize(cross(dFdx(playerPos), dFdy(playerPos))); // it uses depth that has POM written to it.
				slopednormal = normalize(clamp(normal, ApproximatedFlatNormal*2.0 - 1.0, ApproximatedFlatNormal*2.0 + 1.0) );
			#endif
		#endif

		// vec3 viewTest = toScreenSpace(vec3(texcoord/RENDER_SCALE, z));
		// vec3 playerTest = mat3(gbufferModelViewInverse) * viewTest + gbufferModelViewInverse[3].xyz;
		// vec3 viewTest2 = toScreenSpace(vec3(texcoord/RENDER_SCALE, texelFetch(depthtex1, ivec2(0.5/texelSize), 0).x));
		// playerTest -= playerLookVector * -(viewTest2.z+1.0);

		// DEBUG = playerTest;
		// DEBUG = vec3(1.0) * clamp(1.0-length(playerTest)/16.0,0,1) * clamp(dot(-playerTest, slopednormal),0,1);
	////// --------------- COLORS --------------- //////

		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 scatterCoef = Dirt_Amount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

		vec3 Absorbtion = vec3(1.0);
		vec3 AmbientLightColor = vec3(0.0);
		vec3 MinimumLightColor = vec3(1.0);
		vec3 Indirect_lighting = vec3(0.0);
		vec3 Indirect_SSS = vec3(0.0);
		vec2 SSAO_SSS = vec2(1.0);
		
		vec3 DirectLightColor = vec3(0.0);
		vec3 Direct_lighting = vec3(0.0);
		vec3 Direct_SSS = vec3(0.0);
		float cloudShadow = 1.0;
		float Shadows = 1.0;
		float shadowTest = 1.0;


		vec3 shadowColor = vec3(1.0);
		vec3 SSSColor = vec3(0.0);
		vec3 filteredShadow = vec3(Min_Shadow_Filter_Radius,1.0,0.0);

		float NdotL = 1.0;
		float lightLeakFix = clamp(pow(eyeBrightnessSmooth.y/240. + lightmap.y,2.0) ,0.0,1.0);

		#ifdef OVERWORLD_SHADER

			DirectLightColor = lightCol.rgb / 2400.0;
			AmbientLightColor = averageSkyCol_Clouds / 900.0;

			#ifdef FAKE_PLANET
				DirectLightColor = getPlanetAbsorb(playerPos + cameraPosition, WsunVec, colortex4);
			#endif
			
			#ifdef USE_CUSTOM_DIFFUSE_LIGHTING_COLORS
				DirectLightColor.rgb = luma(DirectLightColor.rgb) * vec3(DIRECTLIGHT_DIFFUSE_R,DIRECTLIGHT_DIFFUSE_G,DIRECTLIGHT_DIFFUSE_B);
				AmbientLightColor = luma(AmbientLightColor) * vec3(INDIRECTLIGHT_DIFFUSE_R,INDIRECTLIGHT_DIFFUSE_G,INDIRECTLIGHT_DIFFUSE_B);
			#endif
			
			shadowColor = DirectLightColor;

			bool inShadowmapBounds = false;
		#endif

		MinimumLightColor = MinimumLightColor + 0.7 * MinimumLightColor * dot(slopednormal, feetPlayerPos_normalized);


			////////////////////////////////////////////////////////////////////////////////////////////
			////////////////////////////////	UNDER WATER SHADING		////////////////////////////////
			////////////////////////////////////////////////////////////////////////////////////////////
		
 			if ((isEyeInWater == 0 && isWater) || (isEyeInWater == 1 && !isWater)){
			
				#ifdef USING_LOD_MOD
					vec3 playerPos0 = mat3(gbufferModelViewInverse) *  toScreenSpace_DH(texcoord/RENDER_SCALE-taaJitter*texelSize*0.5, z0, DH_depth0) + gbufferModelViewInverse[3].xyz;
				#else
					vec3 playerPos0 = mat3(gbufferModelViewInverse) * toScreenSpace(vec3(texcoord/RENDER_SCALE-taaJitter*texelSize*0.5,z0)) + gbufferModelViewInverse[3].xyz;
				#endif

				underWaterAbsorbance_outsidePOV(
    				playerPos0, playerPos, feetPlayerPos_normalized,
    				WsunVec, // (normalize(cross(dFdx(playerPos), dFdy(playerPos))).y > 0.01 ? 1.0 : 0.0),
    				totEpsilon, Absorbtion, DirectLightColor, lightLeakFix
				);
			}

	if (swappedDepth < 1.0) {
		////////////////////////////////////////////////////////////////////////////////////////////
		///////////////////////////////////	    FILTER STUFF      //////////////////////////////////
		////////////////////////////////////////////////////////////////////////////////////////////

		#ifdef USING_LOD_MOD
			doEdgeAwareBlur(colortex3,colortex14, colortex12, DH_mixedLinearZ, hand, SSAO_SSS, filteredShadow);
		#else
			doEdgeAwareBlur(colortex3,colortex14, depthtex0, ld(z0), 	hand, SSAO_SSS, filteredShadow);
		#endif
		
		float ShadowBlockerDepth = filteredShadow.y;

	////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	MAJOR LIGHTSOURCE STUFF 	////////////////////////
	////////////////////////////////////////////////////////////////////////////////////
	
	#ifdef OVERWORLD_SHADER
		float LM_shadowMapFallback =  clamp(lightmap.y, 0.0,1.0);
		NdotL = clamp((-15 + dot(slopednormal, WsunVec)*255.0) / 240.0  ,0.0,1.0);
		float flatNormNdotL = clamp((-15 + dot((FlatNormals), WsunVec)*255.0) / 240.0  ,0.0,1.0);

		if(opaqueParticles){
			NdotL = 0.75;
			flatNormNdotL = 0.75;
		}
		
	////////////////////////////////	SHADOWMAP		////////////////////////////////
		float shadowMapBounds = shadowMapBounds(playerPos);

		// setup shadow projection
		// float shadowMapFalloff = smoothstep(0.0, 1.0, min(max(1.0 - length(playerPos) / (shadowDistance+32.0),0.0)*5.0,1.0));
		float shadowMapFalloff2 = shadowMapBounds;// smoothstep(0.0, 1.0, min(max(1.0 - length(playerPos) / shadowDistance,0.0)*5.0,1.0));

		// if(isEyeInWater == 1){
		// 	shadowMapFalloff = 1.0;
		// 	shadowMapFalloff2 = 1.0;
		// }
		
		vec3 shadowPlayerPos = playerPos;

		#if LIGHTLEAKFIX_MODE == 1
			if(!hand) GriAndEminShadowFix(shadowPlayerPos, FlatNormals, lightLeakFix);
		#endif

		vec3 projectedShadowPosition = mat3(shadowModelView) * shadowPlayerPos + shadowModelView[3].xyz;
		
		applyShadowBias(projectedShadowPosition, shadowPlayerPos, FlatNormals);

		projectedShadowPosition = diagonal3_old(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		// vec3 trestpos = projectedShadowPosition;
		// Calclulate distortion factor before bias application
		#ifdef DISTORT_SHADOWMAP
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;
		#else
			float distortFactor = 1.0;
		#endif

		#if defined POM && defined POM_OFFSET_SHADOW_BIAS
			// the idea is to cut the shadows starting position, interpolating down to the lowest depth of POM within a block.
			projectedShadowPosition.z += shadowProjection[3].z * (0.0012 + 0.035 * (float(POM_DEPTH)/100.0) * shadowCutMask);
		#else
			projectedShadowPosition.z += shadowProjection[3].z * 0.0012;
		#endif

		projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5) ;

		shadowColor = ComputeShadowMap_COLOR(projectedShadowPosition, distortFactor, noise_2, filteredShadow.x, DEBUG);
		
		shadowColor = mix(vec3(1.0), shadowColor, shadowMapBounds);
		ShadowBlockerDepth = mix(0.0,ShadowBlockerDepth,shadowMapBounds);

		shadowMapFalloff2 = shadowMapBounds;
		// shadowMapFalloff = shadowMapBounds;


		// transition to fallback lightmap shadow mask.
		// shadowColor *= mix(isWater ? lightLeakFix : LM_shadowMapFallback, 1.0, shadowMapFalloff2);

		#if LIGHTLEAKFIX_MODE == 2
			if(isEyeInWater != 1) shadowColor *= lightLeakFix; // light leak fix
		#endif

	////////////////////////////////	SUN SSS		////////////////////////////////
		#if SSS_TYPE != 0
			float sunSSS_density = LabSSS;
			
			#ifdef USING_LOD_MOD
				shadowMapFalloff2 = smoothstep(0.0, 1.0, min(max(1.0 - length(playerPos) / min(shadowDistance, max(far-32.0,32.0)),0.0)*5.0,1.0));
			#endif

			#ifndef RENDER_ENTITY_SHADOWS
				if(entities) sunSSS_density = 0.0;
			#endif
			
			#ifdef SCREENSPACE_CONTACT_SHADOWS
				// vec2 SS_directLight = SSRT_Shadows(viewPosNoJitter + (mat3(gbufferModelView)*(FlatNormals - FlatNormals*min(WsunVec,0.5)*1.6))*0.01, isDHrange, normalize(WsunVec*mat3(gbufferModelViewInverse)), ig_noise, sunSSS_density > 0.0 && shadowMapFalloff2 < 1.0, hand, clamp(-dot(feetPlayerPos_normalized, WsunVec),0,1) * flatNormNdotL);
				vec2 SS_directLight = SSRT_Shadows(viewPosNoJitter, isDHrange, normalize(WsunVec*mat3(gbufferModelViewInverse)), ig_noise, sunSSS_density > 0.0 && shadowMapFalloff2 < 1.0, hand, clamp(-dot(feetPlayerPos_normalized, WsunVec),0,1) * flatNormNdotL);
				// combine shadowmap with screenspace shadows.
				// if(hideGUI == 0)
				//  SS_directLight.x = filteredShadow.b;

				if(!opaqueParticles) shadowColor *= SS_directLight.r;
				// if(!opaqueParticles) shadowColor = vec3(SS_directLight.r);
			#else
				vec2 SS_directLight = vec2(1,0);
				ShadowBlockerDepth = max(ShadowBlockerDepth, 1.0-shadowMapBounds);
			#endif

			SSSColor = SubsurfaceScattering_sun(albedo, ShadowBlockerDepth, sunSSS_density, clamp(dot(feetPlayerPos_normalized, WsunVec),0.0,1.0), SS_directLight.g, shadowMapBounds, hand);

			if(isEyeInWater != 1) SSSColor *= lightLeakFix;
		#endif

	
		float cloudShadows = GetCloudShadow(playerPos.xyz + cameraPosition, WsunVec);
		shadowColor *= cloudShadows;
		SSSColor *= cloudShadow*cloudShadows;
	
	#endif

	#ifdef END_SHADER

		#ifdef END_LIGHTNING
			float vortexBounds = clamp(vortexBoundRange - length(playerPos+cameraPosition), 0.0,1.0);
		#else
			float vortexBounds = 1.0;
		#endif
		
		float lightningflash = 0.0;
        vec3 lightPos = LightSourcePosition(playerPos+cameraPosition, cameraPosition,vortexBounds, lightningflash);
		vec3 lightColors = pow(lightmap.y,5) * LightSourceColors(vortexBounds, lightningflash);
		
		float end_NdotL = clamp(dot(slopednormal, normalize(-lightPos))*0.5+0.5,0.0,1.0);
		end_NdotL *= end_NdotL;

		float fogShadow = GetEndFogShadow(playerPos+cameraPosition, lightPos);
		float endPhase = endFogPhase(lightPos);

		Direct_lighting += lightColors * endPhase * end_NdotL * fogShadow;
	#endif
	

	/////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	INDIRECT LIGHTING 	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////

		#if defined OVERWORLD_SHADER
			float skylight = 1.0;
			float skylight2 = 1.0;
		
			#if indirect_effect == VANILLA_AO || indirect_effect == SSAO_FILTERED || indirect_effect == SSAO_HQ || indirect_effect == GTAO

				vec3 indirectNormal = slopednormal / dot(abs(slopednormal),vec3(1.0));

				float SkylightDir = indirectNormal.y;

				if(isGrass || opaqueParticles) SkylightDir = 1.0;
				
				#if indirect_effect == VANILLA_AO
					SkylightDir = clamp(SkylightDir*0.7+0.3, 0.0, pow(1-pow(vanilla_AO, 2),4) * 0.7 + 0.3);
				#else
					SkylightDir = clamp(SkylightDir*0.7+0.3, 0.0, pow(1-pow(1-SSAO_SSS.x, 0.5),4.0) * 0.7 + 0.3);
				#endif

				skylight = mix(0.08 + 0.92*(1.0-lightmap.y), 1.0, SkylightDir);
				skylight2 = mix( 1.0-lightmap.y, 1.0, indirectNormal.y*0.7+0.3);
				// skylight2 = mix( 1.0-lightmap.y, 1.0, SkylightDir);

				// skylight = 1.0;
				// skylight = mix(skylight,1.0,LabSSS);
			#endif

			#if indirect_effect == SSRT_AO || indirect_effect == SSRT_AO_GI
				skylight = 1.0;
			#endif
			
			Indirect_lighting += doIndirectLighting(AmbientLightColor*skylight, MinimumLightColor, lightmap.y);
		#endif

		#ifdef NETHER_SHADER
			Indirect_lighting = volumetricsFromTex(normalize(normal), colortex4, 6).rgb / 1200.0;
			vec3 up = volumetricsFromTex(vec3(0.0,1.0,0.0), colortex4, 6).rgb / 1200.0;
			
			#if indirect_effect == SSAO_FILTERED || indirect_effect == SSAO_HQ
				Indirect_lighting = mix(up, Indirect_lighting,  clamp(pow(1.0-pow(1.0-SSAO_SSS.x, 0.5),2.0),0.0,1.0));
			#endif
			
			// Indirect_lighting *= 0.5;
			AmbientLightColor = Indirect_lighting;
		#endif
		
		#ifdef END_SHADER
			Indirect_lighting = vec3(0.1);

			Indirect_lighting = vec3(0.3,0.6,1.0);
			
			Indirect_lighting = Indirect_lighting + 0.7*mix(-Indirect_lighting, Indirect_lighting * dot(slopednormal, feetPlayerPos_normalized), clamp(pow(1.0-pow(1.0-SSAO_SSS.x, 0.5),2.0),0.0,1.0));
			Indirect_lighting *= 0.035 * lightmap.y*lightmap.y;

			Indirect_lighting +=  lightColors * (endPhase*endPhase) * (1.0-exp(vec3(0.6,2.0,2.0) * -(endPhase*0.01))) /1000.0;

    		// float minimumLightAmount = 0.02*nightVision + 0.005 * mix(MINIMUM_INDOOR_LIGHT, MINIMUM_OUTDOOR_LIGHT, clamp(eyeBrightnessSmooth.y/240.0 + lightmap.y,0.0,1.0));
    		// Indirect_lighting += MinimumLightColor * minimumLightAmount;
			Indirect_lighting += MinimumLightColor * (MIN_LIGHT_AMOUNT * 0.02 * 0.2 + nightVision*0.02);
		#endif
		
		#ifdef IS_LPV_ENABLED
			vec3 normalOffset = vec3(0.0);

			if (any(greaterThan(abs(FlatNormals), vec3(1.0e-6))))
				normalOffset = 0.5*(FlatNormals);

			#if LPV_NORMAL_STRENGTH > 0
				vec3 texNormalOffset = -normalOffset + slopednormal;
				normalOffset = mix(normalOffset, texNormalOffset, (LPV_NORMAL_STRENGTH*0.01));
			#endif

			vec3 lpvPos = GetVoxelPosition(playerPos) + normalOffset;
		#else
			const vec3 lpvPos = vec3(0.0);
		#endif

		vec3 blockLightColor = doBlockLightLighting( vec3(TORCH_R,TORCH_G,TORCH_B), lightmap.x, playerPos, lpvPos);
		Indirect_lighting += blockLightColor;
		
		// turn into struct later
		vec3 mainHandPos = vec3(0.0);
		vec3 mainHandCol = vec3(0.0);
		vec3 offHandPos = vec3(0.0);
		vec3 offHandCol = vec3(0.0);

		#if HANDHELD_LIGHTSOURCE_MODE > 0
			vec3 handheldViewPos = viewPosNoJitter;
			if(hand) handheldViewPos.z += 0.7;

			doHandHeldLight(
				handheldViewPos, slopednormal
				,mainHandPos, mainHandCol, offHandPos, offHandCol
			);

			#if HANDHELD_LIGHTSOURCE_SSRT_SHADOWS > 0
				// make sure not to calculate ssrt shadows if there is no light being held.
				#if HANDHELD_LIGHTSOURCE_SSRT_SHADOWS == 1
					if(!hand && (heldBlockLightValue > 0 || heldBlockLightValue2 > 0)){
				#elif HANDHELD_LIGHTSOURCE_SSRT_SHADOWS == 2
					if((firstPersonCamera && !hand) && (heldBlockLightValue > 0 || heldBlockLightValue2 > 0)){
				#endif

					// whichever held light is brighter gets the shadows
					vec3 shadowHandPos = heldBlockLightValue > heldBlockLightValue2 ? mainHandPos : offHandPos;
					float handHeldLightShadow = handHeldLight_SSRT_Shadows(viewPosNoJitter + (mat3(gbufferModelView)*slopednormal)*(1-min(max(centerDepthSmooth-0.9,0)/0.1,1))*0.05*0, shadowHandPos, ig_noise);

					// whichever held light is brighter gets the shadows 2x
					if(heldBlockLightValue < heldBlockLightValue2){
						offHandCol *= handHeldLightShadow;
					}else{
						mainHandCol *= handHeldLightShadow;
					}
				}
			#endif

			Indirect_lighting += mainHandCol + offHandCol;
		#endif

		#if defined LIGHTNING_FLASH
			Indirect_lighting += createLightningPointLight(playerPos, lightningBoltPosition.xyz, slopednormal) * lightmap.y*lightmap.y*lightmap.y*lightmap.y;
		#endif
	/////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	EFFECTS FOR INDIRECT	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////

		float SkySSS = 1.0;
		SkySSS = SSAO_SSS.y;
		
		vec3 AO = vec3(1.0);

		#if indirect_effect == 0
			AO = vec3(pow(1.0 - vanilla_AO*vanilla_AO,5.0));
			Indirect_lighting *= AO;
		#endif

		#if indirect_effect == SSAO_FILTERED || indirect_effect == SSAO_HQ
			// float vanillaAO_curve = pow(1.0 - vanilla_AO*vanilla_AO,5.0);
			float SSAO_curve = pow(SSAO_SSS.x,4.0);
			// use the min of vanilla ao so they dont overdarken eachother
			// AO = vec3( min(vanillaAO_curve, SSAO_curve) );
			AO = vec3( SSAO_curve );
			Indirect_lighting *= AO;
		
		#elif indirect_effect == GTAO

			float vanillaAO_curve = pow(1.0 - vanilla_AO*vanilla_AO,5.0);
			AO = vec3(min(vanillaAO_curve,SSAO_SSS.x));
			Indirect_lighting *= AO;
		#endif

		// RTAO and/or SSGI
		#if indirect_effect == SSRT_AO || indirect_effect == SSRT_AO_GI
			#ifdef SKY_CONTRIBUTION_IN_SSRT
				blockLightColor += mainHandCol + offHandCol;
			#endif
			#ifdef UseQuarterResDepth
				// vec3 newVeiwPos = toScreenSpace(vec3(texcoord, ,z));
				vec3 newVeiwPos = toScreenSpace(vec3(texcoord/RENDER_SCALE - taaJitter*texelSize*0.5/RENDER_SCALE, min(invLinZ(sqrt(texture(colortex4, gl_FragCoord.xy*texelSize/4.0).a/65000.0)),z)));
			#else
				vec3 newVeiwPos = viewPos;
			#endif

			newVeiwPos = viewPos;
			
			if(!hand) Indirect_lighting = ApplySSRT(Indirect_lighting, blockLightColor, MinimumLightColor, viewPos, normal, vec3(bnoise, noise_2), lightmap.y, isGrass, isDHrange);
		#endif

	////////////////////////////////////////////////////////////////////////////////
	/////////////////////////	SUB SURFACE SCATTERING	////////////////////////////
	////////////////////////////////////////////////////////////////////////////////
	
	/////////////////////////////	SKY SSS		/////////////////////////////
		#if defined Ambient_SSS && defined OVERWORLD_SHADER && (indirect_effect == SSAO_FILTERED || indirect_effect == SSAO_HQ)
			
			vec3 ambientColor = AmbientLightColor * ambientsss_brightness * ambient_brightness;

			Indirect_SSS = SubsurfaceScattering_sky(albedo, SkySSS, LabSSS, feetPlayerPos_normalized.y);
			Indirect_SSS *= lightmap.y;
			Indirect_SSS *= ambientColor;

			// Indirect_lighting += Indirect_SSS * ambientColor;
		#endif
	
	/////////////////////////////////////////////////////////////////////////
	/////////////////////////////	FINALIZE	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////

		#ifdef SSS_view
			albedo = vec3(1.0);
			NdotL = 0;
			Indirect_lighting = vec3(0.1);
		#endif
		#if defined END_SHADER
			Direct_lighting *= AO;
		#endif

		#if PUDDLE_MODE > 0 && defined OVERWORLD_SHADER && defined DEFERRED_SPECULAR
			if(!hand && !entities) applyPuddles(playerPos + cameraPosition, FlatNormals, lightmap.y, isWater, labPorosity, albedo, normal, SpecularTex.r, SpecularTex.g);
		#endif

		#ifdef OVERWORLD_SHADER
			vec3 FINAL_COLOR = (
				#ifdef OLD_SSS_MODE
				+ Indirect_SSS
				+ Indirect_lighting * albedo
				#else
				+ Indirect_SSS * (1.0-skylight2*0.8) + Indirect_lighting * albedo
				#endif
				// + Indirect_SSS
				//  + DirectLightColor * albedo * NdotL*shadowColor * (AO*0.7+0.3)
				//  + SSSColor
				#ifdef AO_in_sunlight
				+ DirectLightColor * mix(SSSColor, albedo, NdotL*shadowColor*(AO*0.7+0.3))
				#else
				+ DirectLightColor * mix(SSSColor, albedo, NdotL*shadowColor)
				#endif
			);
		#else
			vec3 FINAL_COLOR = (Indirect_lighting + Direct_lighting) * albedo;
		#endif

		Emission(FINAL_COLOR, albedo, SpecularTex.a);
		
		if(lightningBolt) FINAL_COLOR = vec3(77.0, 153.0, 255.0);
		
		#if defined DEFERRED_SPECULAR	
			vec3 specularNoises = vec3(vec2(blueNoise(), ig_noise), ig_noise);
			FINAL_COLOR = specularReflections(viewPos, normalize(playerPos - gbufferModelViewInverse[3].xyz), WsunVec, specularNoises, normal, SpecularTex.r, SpecularTex.g, albedo, FINAL_COLOR, DirectLightColor*shadowColor, lightmap.y, hand, normalize(mainHandPos), mainHandCol, normalize(offHandPos), offHandCol, z0);
		#endif

		gl_FragData[0].rgb = FINAL_COLOR;

	}else{
		vec3 Background = vec3(0.0);


		#ifdef OVERWORLD_SHADER

			float atmosphereGround = 1.0 - exp2(-50.0 * pow(clamp(feetPlayerPos_normalized.y+0.025,0.0,1.0),2.0)  ); // darken the ground in the sky.
			
			#if RESOURCEPACK_SKY == 1 || RESOURCEPACK_SKY == 0 || RESOURCEPACK_SKY == 3
				// vec3 orbitstar = vec3(feetPlayerPos_normalized.x,abs(feetPlayerPos_normalized.y),feetPlayerPos_normalized.z); orbitstar.x -= WsunVec.x*0.2;
				vec3 orbitstar = normalize(mat3(gbufferModelViewInverse) * toScreenSpace(vec3(texcoord/RENDER_SCALE,1.0)));
				// float radiance = 2.39996 - (worldTime + worldDay*24000.0) / 24000.0;
				// float radiance = 2.39996 ;
				float radiance = 2.39996 + frameTimeCounter/2000.0;
				mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));
				
				orbitstar.xy *= rotationMatrix;
				
  				#if defined OVERWORLD_SHADER && defined TWILIGHT_FOREST_FLAG
					Background += stars(orbitstar) * 100.0;
  				#else
					Background += stars(orbitstar) * 10.0 * clamp(-unsigned_WsunVec.y*2.0,0.0,1.0);
				#endif

				#if !defined ambientLight_only && (RESOURCEPACK_SKY == 1 || RESOURCEPACK_SKY == 0)
					Background += drawSun(dot(unsigned_WsunVec, feetPlayerPos_normalized), 0, lightCol.rgb / 2400.0,vec3(0.0));
					Background += drawMoon(feetPlayerPos_normalized, WmoonVec, moonCol / 2400.0, Background); 
				#endif

				Background *= atmosphereGround;
			#endif
			
			#ifndef ISOLATE_RESOURCEPACK_SKY
				vec3 Sky = skyFromTex(feetPlayerPos_normalized, colortex4)/1200.0 * Sky_Brightness;

				Background += Sky;
			#endif
			
			#if RESOURCEPACK_SKY == 1 || RESOURCEPACK_SKY == 2 || RESOURCEPACK_SKY == 3
				vec3 resourcePackskyBox = skyboxCol * 50.0 * clamp(unsigned_WsunVec.y*255.0,0.1,1.0);

				#if defined SKY_GROUND && !defined ISOLATE_RESOURCEPACK_SKY
					resourcePackskyBox *= atmosphereGround;
				#endif

				Background += resourcePackskyBox;
			#endif

		#endif
		gl_FragData[0].rgb = clamp(fp10Dither(Background, triangularize(noise_2)), 0.0, 65000.);
	}

	if(translucentMasks > 0.0){
		// water absorbtion will impact ALL light coming up from terrain underwater.
		gl_FragData[0].rgb *= Absorbtion;
	}

	////// dEBUG VIEW STUFF
	#if DEBUG_VIEW == debug_SHADOWMAP	
		gl_FragData[0].rgb = vec3(1.0) * shadowColor;
		
		if(dot(feetPlayerPos_normalized, unsigned_WsunVec) > 0.999 ) gl_FragData[0].rgb = vec3(10,10,0);
		if(dot(feetPlayerPos_normalized, -WmoonVec) > 0.999 ) gl_FragData[0].rgb = vec3(1,1,10);
	#endif
	#if DEBUG_VIEW == debug_ALBEDO
		gl_FragData[0].rgb = albedo;
	#endif
	#if DEBUG_VIEW == debug_NORMALS
		if(swappedDepth >= 1.0) Direct_lighting = vec3(1.0);
		gl_FragData[0].rgb = (hideGUI == 1 ? normal : -normal);// * vec3(0,1,0);
	#endif
	#if DEBUG_VIEW == debug_SPECULAR
		if(swappedDepth >= 1.0) Direct_lighting = vec3(1.0);
		gl_FragData[0].rgb = SpecularTex.rgb;
	#endif
	#if DEBUG_VIEW == debug_INDIRECT
		if(swappedDepth >= 1.0) Direct_lighting = vec3(5.0);
		gl_FragData[0].rgb = Indirect_lighting;
	#endif
	#if DEBUG_VIEW == debug_DIRECT
		if(swappedDepth < 1.0) gl_FragData[0].rgb = Direct_lighting;
	#endif
	#if DEBUG_VIEW == debug_VIEW_POSITION
		gl_FragData[0].rgb = viewPos * 0.001;
	#endif
	#if DEBUG_VIEW == debug_FILTERED_STUFF
		// if(hideGUI == 0){
			float value = SSAO_SSS.y;
			value = pow(value,3.5);
			value = 1-pow(1-value,5);

			if(hideGUI == 1) value = pow(SSAO_SSS.x,6);

			// value = filteredShadow.x;
			// value = exp(-10*sqrt(filteredShadow.y));
			// value = 1.0-filteredShadow.z;
			gl_FragData[0].rgb = vec3(value);

			if(swappedDepth >= 1.0) gl_FragData[0].rgb  = vec3(1.0);
		// }
	#endif


	// vec3 heightUV = (playerPos + (cameraPosition - vec3(9727.5,0.0,511.5))) / 2048.0;
	// gl_FragData[0].rgb = vec3(1.0) * texture(ArdaCraftHeightMap, heightUV.xz).r;
	
	// if(heldItemId > 0 ) 
	// gl_FragData[0].rgb = vec3(indirectSSS_phase(feetPlayerPos_normalized.y*0.5+0.5));

    // vec3 raycastPos = playerPos+playerLookVector*toScreenSpace(vec3(0.5,0.5,centerDepthSmooth)).z;
	
	// vec3 raycastPos = viewPos - vec3(0.0,0.0,ld(centerDepthSmooth));

	// vec3 bouncedIndirect = vec3(1)* clamp(1.0-length(raycastPos)/3.0,0,1);
    // // bouncedIndirect *= clamp(dot(-raycastPos, normal),0,1);

	// gl_FragData[0].rgb = bouncedIndirect;
	// gl_FragData[0].rgb = DEBUG/255.0;
	
	/* RENDERTARGETS:3 */
}