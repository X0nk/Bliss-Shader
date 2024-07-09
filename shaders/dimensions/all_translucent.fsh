#include "/lib/settings.glsl"

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

const bool colortex4MipmapEnabled = true;
uniform sampler2D noisetex;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;

#ifdef DISTANT_HORIZONS
	uniform sampler2D dhDepthTex1;
#endif
uniform sampler2D colortex7;
uniform sampler2D colortex12;
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


flat varying float exposure;


uniform vec3 sunVec;
uniform float near;
// uniform float far;
uniform float sunElevation;

uniform int isEyeInWater;
uniform float rainStrength;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform ivec2 eyeBrightnessSmooth;

uniform int frameCounter;
uniform float frameTimeCounter;
uniform vec2 texelSize;
uniform int framemod8;

uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;


uniform float moonIntensity;
uniform float sunIntensity;
uniform vec3 sunColor;
uniform vec3 nsunColor;

#include "/lib/util.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/projections.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/waterBump.glsl"


#ifdef OVERWORLD_SHADER
	flat varying float Flashing;
	#include "/lib/lightning_stuff.glsl"
	
	#define CLOUDSHADOWSONLY
	#include "/lib/volumetricClouds.glsl"
#else
	uniform float nightVision;
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

#include "/lib/diffuse_lighting.glsl"

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord)%512 , 0) ;
}
float interleaved_gradientNoise_temporal(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+frameTimeCounter*51.9521);
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
float R2_dither(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}

#include "/lib/TAA_jitter.glsl"








#define PW_DEPTH 1.5 //[0.5 1.0 1.5 2.0 2.5 3.0]
#define PW_POINTS 2 //[2 4 6 8 16 32]

varying vec3 viewVector;
vec3 getParallaxDisplacement(vec3 posxz) {

	vec3 parallaxPos = posxz;
	vec2 vec = viewVector.xy * (1.0 / float(PW_POINTS)) * 22.0 * PW_DEPTH;
	// float waterHeight = (1.0 - (getWaterHeightmap(posxz.xz)*0.5+0.5)) * 2.0 - 1.0;
	float waterHeight = getWaterHeightmap(posxz.xz) * 2.0;
	parallaxPos.xz -= waterHeight * vec;

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


float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

vec3 rayTrace(vec3 dir, vec3 position,float dither, float fresnel, bool inwater, inout float reflectLength){

    float quality = mix(15,SSR_STEPS,fresnel);
	
    // quality = SSR_STEPS;

    vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
       (-near -position.z) / dir.z : far*sqrt(3.);
    vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
    direction.xy = normalize(direction.xy);

    //get at which length the ray intersects with the edge of the screen
    vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
    float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);


    vec3 stepv = direction * mult / quality * vec3(RENDER_SCALE,1.0);


	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) + stepv*dither;
	float minZ = clipPosition.z;
	float maxZ = spos.z+stepv.z*0.5;
	
	spos.xy += offsets[framemod8]*texelSize*0.5/RENDER_SCALE;

	float dist = 1.0 + clamp(position.z*position.z/50.0,0,2); // shrink sample size as distance increases
    for (int i = 0; i <= int(quality); i++) {

		// decode depth buffer
		// float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/texelSize/4),0).w/65000.0);

		float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/texelSize/4.0),0).a/65000.0);
		sp = invLinZ(sp);

        if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ)) return vec3(spos.xy/RENDER_SCALE,sp);




        spos += stepv;
		//small bias
		if(inwater) {
			minZ = maxZ-0.00035/ld(spos.z);
		}else{
			minZ = maxZ-0.0001/max(ld(spos.z), (0.0 + position.z*position.z*0.001));
		}
		maxZ += stepv.z;

		
		reflectLength += 1.0 / quality; // for shit
    }

    return vec3(1.1);
}

float GGX(vec3 n, vec3 v, vec3 l, float r, float f0) {
  r = max(pow(r,2.5), 0.0001);

  vec3 h = l + v;
  float hn = inversesqrt(dot(h, h));

  float dotLH = clamp(dot(h,l)*hn,0.,1.);
  float dotNH = clamp(dot(h,n)*hn,0.,1.) ;
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNHsq = dotNH*dotNH;

  float denom = dotNHsq * r - dotNHsq + 1.;
  float D = r / (3.141592653589793 * denom * denom);

  float F = f0 + (1. - f0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
  float k2 = .25 * r;

  return dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
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
	float Emission,
	float exposure
){
	float autoBrightnessAdjust = mix(5.0, 100.0, clamp(exp(-10.0*exposure),0.0,1.0));
	if( Emission < 254.5/255.0) Lighting = mix(Lighting, Albedo * Emissive_Brightness * autoBrightnessAdjust * 0.1, pow(Emission, Emissive_Curve)); // old method.... idk why
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

	#ifdef HAND
		convertHandDepth(FragCoord.z);
	#endif

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
	// 0.1 = hand mask

	#ifdef HAND
		MATERIALS = 0.1;
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
	NormalTex.z = clamp(sqrt(1.0 - dot(NormalTex.xy, NormalTex.xy)),0.0,1.0) ;
	
	// tangent space normals for refraction
	TangentNormal = NormalTex.xy*0.5+0.5;
	
	#ifndef HAND
		if (isWater){
			vec3 posxz = (mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz) + cameraPosition;
			
			// make the waves flow in the direction the water faces, except for perfectly up facing parts.
			if(abs(worldSpaceNormal.y) < 0.9995) posxz.xz -= (posxz.y + frameTimeCounter*3 * WATER_WAVE_SPEED) * normalize(worldSpaceNormal.xz) ;
		
			posxz.xyz = getParallaxDisplacement(posxz);
			vec3 bump = normalize(getWaveNormal(posxz, false));

			float bumpmult = 10.0 * WATER_WAVE_STRENGTH;
			bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

			NormalTex.xyz = bump;

			// tangent space normals for refraction
			TangentNormal = (bump.xy/3.0)*0.5+0.5; 
		}
	#endif

	normal = applyBump(tbnMatrix, NormalTex.xyz, 1.0);

	gl_FragData[2] = vec4(encodeVec2(TangentNormal), encodeVec2(GLASS_TINT_COLORS.rg), encodeVec2(GLASS_TINT_COLORS.ba), 1.0);

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
		lightmap.x = max(lightmap.x, HELD_ITEM_BRIGHTNESS*clamp( pow(max(1.0-length((feetPlayerPos+cameraPosition) - playerCamPos)/HANDHELD_LIGHT_RANGE,0.0),1.5),0.0,1.0));
	#endif

	vec3 Indirect_lighting = vec3(0.0);
	vec3 MinimumLightColor = vec3(1.0);
	if(isEyeInWater == 1) MinimumLightColor = vec3(10.0);

	vec3 Direct_lighting = vec3(0.0);

	#ifdef OVERWORLD_SHADER
		vec3 DirectLightColor = lightCol.rgb/80.0;
		float NdotL = clamp(dot(normal, normalize(WsunVec*mat3(gbufferModelViewInverse))),0.0,1.0); NdotL = clamp((-15 + NdotL*255.0) / 240.0  ,0.0,1.0);
		float Shadows = 1.0;

		float shadowMapFalloff = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / (shadowDistance+16),0.0)*5.0,1.0));
		float shadowMapFalloff2 = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / shadowDistance,0.0)*5.0,1.0));

		float LM_shadowMapFallback = min(max(lightmap.y-0.8, 0.0) * 25,1.0);

		vec3 shadowPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;

		Shadows = ComputeShadowMap(DirectLightColor, shadowPlayerPos, shadowMapFalloff, blueNoise());

		Shadows = mix(LM_shadowMapFallback, Shadows, shadowMapFalloff2);

		Shadows *= pow(GetCloudShadow(feetPlayerPos),3);

		Direct_lighting = DirectLightColor * NdotL * Shadows;

		vec3 AmbientLightColor = averageSkyCol_Clouds/30.0;

		vec3 ambientcoefs = worldSpaceNormal / dot(abs(worldSpaceNormal), vec3(1.0));
		float SkylightDir = ambientcoefs.y*1.5;
		
		float skylight = max(pow(viewToWorld(flatnormal).y*0.5+0.5,0.1) + SkylightDir, 0.2);
		AmbientLightColor *= skylight;
		
		Indirect_lighting = doIndirectLighting(AmbientLightColor, MinimumLightColor, lightmap.y);
	#endif

	#ifdef NETHER_SHADER
		Indirect_lighting = skyCloudsFromTexLOD2(worldSpaceNormal, colortex4, 6).rgb / 30.0 ;
	#endif

	#ifdef END_SHADER
		float vortexBounds = clamp(vortexBoundRange - length(feetPlayerPos+cameraPosition), 0.0,1.0);
        vec3 lightPos = LightSourcePosition(feetPlayerPos+cameraPosition, cameraPosition,vortexBounds);


		float lightningflash = texelFetch2D(colortex4,ivec2(1,1),0).x/150.0;
		vec3 lightColors = LightSourceColors(vortexBounds, lightningflash);

		float NdotL = clamp(dot(worldSpaceNormal, normalize(-lightPos))*0.5+0.5,0.0,1.0);
		
		NdotL *= NdotL;

		Direct_lighting = lightColors * endFogPhase(lightPos) * NdotL;

		vec3 AmbientLightColor = vec3(0.3,0.6,1.0) * 0.5;
			
		Indirect_lighting = AmbientLightColor + 0.7 * AmbientLightColor * dot(worldSpaceNormal, normalize(feetPlayerPos));
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

	Indirect_lighting += doBlockLightLighting( vec3(TORCH_R,TORCH_G,TORCH_B), lightmap.x, exposure, feetPlayerPos, lpvPos);
	
	vec3 FinalColor = (Indirect_lighting + Direct_lighting) * Albedo;

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// SPECULAR LIGHTING /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

	#ifdef DAMAGE_BLOCK_EFFECT
		#undef WATER_REFLECTIONS
	#endif

	#ifndef OVERWORLD_SHADER
		#undef WATER_SUN_SPECULAR
	#endif

	#ifdef WATER_REFLECTIONS
		// vec2 SpecularTex = texture2D(specular, lmtexcoord.xy, Texture_MipMap_Bias).rg;
		
		// if nothing is chosen, no smoothness and no reflectance
		vec2 specularValues = vec2(1.0, 0.0); 

		// hardcode specular values for select blocks like glass, water, and slime
		if(isReflective) specularValues = vec2(1.0, 0.02);

		// detect if the specular texture is used, if it is, overwrite hardcoded values
		if(SpecularTex.r > 0.0 && SpecularTex.g <= 1.0) specularValues = SpecularTex.rg;
		
		float roughness = pow(1.0-specularValues.r,2.0);
		float f0 = isReflective ? max(specularValues.g, 0.02) : specularValues.g;

		#ifdef HAND
			f0 = max(specularValues.g, 0.02);
		#endif
		
		// f0 = SpecularTex.g;
		// roughness = pow(1.0-specularValues.r,2.0);
		// f0 = 0.9; 
		// roughness = 0.0;
		
		vec3 Metals = f0 > 229.5/255.0 ? normalize(Albedo+1e-7) * (dot(Albedo,vec3(0.21, 0.72, 0.07)) * 0.7 + 0.3) : vec3(1.0);
		
		// make sure zero alpha is not forced to be full alpha by fresnel on items with funny normal padding	
		if(UnchangedAlpha <= 0.0 && !isReflective) f0 = 0.0;
		
		if (f0 > 0.0){

			if(isReflective) f0 = max(f0, 0.02);

			vec3 Reflections_Final = vec3(0.0);
			vec4 Reflections = vec4(0.0);
			vec3 BackgroundReflection = FinalColor; 
			vec3 SunReflection = vec3(0.0);
			float indoors = pow(1.0-pow(1.0-min(max(lightmap.y-0.6,0.0)*3.0,1.0),0.5),2.0);

			vec3 reflectedVector = reflect(normalize(viewPos), normal);
			float normalDotEye = dot(normal, normalize(viewPos));

			float fresnel =  pow(clamp(1.0 + normalDotEye, 0.0, 1.0),5.0);

			/*
				int seed = (frameCounter%40000) + frameCounter*2;
				float noise = fract(R2_samples(seed).y + (1-blueNoise()));
				mat3 Basis = CoordBase(viewToWorld(normal));
				vec3 ViewDir = -normalize(feetPlayerPos)*Basis;
				vec3 SamplePoints = SampleVNDFGGX(ViewDir, vec2(roughness), noise);
				vec3 Ln = reflect(-ViewDir, SamplePoints);
				vec3 L = Basis * Ln;
				fresnel = pow(clamp(1.0 + dot(-Ln, SamplePoints),0.0,1.0), 5.0);
			*/

			#ifdef SNELLS_WINDOW
				// snells window looking thing
				if(isEyeInWater == 1) fresnel = pow(clamp(1.5 + normalDotEye,0.0,1.0), 25.0);
			#endif

			fresnel = mix(f0, 1.0, fresnel); 

			// Sun, Sky, and screen-space reflections
			#ifdef OVERWORLD_SHADER
				#ifdef WATER_SUN_SPECULAR
					SunReflection = Direct_lighting * GGX(normal, -normalize(viewPos), WsunVec*mat3(gbufferModelViewInverse), max(roughness,0.035), f0) * Metals; 
				#endif
				#ifdef WATER_BACKGROUND_SPECULAR
 					if(isEyeInWater == 0 && !isReflectiveEntity) BackgroundReflection = skyCloudsFromTex(mat3(gbufferModelViewInverse) * reflectedVector, colortex4).rgb / 30.0 * Metals;
				#endif

				if(isEyeInWater == 1 && isWater) BackgroundReflection.rgb = exp(-8.0 * vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B)) * clamp(WsunVec.y*lightCol.a,0,1);
			#else
				#ifdef WATER_BACKGROUND_SPECULAR 
 					if(isEyeInWater == 0) BackgroundReflection = skyCloudsFromTexLOD2(mat3(gbufferModelViewInverse) * reflectedVector, colortex4, 0).rgb / 30.0 * Metals;
				#endif
			#endif

			#ifdef SCREENSPACE_REFLECTIONS
				float reflectLength = 0.0;
				vec3 rtPos = rayTrace(reflectedVector, viewPos.xyz, interleaved_gradientNoise_temporal(), fresnel, isEyeInWater == 1,reflectLength);
				if (rtPos.z < 1.0){
					vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rtPos) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
					previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
					previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
					if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
						Reflections.a = 1.0; 
						Reflections.rgb = texture2D(colortex5, previousPosition.xy).rgb * Metals;
					}
				}
			#endif

			float visibilityFactor = clamp(exp2((pow(roughness,3.0) / f0) * -4),0,1);

			Reflections_Final = mix(mix(FinalColor, BackgroundReflection, indoors), Reflections.rgb, Reflections.a) * fresnel * visibilityFactor;
			Reflections_Final += SunReflection;

			//correct alpha channel with fresnel
			float alpha0 = gl_FragData[0].a;

			gl_FragData[0].a = -gl_FragData[0].a * fresnel + gl_FragData[0].a + fresnel;

			// prevent reflections from being darkened by buffer blending
			gl_FragData[0].rgb = clamp(FinalColor / gl_FragData[0].a*alpha0*(1.0-fresnel) * 0.1		+	Reflections_Final / gl_FragData[0].a * 0.1,0.0,65100.0);

			if (gl_FragData[0].r > 65000.) gl_FragData[0].rgba = vec4(0.0);

		} else {
			gl_FragData[0].rgb = FinalColor*0.1;
		}
	
	#else
		gl_FragData[0].rgb = FinalColor*0.1;
	#endif

	#if EMISSIVE_TYPE == 2 || EMISSIVE_TYPE == 3
		Emission(gl_FragData[0].rgb, Albedo, SpecularTex.b, exposure);
	#endif
	
	#if defined DISTANT_HORIZONS && defined DH_OVERDRAW_PREVENTION && !defined HAND
		bool WATER = texture2D(colortex7, gl_FragCoord.xy*texelSize).a > 0.0 && length(feetPlayerPos) > far-16*4 && texture2D(depthtex1, gl_FragCoord.xy*texelSize).x >= 1.0;

		if(WATER) gl_FragData[0].a = 0.0;
	#endif

	#ifndef HAND
		gl_FragData[1] = vec4(Albedo, MATERIALS);
	#endif
	#if DEBUG_VIEW == debug_DH_WATER_BLENDING
		if(gl_FragCoord.x*texelSize.x < 0.47) gl_FragData[0] = vec4(0.0);
	#endif
	#if DEBUG_VIEW == debug_NORMALS
		gl_FragData[0].rgb = normalize(normal.xyz) * 0.1;
	#endif
	#if DEBUG_VIEW == debug_INDIRECT
		gl_FragData[0].rgb = Indirect_lighting* 0.1;
	#endif
	#if DEBUG_VIEW == debug_DIRECT
		gl_FragData[0].rgb = Direct_lighting * 0.1;
	#endif

	gl_FragData[3].a = clamp(lightmap.y,0.0,1.0);

}
}