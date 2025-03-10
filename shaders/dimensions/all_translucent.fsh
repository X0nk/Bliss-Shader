#include "/lib/settings.glsl"

#undef FLASHLIGHT_BOUNCED_INDIRECT

// #if defined END_SHADER || defined NETHER_SHADER
// 	#undef IS_LPV_ENABLED
// #endif

#ifdef IS_LPV_ENABLED
	#extension GL_EXT_shader_image_load_store: enable
	#extension GL_ARB_shading_language_packing: enable
#endif

#include "/lib/res_params.glsl"

varying vec4 lmtexcoord;
varying vec4 color;
uniform vec4 entityColor;

#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;
	
	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif

	uniform float lightSign;
	flat varying vec3 WsunVec;

	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
#endif


flat varying float HELD_ITEM_BRIGHTNESS;
#if defined ENTITIES && defined IS_IRIS
	flat varying int NAMETAG;
#endif

uniform sampler2D noisetex;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;

#ifdef DISTANT_HORIZONS
	uniform sampler2D dhDepthTex1;
#endif

uniform sampler2D colortex7;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex14;
uniform sampler2D colortex5;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;

uniform sampler2D texture;
uniform sampler2D specular;
uniform sampler2D normals;

#ifdef IS_LPV_ENABLED
	uniform usampler1D texBlockData;
	uniform sampler3D texLpv1;
	uniform sampler3D texLpv2;
#endif

varying vec4 tangent;
varying vec4 normalMat;
varying vec3 binormal;
varying vec3 flatnormal;
#ifdef LARGE_WAVE_DISPLACEMENT
varying vec3 shitnormal;
#endif

uniform vec3 sunVec;
uniform float near;
// uniform float far;
uniform float sunElevation;

uniform int isEyeInWater;
uniform float rainStrength;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform ivec2 eyeBrightnessSmooth;
uniform float nightVision;

uniform int frameCounter;
uniform float frameTimeCounter;
uniform vec2 texelSize;
uniform int framemod8;
uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;

uniform float moonIntensity;
uniform float sunIntensity;
uniform vec3 sunColor;
uniform vec3 nsunColor;

uniform float waterEnteredAltitude;

#include "/lib/util.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/projections.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/waterBump.glsl"

#ifdef OVERWORLD_SHADER
	flat varying float Flashing;
	#include "/lib/lightning_stuff.glsl"

	#ifdef Daily_Weather
		flat varying vec4 dailyWeatherParams0;
		flat varying vec4 dailyWeatherParams1;
	#else
		vec4 dailyWeatherParams0 = vec4(CloudLayer0_coverage, CloudLayer1_coverage, CloudLayer2_coverage, 0.0);
		vec4 dailyWeatherParams1 = vec4(CloudLayer0_density, CloudLayer1_density, CloudLayer2_density, 0.0);
	#endif

	#define CLOUDSHADOWSONLY
	#include "/lib/volumetricClouds.glsl"

#endif

#ifdef END_SHADER
	#include "/lib/end_fog.glsl"
#endif

#ifdef IS_LPV_ENABLED
	uniform int heldItemId;
	uniform int heldItemId2;

	#include "/lib/hsv.glsl"
	#include "/lib/lpv_common.glsl"
	#include "/lib/lpv_render.glsl"
#endif

#define FORWARD_SPECULAR
#define FORWARD_ENVIORNMENT_REFLECTION
#define FORWARD_BACKGROUND_REFLECTION
#define FORWARD_ROUGH_REFLECTION


#ifdef FORWARD_SPECULAR
#endif
#ifdef FORWARD_ENVIORNMENT_REFLECTION
#endif
#ifdef FORWARD_BACKGROUND_REFLECTION
#endif
#ifdef FORWARD_ROUGH_REFLECTION
#endif

#include "/lib/specular.glsl"
#include "/lib/diffuse_lighting.glsl"

float interleaved_gradientNoise_temporal(){
	#ifdef TAA
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

	#ifdef TAA
		coord += + (frameCounter%40000) * 2.0;
	#endif
	
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}

float blueNoise(){
	#ifdef TAA
  		return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887);
	#endif
}

#include "/lib/TAA_jitter.glsl"

varying vec3 viewVector;
vec3 getParallaxDisplacement(vec3 waterPos, vec3 playerPos) {

	float largeWaves = texture2D(noisetex, waterPos.xy / 600.0 ).b;
	float largeWavesCurved = pow(1.0-pow(1.0-largeWaves,2.5),4.5);

	float waterHeight = getWaterHeightmap(waterPos.xy, largeWaves, largeWavesCurved);
	// waterHeight = exp(-20.0*sqrt(waterHeight));
	waterHeight = exp(-7.0*exp(-7.0*waterHeight)) * 0.25;
	
	vec3 parallaxPos = waterPos;

	parallaxPos.xy += (viewVector.xy / -viewVector.z) * waterHeight;

	return parallaxPos;
}

vec3 applyBump(mat3 tbnMatrix, vec3 bump, float puddle_values){
	float bumpmult = puddle_values;
	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
	// 
	return normalize(bump*tbnMatrix);
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
    float spiralShape = pow(variedSamples / (totalSamples + variance),0.5);

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
    pos = gbufferModelViewInverse * pos ;
    return pos.xyz;
}

vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}

vec4 encode (vec3 n, vec2 lightmaps){
	n.xy = n.xy / dot(abs(n), vec3(1.0));
	n.xy = n.z <= 0.0 ? (1.0 - abs(n.yx)) * sign(n.xy) : n.xy;
    vec2 encn = clamp(n.xy * 0.5 + 0.5,-1.0,1.0);
	
    return vec4(encn,vec2(lightmaps.x,lightmaps.y));
}

//encoding by jodie
float encodeVec2(vec2 a){
    const vec2 constant1 = vec2( 1., 256.) / 65535.;
    vec2 temp = floor( a * 255. );
	return temp.x*constant1.x+temp.y*constant1.y;
}

float encodeVec2(float x,float y){
    return encodeVec2(vec2(x,y));
}

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

uniform float dhFarPlane;

#include "/lib/DistantHorizons_projections.glsl"




// #undef BASIC_SHADOW_FILTER

#ifdef OVERWORLD_SHADER
float ComputeShadowMap(inout vec3 directLightColor, vec3 playerPos, float maxDistFade, float noise){

	if(maxDistFade <= 0.0) return 1.0;

	// setup shadow projection
	vec3 projectedShadowPosition = mat3(shadowModelView) * playerPos + shadowModelView[3].xyz;
	projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

	// un-distort
	#ifdef DISTORT_SHADOWMAP
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;
	#else
		float distortFactor = 1.0;
	#endif

	// hamburger
	projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);
	
	float shadowmap = 0.0;
	vec3 translucentTint = vec3(0.0);

	#ifndef HAND
		projectedShadowPosition.z -= 0.0001;
	#endif

	#if defined ENTITIES
		projectedShadowPosition.z -= 0.0002;
	#endif

	#ifdef BASIC_SHADOW_FILTER
		int samples = int(SHADOW_FILTER_SAMPLE_COUNT * 0.5);
		float rdMul = 14.0*distortFactor*d0*k/shadowMapResolution;

		for(int i = 0; i < samples; i++){
			vec2 offsetS = CleanSample(i, samples - 1, noise) * 0.3;
			projectedShadowPosition.xy += rdMul*offsetS;
	#else
		int samples = 1;
	#endif
	

		#ifdef TRANSLUCENT_COLORED_SHADOWS

			// determine when opaque shadows are overlapping translucent shadows by getting the difference of opaque depth and translucent depth
			float shadowDepthDiff = pow(clamp((shadow2D(shadowtex1, projectedShadowPosition).x - projectedShadowPosition.z) * 2.0,0.0,1.0),2.0);

			// get opaque shadow data to get opaque data from translucent shadows.
			float opaqueShadow = shadow2D(shadowtex0, projectedShadowPosition).x;
			shadowmap += max(opaqueShadow, shadowDepthDiff);

			// get translucent shadow data
			vec4 translucentShadow = texture2D(shadowcolor0, projectedShadowPosition.xy);

			// this curve simply looked the nicest. it has no other meaning.
			float shadowAlpha = pow(1.0 - pow(translucentShadow.a,5.0),0.2);

			// normalize the color to remove luminance, and keep the hue. remove all opaque color.
			// mulitply shadow alpha to shadow color, but only on surfaces facing the lightsource. this is a tradeoff to protect subsurface scattering's colored shadow tint from shadow bias on the back of the caster.
			translucentShadow.rgb = max(normalize(translucentShadow.rgb + 0.0001), max(opaqueShadow, 1.0-shadowAlpha)) * shadowAlpha;

			// make it such that full alpha areas that arent in a shadow have a value of 1.0 instead of 0.0
			translucentTint += mix(translucentShadow.rgb, vec3(1.0),  opaqueShadow*shadowDepthDiff);

		#else
			shadowmap += shadow2D(shadow, projectedShadowPosition).x;
		#endif

	#ifdef BASIC_SHADOW_FILTER
		}
	#endif

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		// tint the lightsource color with the translucent shadow color
		directLightColor *= mix(vec3(1.0), translucentTint.rgb / samples, maxDistFade);
	#endif

	return mix(1.0, shadowmap / samples, maxDistFade);
}
#endif

void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}

void Emission(
	inout vec3 Lighting,
	vec3 Albedo,
	float Emission
){
	if( Emission < 254.5/255.0) Lighting = mix(Lighting, Albedo * 5.0 * Emissive_Brightness, pow(Emission, Emissive_Curve));
}

uniform vec3 eyePosition;


//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

/* RENDERTARGETS:2,7,11,14 */


void main() {
if (gl_FragCoord.x * texelSize.x < 1.0  && gl_FragCoord.y * texelSize.y < 1.0 )	{
	
	vec3 FragCoord = gl_FragCoord.xyz;

	vec2 tempOffset = offsets[framemod8];

	vec3 viewPos = toScreenSpace(FragCoord*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5, 0.0));

	vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos;
////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// MATERIAL MASKS ////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
	
	float MATERIALS = normalMat.w;

	// 1.0 = water mask
	// 0.9 = entity mask
	// 0.8 = reflective entities
	// 0.7 = reflective blocks
	// 0.3 = hand mask

	#ifdef HAND
		MATERIALS = 0.3;
	#endif

	// bool isHand = abs(MATERIALS - 0.1) < 0.01;
	bool isWater = MATERIALS > 0.99;
	bool isReflectiveEntity = abs(MATERIALS - 0.8) < 0.01;
	bool isReflective = abs(MATERIALS - 0.7) < 0.01 || isWater || isReflectiveEntity;
	bool isEntity = abs(MATERIALS - 0.9) < 0.01 || isReflectiveEntity;

////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////// ALBEDO /////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

	gl_FragData[0] = texture2D(texture, lmtexcoord.xy, Texture_MipMap_Bias) * color;

	float UnchangedAlpha = gl_FragData[0].a;

	#ifdef WhiteWorld
		gl_FragData[0].rgb = vec3(0.5);
		gl_FragData[0].a = 1.0;
	#endif

	vec3 Albedo = toLinear(gl_FragData[0].rgb);

	#ifndef WhiteWorld
		#ifdef Vanilla_like_water
			if (isWater) Albedo *= sqrt(luma(Albedo));
		#else
			if (isWater){
				Albedo = vec3(0.0);
				gl_FragData[0].a = 1.0/255.0;
			}
		#endif
	#endif

	#ifdef ENTITIES
		Albedo.rgb = mix(Albedo.rgb, entityColor.rgb, clamp(entityColor.a*1.5,0,1));
	#endif

	vec4 GLASS_TINT_COLORS = vec4(Albedo, UnchangedAlpha);
	
	#ifdef BIOME_TINT_WATER
		if (isWater) GLASS_TINT_COLORS.rgb = toLinear(color.rgb);
	#endif

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// NORMALS ///////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

	vec3 normal = normalMat.xyz; // in viewSpace

	#ifdef LARGE_WAVE_DISPLACEMENT
		if (isWater){
			normal = viewToWorld(normal) ;
			normal.xz = shitnormal.xy;
			normal = worldToView(normal);
		}
	#endif
	
	vec3 worldSpaceNormal = viewToWorld(normal).xyz;
	vec2 TangentNormal = vec2(0); // for refractions
	
	vec3 tangent2 = normalize(cross(tangent.rgb,normal)*tangent.w);
	mat3 tbnMatrix = mat3(tangent.x, tangent2.x, normal.x,
						  tangent.y, tangent2.y, normal.y,
						  tangent.z, tangent2.z, normal.z);

	vec3 NormalTex = vec3(texture2D(normals, lmtexcoord.xy, Texture_MipMap_Bias).xy,0.0);
	NormalTex.xy = NormalTex.xy*2.0-1.0;
	NormalTex.z = clamp(sqrt(1.0 - dot(NormalTex.xy, NormalTex.xy)),0.0,1.0);

	#ifndef HAND
		if (isWater){
			vec3 playerPos = (mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz);
			vec3 waterPos = playerPos;

			vec3 flowDir = normalize(worldSpaceNormal*10.0) * frameTimeCounter * 2.0 * WATER_WAVE_SPEED;
			
			vec2 newPos = playerPos.xy + cameraPosition.xy + abs(flowDir.xz);
			newPos = mix(newPos, playerPos.zy + cameraPosition.zy + abs(flowDir.zx), clamp(abs(worldSpaceNormal.x),0.0,1.0));
			newPos = mix(newPos, playerPos.xz + cameraPosition.xz, clamp(abs(worldSpaceNormal.y),0.0,1.0));
			waterPos.xy = newPos;
		
			waterPos.xyz = getParallaxDisplacement(waterPos, playerPos);
			
			vec3 bump = normalize(getWaveNormal(waterPos, playerPos, false));

			float bumpmult = WATER_WAVE_STRENGTH;
			bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

			NormalTex.xyz = bump;
		}
	#endif

	// tangent space normals for refraction
	TangentNormal = NormalTex.xy;

	normal = applyBump(tbnMatrix, NormalTex.xyz, 1.0);

	// TangentNormal = clamp(TangentNormal + (blueNoise()*2.0-1.0)*0.005,-1.0,1.0);
	float nameTagMask = 0.0;

	#if defined ENTITIES && defined IS_IRIS
		if(NAMETAG > 0) nameTagMask = 0.1;
	#endif

	gl_FragData[2] = vec4(encodeVec2(TangentNormal*0.5+0.5), encodeVec2(GLASS_TINT_COLORS.rg), encodeVec2(GLASS_TINT_COLORS.ba), encodeVec2(0.0, nameTagMask));

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// SPECULARS /////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////


	vec3 SpecularTex = texture2D(specular, lmtexcoord.xy, Texture_MipMap_Bias).rga;
////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// DIFFUSE LIGHTING //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

	vec2 lightmap = lmtexcoord.zw;

	// lightmap.y = 1.0;
	
	#ifndef OVERWORLD_SHADER
		lightmap.y = 1.0;
	#endif
	
	#if defined Hand_Held_lights && !defined LPV_ENABLED
		#ifdef IS_IRIS
			vec3 playerCamPos = eyePosition;
		#else
			vec3 playerCamPos = cameraPosition;
		#endif
		
		if(HELD_ITEM_BRIGHTNESS > 0.0){ 
			float pointLight = clamp(1.0-length((feetPlayerPos+cameraPosition)-playerCamPos)/HANDHELD_LIGHT_RANGE,0.0,1.0);
			lightmap.x  = mix(lightmap.x , HELD_ITEM_BRIGHTNESS, pointLight*pointLight);
		}

	#endif

	vec3 Indirect_lighting = vec3(0.0);
	vec3 MinimumLightColor = vec3(1.0);
	if(isEyeInWater == 1) MinimumLightColor = vec3(10.0);

	vec3 Direct_lighting = vec3(0.0);

	#ifdef OVERWORLD_SHADER
		vec3 DirectLightColor = lightCol.rgb/2400.0;

		if(isEyeInWater == 1){
	  		float distanceFromWaterSurface = max(-(feetPlayerPos.y + (cameraPosition.y - waterEnteredAltitude)),0.0) ;
			DirectLightColor *= exp(-vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B) * distanceFromWaterSurface);
		}

		float NdotL = clamp(dot(normal, normalize(WsunVec*mat3(gbufferModelViewInverse))),0.0,1.0); NdotL = clamp((-15 + NdotL*255.0) / 240.0  ,0.0,1.0);
		float Shadows = 1.0;

		float shadowMapFalloff = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / (shadowDistance+16),0.0)*5.0,1.0));
		float shadowMapFalloff2 = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / shadowDistance,0.0)*5.0,1.0));

		float LM_shadowMapFallback = min(max(lightmap.y-0.8, 0.0) * 25,1.0);

		vec3 shadowPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;

		Shadows = ComputeShadowMap(DirectLightColor, shadowPlayerPos, shadowMapFalloff, blueNoise());

		Shadows = mix(LM_shadowMapFallback, Shadows, shadowMapFalloff2);

		#ifdef CLOUDS_SHADOWS
			Shadows *= GetCloudShadow(feetPlayerPos+cameraPosition, WsunVec);
		#endif

		Direct_lighting = DirectLightColor * NdotL * Shadows;

		vec3 AmbientLightColor = averageSkyCol_Clouds/900.0;

		vec3 indirectNormal = worldSpaceNormal / dot(abs(worldSpaceNormal),vec3(1.0));
		float SkylightDir = clamp(indirectNormal.y*0.7+0.3,0.0,1.0);

		float skylight = mix(0.2 + 2.3*(1.0-lightmap.y), 2.5, SkylightDir);
		AmbientLightColor *= skylight;

		Indirect_lighting = doIndirectLighting(AmbientLightColor, MinimumLightColor, lightmap.y);
	#endif

	#ifdef NETHER_SHADER
		Indirect_lighting = volumetricsFromTex(normalize(worldSpaceNormal), colortex4, 0).rgb / 1200.0 / 1.5;
	#endif

	#ifdef END_SHADER

		float vortexBounds = clamp(vortexBoundRange - length(feetPlayerPos+cameraPosition), 0.0,1.0);
        vec3 lightPos = LightSourcePosition(feetPlayerPos+cameraPosition, cameraPosition,vortexBounds);

		float lightningflash = texelFetch2D(colortex4,ivec2(1,1),0).x/150.0;
		vec3 lightColors = LightSourceColors(vortexBounds, lightningflash);
		
		float end_NdotL = clamp(dot(worldSpaceNormal, normalize(-lightPos))*0.5+0.5,0.0,1.0);
		end_NdotL *= end_NdotL;

		float fogShadow = GetEndFogShadow(feetPlayerPos+cameraPosition, lightPos);
		float endPhase = endFogPhase(lightPos);

		Direct_lighting += lightColors * endPhase * end_NdotL * fogShadow;

		vec3 AmbientLightColor = vec3(0.3,0.6,1.0) ;
			
		Indirect_lighting = AmbientLightColor + 0.7 * AmbientLightColor * dot(worldSpaceNormal, normalize(feetPlayerPos));
		Indirect_lighting *= 0.1;
	#endif

	///////////////////////// BLOCKLIGHT LIGHTING OR LPV LIGHTING OR FLOODFILL COLORED LIGHTING
	#ifdef IS_LPV_ENABLED
		vec3 normalOffset = vec3(0.0);

		if (any(greaterThan(abs(worldSpaceNormal), vec3(1.0e-6))))
			normalOffset = 0.5*worldSpaceNormal;

		#if LPV_NORMAL_STRENGTH > 0
			if (any(greaterThan(abs(normal), vec3(1.0e-6)))) {
				vec3 texNormalOffset = -normalOffset + viewToWorld(normal);
				normalOffset = mix(normalOffset, texNormalOffset, (LPV_NORMAL_STRENGTH*0.01));
			}
		#endif

		vec3 lpvPos = GetLpvPosition(feetPlayerPos) + normalOffset;
	#else
		const vec3 lpvPos = vec3(0.0);
	#endif

	Indirect_lighting += doBlockLightLighting( vec3(TORCH_R,TORCH_G,TORCH_B), lightmap.x, feetPlayerPos, lpvPos);
	
	vec4 flashLightSpecularData = vec4(0.0);
	#ifdef FLASHLIGHT
		Indirect_lighting += calculateFlashlight(FragCoord.xy*texelSize/RENDER_SCALE, viewPos, vec3(0.0), viewToWorld(normalize(normal)), flashLightSpecularData, false);
	#endif

	vec3 FinalColor = (Indirect_lighting + Direct_lighting) * Albedo;

	#if EMISSIVE_TYPE == 2 || EMISSIVE_TYPE == 3
		Emission(FinalColor, Albedo, SpecularTex.b);
	#endif

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// SPECULAR LIGHTING /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

	#ifdef DAMAGE_BLOCK_EFFECT
		#undef FORWARD_SPECULAR
	#endif

	#ifdef FORWARD_SPECULAR

		float harcodedF0 = 0.02;
		
		// if nothing is chosen, no smoothness and no reflectance
		vec2 specularValues = vec2(1.0, 0.0); 
		
		// hardcode specular values for select blocks like glass, water, and slime
		if(isReflective) specularValues = vec2(1.0, harcodedF0);

		// detect if the specular texture is used, if it is, overwrite hardcoded values
		if(SpecularTex.r > 0.0 && SpecularTex.g <= 1.0) specularValues = SpecularTex.rg;
		
		float f0 = isReflective ? max(specularValues.g, harcodedF0) : specularValues.g;
		bool isHand = false;


		#ifdef HAND
			isHand = true;
			f0 = max(specularValues.g, harcodedF0);
		#endif
		
		float roughness = specularValues.r; 

		if(UnchangedAlpha <= 0.0 && !isReflective) f0 = 0.0;

		if (f0 > 0.0){
			if(isReflective) f0 = max(f0, harcodedF0);
			
			float reflectance = 0.0;

			#if !defined OVERWORLD_SHADER
				vec3 WsunVec = vec3(0.0);
				vec3 DirectLightColor = WsunVec;
				float Shadows = 0.0;
			#endif
			
			
			vec3 specularReflections = specularReflections(viewPos, normalize(feetPlayerPos), WsunVec, vec3(blueNoise(), vec2(interleaved_gradientNoise_temporal())), viewToWorld(normal), roughness, f0, Albedo, FinalColor*gl_FragData[0].a, DirectLightColor * Shadows, lightmap.y, isHand, reflectance, flashLightSpecularData);
			
			gl_FragData[0].a = gl_FragData[0].a + (1.0-gl_FragData[0].a) * reflectance;
		
			// invert the alpha blending darkening on the color so you can interpolate between diffuse and specular and keep buffer blending
			gl_FragData[0].rgb = clamp(specularReflections / gl_FragData[0].a * 0.1,0.0,65000.0);
			
		}else{
			gl_FragData[0].rgb = clamp(FinalColor * 0.1,0.0,65000.0);
		}
	#else
		gl_FragData[0].rgb = FinalColor*0.1;
	#endif

	#if defined ENTITIES
		// do not allow specular to be very visible in these regions on entities
		// this helps with specular on slimes, and entities with skin overlays like piglins/players
    	if (!gl_FrontFacing) {
			gl_FragData[0] = vec4(FinalColor*0.1, UnchangedAlpha);
		}
	#endif
	
	#if defined DISTANT_HORIZONS && defined DH_OVERDRAW_PREVENTION && !defined HAND
		#if OVERDRAW_MAX_DISTANCE == 0
			float maxOverdrawDistance = far;
		#else
			float maxOverdrawDistance = OVERDRAW_MAX_DISTANCE;
		#endif

		bool WATER = texture2D(colortex7, gl_FragCoord.xy*texelSize).a > 0.0 && length(feetPlayerPos) > clamp(far-16*4, 16, maxOverdrawDistance) && texture2D(depthtex1, gl_FragCoord.xy*texelSize).x >= 1.0;

		if(WATER) gl_FragData[0].a = 0.0;
	#endif

	gl_FragData[1] = vec4(Albedo, MATERIALS);

	#if DEBUG_VIEW == debug_DH_WATER_BLENDING
		if(gl_FragCoord.x*texelSize.x < 0.47) gl_FragData[0] = vec4(0.0);
	#endif
	#if DEBUG_VIEW == debug_NORMALS
		gl_FragData[0].rgb = viewToWorld(normalize(normal.xyz)) * 0.1;
		gl_FragData[0].a = 1;
	#endif
	#if DEBUG_VIEW == debug_INDIRECT
		gl_FragData[0].rgb = Indirect_lighting * 0.1;
	#endif
	#if DEBUG_VIEW == debug_DIRECT
		gl_FragData[0].rgb = Direct_lighting * 0.1;
	#endif

	gl_FragData[3] = vec4(encodeVec2(lightmap.x, lightmap.y), 1, 1, 1);

	#if defined ENTITIES && defined IS_IRIS
		if(NAMETAG > 0) {
			//  WHY DO THEY HAVE TO AHVE LIGHTING AAAAAAUGHAUHGUAHG
			#ifndef OVERWORLD_SHADER
				lightmap.y = 0.0;
			#endif
			
			vec3 nameTagLighting = Albedo.rgb * max(max(lightmap.y*lightmap.y*lightmap.y , lightmap.x*lightmap.x*lightmap.x), 0.025);
			
			// in vanilla they have a special blending mode/no blending, or something. i cannot change the buffer blend mode without changing the rest of the entities :/
			gl_FragData[0] = vec4(nameTagLighting.rgb * 0.1, UnchangedAlpha  * 0.75);
		}
	#endif
}
}