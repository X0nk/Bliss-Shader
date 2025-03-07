#include "/lib/settings.glsl"
#include "/lib/util.glsl"

// #if defined END_SHADER || defined NETHER_SHADER
	// #undef IS_LPV_ENABLED
// #endifs

#ifdef IS_LPV_ENABLED
	#extension GL_ARB_shader_image_load_store: enable
	#extension GL_ARB_shading_language_packing: enable
#endif

#include "/lib/res_params.glsl"

const bool colortex5MipmapEnabled = true;

#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif

	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
	flat varying vec3 moonCol;

	#if Sun_specular_Strength != 0
		#define LIGHTSOURCE_REFLECTION
	#endif

	#include "/lib/lightning_stuff.glsl"
#endif

#ifdef NETHER_SHADER
	const bool colortex4MipmapEnabled = true;
	uniform vec3 lightningEffect;
	#undef LIGHTSOURCE_REFLECTION
#endif

#ifdef END_SHADER
	uniform vec3 lightningEffect;
	flat varying float Flashing;
	#undef LIGHTSOURCE_REFLECTION
#endif

uniform int hideGUI;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

#ifdef DISTANT_HORIZONS
	uniform sampler2D dhDepthTex;
	uniform sampler2D dhDepthTex1;
#endif

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
uniform sampler2D colortex15; // flat normals(rgb), vanillaAO(alpha)

#ifdef IS_LPV_ENABLED
	uniform usampler1D texBlockData;
	uniform sampler3D texLpv1;
	uniform sampler3D texLpv2;
#endif

uniform mat4 gbufferPreviousModelView;

// uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float updateFadeTime;
// uniform float centerDepthSmooth;

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
flat varying vec2 TAA_Offset;

uniform float frameTimeCounter;

uniform float rainStrength;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

uniform vec3 sunVec;
flat varying vec3 WsunVec;
flat varying vec3 unsigned_WsunVec;
flat varying vec3 WmoonVec;
flat varying float exposure;
flat varying vec3 albedoSmooth;

#ifdef IS_LPV_ENABLED
	uniform int heldItemId;
	uniform int heldItemId2;
#endif

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

#define TESTTHINGYG

#include "/lib/color_transforms.glsl"
#include "/lib/waterBump.glsl"

#include "/lib/Shadow_Params.glsl"
#include "/lib/Shadows.glsl"
#include "/lib/stars.glsl"
#include "/lib/climate_settings.glsl"
#include "/lib/sky_gradient.glsl"

#ifdef OVERWORLD_SHADER

	#ifdef Daily_Weather
		flat varying vec4 dailyWeatherParams0;
		flat varying vec4 dailyWeatherParams1;
	#else
		vec4 dailyWeatherParams0 = vec4(CloudLayer0_coverage, CloudLayer1_coverage, CloudLayer2_coverage, 0.0);
		vec4 dailyWeatherParams1 = vec4(CloudLayer0_density, CloudLayer1_density, CloudLayer2_density, 0.0);
	#endif

	#define CLOUDSHADOWSONLY
	#include "/lib/volumetricClouds.glsl"
	#define CLOUDS_INTERSECT_TERRAIN
#endif

#ifdef IS_LPV_ENABLED
	#include "/lib/hsv.glsl"
	#include "/lib/lpv_common.glsl"
	#include "/lib/lpv_render.glsl"
#endif

// #define DEFERRED_SPECULAR
#define DEFERRED_ENVIORNMENT_REFLECTION
#define DEFERRED_BACKGROUND_REFLECTION
#define DEFERRED_ROUGH_REFLECTION

#ifdef DEFERRED_SPECULAR
#endif
#ifdef DEFERRED_ENVIORNMENT_REFLECTION
#endif
#ifdef DEFERRED_BACKGROUND_REFLECTION
#endif
#ifdef DEFERRED_ROUGH_REFLECTION
#endif

#include "/lib/specular.glsl"
#include "/lib/diffuse_lighting.glsl"

#include "/lib/end_fog.glsl"
#include "/lib/DistantHorizons_projections.glsl"

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

float triangularize(float dither){
	float center = dither*2.0-1.0;
	dither = center*inversesqrt(abs(center));
	return clamp(dither-fsign(center),0.0,1.0);
}

vec3 fp10Dither(vec3 color,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}

vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord)%512 , 0) ;
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

vec2 SSRT_Shadows(vec3 viewPos, bool depthCheck, vec3 lightDir, float noise, bool isSSS, bool hand){

	float handSwitch = hand ? 1.0 : 0.0;

	float steps = 16.0;
	float Shadow = 1.0; 
	float SSS = 0.0;
	// isSSS = true;

	float _near = near; float _far = far*4.0;

	if (depthCheck) {
		_near = dhNearPlane;
		_far = dhFarPlane;
	}


	vec3 clipPosition = toClipSpace3_DH(viewPos, depthCheck);
	//prevents the ray from going behind the camera
	float rayLength = ((viewPos.z + lightDir.z * _far*sqrt(3.)) > -_near)
					? (-_near -viewPos.z) / lightDir.z
					: _far*sqrt(3.);

	vec3 direction = toClipSpace3_DH(viewPos + lightDir*rayLength, depthCheck) - clipPosition;  //convert to clip space

	direction.xyz = direction.xyz / max(abs(direction.x)/0.0005, abs(direction.y)/0.0005);	//fixed step size

	// float Stepmult = depthCheck ? (isSSS ? 1.0 : 3.0) : (isSSS ? 1.0 : 3.0);
	float Stepmult = isSSS ? 3.0 : 6.0;

	vec3 rayDir = direction * Stepmult * vec3(RENDER_SCALE,1.0);
	vec3 screenPos = clipPosition * vec3(RENDER_SCALE,1.0) + rayDir*noise - (isSSS ? rayDir*0.9 : vec3(0.0));

	float minZ = screenPos.z;
	float maxZ = screenPos.z;

	// as distance increases, add larger values to the SSS value. this scales the "density" with distance, as far things should appear denser.
	float dist = 1.0 + length(mat3(gbufferModelViewInverse) * viewPos) / 500.0;

	for (int i = 0; i < int(steps); i++) {
		
		float samplePos = convertHandDepth_2(texture2D(depthtex1, screenPos.xy).x, hand);
		
		#ifdef DISTANT_HORIZONS
			if(depthCheck) samplePos = texture2D(dhDepthTex1, screenPos.xy).x;
		#endif

		if(samplePos < screenPos.z && (samplePos <= max(minZ,maxZ) && samplePos >= min(minZ,maxZ))){
			vec2 linearZ = vec2(swapperlinZ(screenPos.z, _near, _far), swapperlinZ(samplePos, _near, _far));
			float calcthreshold = abs(linearZ.x - linearZ.y) / linearZ.x;

			if (calcthreshold < 0.035) Shadow = 0.0;
			SSS += dist;
		} 
		
		minZ = maxZ - (isSSS ? 1.0 : 0.0001) / swapperlinZ(samplePos, _near, _far);
		maxZ += rayDir.z;

		screenPos += rayDir;
	}
	return vec2(Shadow, SSS / steps);
}

float SSRT_FlashLight_Shadows(vec3 viewPos, bool depthCheck, vec3 lightDir, float noise){

	float steps = 16.0;
	float Shadow = 1.0; 
	float SSS = 0.0;
	// isSSS = true;

	float _near = near; float _far = far*4.0;

	if (depthCheck) {
		_near = dhNearPlane;
		_far = dhFarPlane;
	}

	vec3 clipPosition = toClipSpace3_DH(viewPos, depthCheck);
	//prevents the ray from going behind the camera
	float rayLength = ((viewPos.z + lightDir.z * _far*sqrt(3.)) > -_near)
					? (-_near -viewPos.z) / lightDir.z
					: _far*sqrt(3.);

	vec3 direction = toClipSpace3_DH(viewPos + lightDir*rayLength, depthCheck) - clipPosition; //convert to clip space

	direction.xyz = direction.xyz / max(abs(direction.x)/0.0005, abs(direction.y)/0.0005); //fixed step size

	float Stepmult = 6.0;

	vec3 rayDir = direction * Stepmult * vec3(RENDER_SCALE,1.0);
	vec3 screenPos = clipPosition * vec3(RENDER_SCALE,1.0) + rayDir*noise;


	for (int i = 0; i < int(steps); i++) {
		
		float samplePos = texture2D(depthtex2, screenPos.xy).x;
		
		#ifdef DISTANT_HORIZONS
			if(depthCheck) samplePos = texture2D(dhDepthTex1, screenPos.xy).x;
		#endif

		if(samplePos < screenPos.z){// && (samplePos <= max(minZ,maxZ) && samplePos >= min(minZ,maxZ))
			// vec2 linearZ = vec2(swapperlinZ(screenPos.z, _near, _far), swapperlinZ(samplePos, _near, _far));
			// float calcthreshold = abs(linearZ.x - linearZ.y) / linearZ.x;

			// if (calcthreshold < 0.035) 
			Shadow = 0.0;
		} 
		screenPos += rayDir;
	}
	return Shadow;
}

void Emission(
	inout vec3 Lighting,
	vec3 Albedo,
	float Emission,
	float exposure
){
	// float autoBrightnessAdjust = mix(5.0, 100.0, clamp(exp(-10.0*exposure),0.0,1.0));
	if( Emission < 254.5/255.0) Lighting = mix(Lighting, Albedo * 5.0 * Emissive_Brightness, pow(Emission, Emissive_Curve)); // old method.... idk why
	// if( Emission < 254.5/255.0 ) Lighting += (Albedo * Emissive_Brightness) * pow(Emission, Emissive_Curve);
}

#include "/lib/indirect_lighting_effects.glsl"
#include "/lib/PhotonGTAO.glsl"

void BilateralUpscale_REUSE_Z(sampler2D tex1, sampler2D tex2, sampler2D depth, vec2 coord, float referenceDepth, inout vec2 ambientEffects, inout vec3 filteredShadow, bool hand){
	ivec2 scaling = ivec2(1.0);
	ivec2 posDepth  = ivec2(coord) * scaling;
	ivec2 posColor  = ivec2(coord);
  	ivec2 pos = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 getRadius[4] = ivec2[](
		ivec2(-1,-1),
	 	ivec2( 1,-1),
		ivec2( 1, 1),
		ivec2(-1, 1)
  	);

	#ifdef DISTANT_HORIZONS
		float diffThreshold = 0.0005;
	#else
		float diffThreshold = 0.005;
	#endif

	vec3 shadow_RESULT = vec3(0.0);
	vec2 ssao_RESULT = vec2(0.0);
	float SUM = 1.0;

	#ifdef LIGHTING_EFFECTS_BLUR_FILTER
		for (int i = 0; i < 4; i++) {

			ivec2 radius = getRadius[i];

			#ifdef DISTANT_HORIZONS
				float offsetDepth = sqrt(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling,0).a/65000.0);
			#else
				float offsetDepth = ld(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling, 0).r);
			#endif

			float EDGES = abs(offsetDepth - referenceDepth) < diffThreshold ? 1.0 : 1e-5;

			#ifdef Variable_Penumbra_Shadows
				shadow_RESULT += texelFetch2D(tex1, posColor + radius + pos, 0).rgb * EDGES;
			#endif

			#if indirect_effect == 1
				ssao_RESULT += texelFetch2D(tex2, posColor + radius + pos, 0).rg * EDGES;
			#endif

			SUM += EDGES;
		}
	#endif

	#ifdef Variable_Penumbra_Shadows
		shadow_RESULT += texture2D(tex1, gl_FragCoord.xy*texelSize).rgb;
		filteredShadow = shadow_RESULT/SUM;
	#endif
	
	#if indirect_effect == 1
		ssao_RESULT += texture2D(tex2, gl_FragCoord.xy*texelSize).rg;
		ambientEffects = ssao_RESULT/SUM;
	#endif
}

vec4 BilateralUpscale_VLFOG(sampler2D tex, sampler2D depth, vec2 coord, float referenceDepth){
	ivec2 scaling = ivec2(1.0/VL_RENDER_RESOLUTION);
	ivec2 posDepth = ivec2(coord*VL_RENDER_RESOLUTION) * scaling;
	ivec2 posColor = ivec2(coord*VL_RENDER_RESOLUTION);
 	ivec2 pos = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 getRadius[5] = ivec2[](
    	ivec2(-1,-1),
	 	ivec2( 1, 1),
		ivec2(-1, 1),
		ivec2( 1,-1),
		ivec2( 0, 0)
	);

	float diffThreshold = zMults.x;
	#ifdef DISTANT_HORIZONS
		diffThreshold = 0.01;
	#endif

	vec4 RESULT = vec4(0.0);
	float SUM = 0.0;

	for (int i = 0; i < 4; i++) {
		
		ivec2 radius = getRadius[i];

		#ifdef DISTANT_HORIZONS
			float offsetDepth = sqrt(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling,0).a/65000.0);
		#else
			float offsetDepth = ld(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling, 0).r);
		#endif

		float EDGES = abs(offsetDepth - referenceDepth) < diffThreshold ? 1.0 : 1e-5;
		
		RESULT += texelFetch2D(tex, posColor + radius + pos, 0) * EDGES;
		
   		SUM += EDGES;
	}
	return RESULT / SUM;
}

#ifdef OVERWORLD_SHADER
	vec3 ComputeShadowMap_COLOR(in vec3 projectedShadowPosition, float distortFactor, float noise, float shadowBlockerDepth, float NdotL, float maxDistFade, vec3 directLightColor, inout float tShadow, inout vec3 tintedSunlight, bool isSSS, inout float shadowDebug) {
		float backface = NdotL <= 0.0 ? 1.0 : 0.0;
		vec3 shadowColor = vec3(0.0);
		vec3 translucentTint = vec3(0.0);
		float tShadowAccum = 0.0;

		int samples = 1;
		float rdMul = 0.0;

		#ifdef BASIC_SHADOW_FILTER
			samples = SHADOW_FILTER_SAMPLE_COUNT;
			rdMul = (shadowBlockerDepth * distortFactor * d0 * k / shadowMapResolution) * 0.3;
		#endif

		vec3 samplePos = projectedShadowPosition;
		for (int i = 0; i < samples; i++) {
			#ifdef BASIC_SHADOW_FILTER
				samplePos.xy += CleanSample(i, samples - 1, noise) * rdMul;
			#endif

			#ifdef TRANSLUCENT_COLORED_SHADOWS
				float opaqueShadow = shadow2D(shadowtex0, samplePos).x;
				float opaqueShadowT = shadow2D(shadowtex1, samplePos).x;
				vec4 translucentShadow = texture2D(shadowcolor0, samplePos.xy);

				float shadowAlpha = pow(translucentShadow.a * (2.0 - translucentShadow.a), 5.0);
				translucentShadow.rgb = normalize(translucentShadow.rgb * translucentShadow.rgb + 0.0001) * (1.0 - shadowAlpha);

				shadowColor += directLightColor * mix(translucentShadow.rgb * opaqueShadowT, vec3(1.0), opaqueShadow);
				translucentTint += mix(translucentShadow.rgb, vec3(1.0), max(opaqueShadow, backface * step(1.0, shadowAlpha)));
				tShadowAccum += (1.0 - shadowAlpha) * opaqueShadowT;
			#else
				shadowColor += directLightColor * shadow2D(shadow, samplePos).x;
			#endif
		}

		#ifdef debug_SHADOWMAP
			shadowDebug = shadow2D(shadow, projectedShadowPosition).x;
		#endif

		tShadow += tShadowAccum / samples;
		tintedSunlight *= translucentTint.rgb / samples;
		return mix(directLightColor, shadowColor.rgb / samples, maxDistFade);
	}
#endif

float CustomPhase(float LightPos){

	float PhaseCurve = 1.0 - LightPos;
	float Final = exp2(sqrt(PhaseCurve) * -25.0);
	Final += exp(PhaseCurve * -10.0)*0.5;

	return Final;
}

vec3 SubsurfaceScattering_sun(vec3 albedo, float Scattering, float Density, float lightPos, float shadows, float distantSSS){

	// Density = 1.0;
	Scattering *= sss_density_multiplier;

	float density = 1e-6 + Density * 2.0;
	float scatterDepth = max(1.0 - Scattering/density, 0.0);
	scatterDepth *= exp(-7.0 * (1.0-scatterDepth));

	vec3 absorbColor = exp(max(luma(albedo) - albedo*vec3(1.0,1.1,1.2), 0.0) * -20.0 * sss_absorbance_multiplier);
	vec3 scatter =  scatterDepth * mix(absorbColor, vec3(1.0), scatterDepth) * pow(Density, LabSSS_Curve);//* (1-min(max((1-Density)-0.9, 0.0)/(1.0-0.9),1.0));

	scatter *= 1.0 + CustomPhase(lightPos)*6.0; // ~10x brighter at the peak

	return scatter;	
}

vec3 SubsurfaceScattering_sky(vec3 albedo, float Scattering, float Density){
	// Density = 1.0;
	#ifdef OLD_INDIRECT_SSS
		float scatterDepth = 1.0 - pow(1.0-Scattering, 0.5 + Density * 2.5);
		vec3 absorbColor = vec3(1.0) * exp(-(15.0 - 10.0*scatterDepth)  * sss_absorbance_multiplier * 0.01);
		vec3 scatter =  scatterDepth *  absorbColor * pow(Density, LabSSS_Curve);
	#else
		float scatterDepth = pow(Scattering,3.5);
		scatterDepth = 1-pow(1-scatterDepth,5);

		vec3 absorbColor = exp(max(luma(albedo) - albedo*vec3(1.0,1.1,1.2), 0.0) * -20.0 * sss_absorbance_multiplier);
		vec3 scatter = scatterDepth * mix(absorbColor, vec3(1.0), scatterDepth) * pow(Density, LabSSS_Curve);
	#endif

	// scatter *= 1.0 + exp(-7.0*(-playerPosNormalized.y*0.5+0.5));

	return scatter;
}

uniform float wetnessAmount;
uniform float wetness;

void applyPuddles(
	in vec3 worldPos, in vec3 flatNormals, in float lightmap, in bool isWater, inout vec3 albedo, inout vec3 normals, inout float roughness, inout float f0
){
	vec3 unchangedNormals = normals;

	float halfWet = min(wetnessAmount,1.0);
	float fullWet = clamp(wetnessAmount - 2.0,0.0,1.0);

	float noise = texture2D(noisetex, worldPos.xz * 0.02).b;

	float lightmapMax = min(max(lightmap - 0.9,0.0) * 10.0,1.0) ;
	float lightmapMin = min(max(lightmap - 0.8,0.0) * 5.0,1.0) ;
	lightmap = clamp(lightmapMax + noise*lightmapMin*2.0,0.0,1.0);
	lightmap = pow(1.0-pow(1.0-lightmap,3.0),2.0);
	
	float puddles = max(halfWet - noise,0.0);
	puddles = clamp(halfWet - exp(-25.0 * puddles * puddles * puddles * puddles * puddles),0.0,1.0);
	
	float wetnessStages = mix(puddles, 1.0, fullWet) * lightmap;
	if(isWater) wetnessStages = 0.0;

	normals = mix(normals, flatNormals, puddles * lightmap * clamp(flatNormals.y,0.0,1.0));
	roughness = mix(roughness, 1.0, wetnessStages * roughness);

	if(f0 < 229.5/255.0 ) albedo = pow(albedo * (1.0 - 0.08*wetnessStages), vec3(1.0 + 0.7*wetnessStages));

	//////////////// snow
	
	// float upnormal = clamp(-(normals / dot(abs(normals),vec3(1.0))).y+clamp(flatNormals.y,0.5,1.0),0,1);
	// halfWet = clamp(halfWet - upnormal - (1.0-lightmap),0.0,1.0);
	// float snow = max(halfWet - noise,0.0);
	// snow = clamp(halfWet - exp(-20.0 * snow*snow*snow*snow*snow),0.0,1.0);
	
	// if(isWater || f0 > 229.5/255.0) snow = 0.0;

	// normals = mix(normals, unchangedNormals, snow);
	// roughness = mix(roughness, 0.5, snow);
	// albedo = mix(albedo, vec3(1.0), snow);
}

void main() {

		vec3 DEBUG = vec3(1.0);

	////// --------------- SETUP STUFF --------------- //////
		vec2 texcoord = gl_FragCoord.xy * texelSize;
	
		float noise_2 = R2_dither();
		vec2 bnoise = blueNoise(gl_FragCoord.xy).rg;

		int seed = 600;
		#ifdef TAA
			seed = (frameCounter*5)%40000;
		#endif

		vec2 r2_sequence = R2_samples(seed).xy;
		vec2 BN = fract(r2_sequence + bnoise);
		float noise = BN.y;

		// float z0 = texture2D(depthtex0,texcoord).x;
		// float z = texture2D(depthtex1,texcoord).x;
		
		float z0 = texelFetch2D(depthtex0, ivec2(gl_FragCoord.xy), 0).x;
		float z =  texelFetch2D(depthtex1, ivec2(gl_FragCoord.xy), 0).x;
		float swappedDepth = z;

		bool isDHrange = z >= 1.0;

		#ifdef DISTANT_HORIZONS
			float DH_mixedLinearZ = sqrt(texture2D(colortex12,texcoord).a/65000.0);
			float DH_depth0 = texture2D(dhDepthTex,texcoord).x;
			float DH_depth1 = texture2D(dhDepthTex1,texcoord).x;

			float depthOpaque = z;
			float depthOpaqueL = linearizeDepthFast(depthOpaque, near, farPlane);
			
			#ifdef DISTANT_HORIZONS
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
	
		vec4 data = texelFetch2D(colortex1, ivec2(gl_FragCoord.xy), 0);

		vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y)); // albedo, masks
		vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w)); // normals, lightmaps
		// vec4 dataUnpacked2 = vec4(decodeVec2(data.z),decodeVec2(data.w));

		vec3 albedo = toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));
		vec3 normal = decode(dataUnpacked0.yw);
		vec2 lightmap = dataUnpacked1.yz;

		lightmap.xy = min(max(lightmap.xy - 0.05,0.0)*1.06,1.0); // small offset to hide flickering from precision error in the encoding/decoding on values close to 1.0 or 0.0
		
		#if !defined OVERWORLD_SHADER
			lightmap.y = 1.0;
		#endif

	////// --------------- UNPACK MISC --------------- //////
	
		vec4 SpecularTex = texelFetch2D(colortex8, ivec2(gl_FragCoord.xy), 0);
		float LabSSS = clamp((-65.0 + SpecularTex.z * 255.0) / 190.0 ,0.0,1.0);	
		// LabSSS = 1;

		vec4 normalAndAO = texture2D(colortex15,texcoord);
		vec3 FlatNormals = normalize(normalAndAO.rgb * 2.0 - 1.0);
		vec3 slopednormal = normal;

		float vanilla_AO = z < 1.0 ? clamp(normalAndAO.a,0,1) : 0.0;
		normalAndAO.a = clamp(pow(normalAndAO.a*5,4),0,1);

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
		// 1.0 = water mask
		// 0.9 = entity mask
		// 0.8 = reflective entities
		// 0.7 = reflective blocks
  		float translucentMasks = texture2D(colortex7, texcoord).a;

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
		// bool blocklights = abs(opaqueMasks-0.8) <0.01;

		if(hand){
			convertHandDepth(z);
			convertHandDepth(z0);
		}

		#ifdef DISTANT_HORIZONS
			vec3 viewPos = toScreenSpace_DH(texcoord/RENDER_SCALE - TAA_Offset*texelSize*0.5, z, DH_depth1);
		#else
			vec3 viewPos = toScreenSpace(vec3(texcoord/RENDER_SCALE - TAA_Offset*texelSize*0.5, z));
		#endif
		
		vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos;
		vec3 feetPlayerPos_normalized = normalize(feetPlayerPos);

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

		vec3 shadowColor = vec3(1.0);
		vec3 SSSColor = vec3(1.0);
		vec3 filteredShadow = vec3(Min_Shadow_Filter_Radius,1.0,0.0);

		float NdotL = 1.0;
		float lightLeakFix = clamp(pow(eyeBrightnessSmooth.y/240. + lightmap.y,2.0) ,0.0,1.0);

		#ifdef OVERWORLD_SHADER
			DirectLightColor = lightCol.rgb / 2400.0;
			AmbientLightColor = averageSkyCol_Clouds / 900.0;
			shadowColor = DirectLightColor;

			// #ifdef PER_BIOME_ENVIRONMENT
			// 	// BiomeSunlightColor(DirectLightColor);
			// 	vec3 biomeDirect = DirectLightColor; 
			// 	vec3 biomeIndirect = AmbientLightColor;
			// 	float inBiome = BiomeVLFogColors(biomeDirect, biomeIndirect);

			// 	float maxDistance = inBiome * min(max(1.0 -  length(feetPlayerPos)/(32*8),0.0)*2.0,1.0);
			// 	DirectLightColor = mix(DirectLightColor, biomeDirect, maxDistance);
			// #endif

			bool inShadowmapBounds = false;
		#endif

		MinimumLightColor = MinimumLightColor + 0.7 * MinimumLightColor * dot(slopednormal, feetPlayerPos_normalized);

	////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////	UNDER WATER SHADING		////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////

 	if ((isEyeInWater == 0 && isWater) || (isEyeInWater == 1 && !isWater)){

		feetPlayerPos += gbufferModelViewInverse[3].xyz;

		#ifdef DISTANT_HORIZONS
			vec3 playerPos0 = mat3(gbufferModelViewInverse) *  toScreenSpace_DH(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5, z0, DH_depth0) + gbufferModelViewInverse[3].xyz;
		#else
			vec3 playerPos0 = mat3(gbufferModelViewInverse) * toScreenSpace(vec3(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5,z0)) + gbufferModelViewInverse[3].xyz;
		#endif

		float Vdiff = distance(feetPlayerPos, playerPos0);
		float estimatedDepth = Vdiff * abs(feetPlayerPos_normalized.y);// assuming water plane

		// force the absorbance to start way closer to the water surface in low light areas, so the water is visible in caves and such.
		#if MINIMUM_WATER_ABSORBANCE > -1
			float minimumAbsorbance = MINIMUM_WATER_ABSORBANCE*0.1;
		#else
			float minimumAbsorbance	= (1.0 - lightLeakFix);
		#endif
		Absorbtion = exp(-totEpsilon * max(Vdiff, minimumAbsorbance));


		// brighten up the fully absorbed parts of water when night vision activates.
		// if( nightVision > 0.0 ) Absorbtion += exp( -50.0 * totEpsilon) * 50.0 * 7.0 * nightVision;
		// if( nightVision > 0.0 ) Absorbtion += exp( -30.0 * totEpsilon) * 10.0 * nightVision * 10.0;

		// things to note about sunlight in water
		// sunlight gets absorbed by water on the way down to the floor, and on the way back up to your eye. im gonna ingore the latter part lol
		// based on the angle of the sun, sunlight will travel through more/less water to reach the same spot. scale absorbtion depth accordingly
		vec3 sunlightAbsorbtion = exp(-totEpsilon * (estimatedDepth/abs(WsunVec.y)));

		if (isEyeInWater == 1){
			estimatedDepth = 1.0;

			// viewerWaterDepth = max(0.9-lightmap.y,0.0)*3.0;
	  		float distanceFromWaterSurface = max(-(feetPlayerPos.y + (cameraPosition.y - waterEnteredAltitude)),0.0) ;

			Absorbtion = exp(-totEpsilon * distanceFromWaterSurface);
			
			sunlightAbsorbtion = exp(-totEpsilon * (distanceFromWaterSurface/abs(WsunVec.y)));
		}

		DirectLightColor *= sunlightAbsorbtion;

		if( nightVision > 0.0 ) Absorbtion += exp(-totEpsilon * 25.0) * nightVision;

		// apply caustics to the lighting, and make sure they dont look weird
		DirectLightColor *= mix(1.0, waterCaustics(feetPlayerPos + cameraPosition, WsunVec)*WATER_CAUSTICS_BRIGHTNESS, clamp(estimatedDepth,0,1));
	}

	if (swappedDepth < 1.0) {

		// idk why this do
		feetPlayerPos += gbufferModelViewInverse[3].xyz;
	////////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////	    FILTER STUFF      //////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////

		#if defined DISTANT_HORIZONS && defined DH_AMBIENT_OCCLUSION
			BilateralUpscale_REUSE_Z(colortex3,	colortex14, colortex12, gl_FragCoord.xy-1.5, DH_mixedLinearZ, SSAO_SSS, filteredShadow, hand);
		#else
			BilateralUpscale_REUSE_Z(colortex3,	colortex14, depthtex0, gl_FragCoord.xy-1.5, ld(z0), SSAO_SSS, filteredShadow, hand);
		#endif

		float ShadowBlockerDepth = filteredShadow.y;

	////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	MAJOR LIGHTSOURCE STUFF 	////////////////////////
	////////////////////////////////////////////////////////////////////////////////////

	#ifdef OVERWORLD_SHADER

		float LM_shadowMapFallback =  min(max(lightmap.y-0.8, 0.0) * 5.0,1.0);

		float LightningPhase = 0.0;
		vec3 LightningFlashLighting = Iris_Lightningflash(feetPlayerPos, lightningBoltPosition.xyz, slopednormal, LightningPhase) * pow(lightmap.y,10);

		NdotL = clamp((-15 + dot(slopednormal, WsunVec)*255.0) / 240.0  ,0.0,1.0);

		// NdotL = 1;
		float flatNormNdotL = clamp((-15 + dot((FlatNormals), WsunVec)*255.0) / 240.0  ,0.0,1.0);

	////////////////////////////////	SHADOWMAP		////////////////////////////////
		// setup shadow projection
		vec3 shadowPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
		if(!hand) GriAndEminShadowFix(shadowPlayerPos, FlatNormals, vanilla_AO, lightmap.y);

		vec3 projectedShadowPosition = mat3(shadowModelView) * shadowPlayerPos + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		#if OPTIMIZED_SHADOW_DISTANCE > 0

			float shadowMapFalloff = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / (shadowDistance+16.0),0.0)*5.0,1.0));
			float shadowMapFalloff2 = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / shadowDistance,0.0)*5.0,1.0));

		#else
			vec3 shadowEdgePos = projectedShadowPosition * vec3(0.4,0.4,0.5/6.0) + vec3(0.5,0.5,0.12);
      		float fadeLength = max((shadowDistance/256)*30,10.0); 

      		vec3 cubicRadius = clamp(   min((1.0-shadowEdgePos)*fadeLength, shadowEdgePos*fadeLength),0.0,1.0);
      		float shadowmapFade = cubicRadius.x*cubicRadius.y*cubicRadius.z;

        	shadowmapFade = 1.0 - pow(1.0-pow(shadowmapFade,1.5),3.0);

			float shadowMapFalloff = shadowmapFade;
			float shadowMapFalloff2 = shadowmapFade;
		#endif

		if(isEyeInWater == 1){
			shadowMapFalloff = 1.0;
			shadowMapFalloff2 = 1.0;
		}

		// un-distort
		#ifdef DISTORT_SHADOWMAP
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;
		#else
			float distortFactor = 1.0;
		#endif
		
		projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5) ;

		#ifdef LPV_SHADOWS
			projectedShadowPosition.xy *= 0.8;
		#endif

		float ShadowAlpha = 0.0; // this is for subsurface scattering later.
		vec3 tintedSunlight = DirectLightColor; // this is for subsurface scattering later.
		
		shadowColor = ComputeShadowMap_COLOR(projectedShadowPosition, distortFactor, noise_2, filteredShadow.x, flatNormNdotL, shadowMapFalloff, DirectLightColor, ShadowAlpha, tintedSunlight, LabSSS > 0.0,Shadows);
		
		// transition to fallback lightmap shadow mask.
		shadowColor *= mix(isWater ? lightLeakFix : LM_shadowMapFallback, 1.0, shadowMapFalloff2);

		// #ifdef OLD_LIGHTLEAK_FIX
		// 	if (isEyeInWater == 0) Shadows *= lightLeakFix; // light leak fix
		// #endif
		
	////////////////////////////////	SUN SSS		////////////////////////////////
	
		#if SSS_TYPE != 0

			float sunSSS_density = LabSSS;
			float SSS_shadow = ShadowAlpha;
			
			#ifdef DISTANT_HORIZONS
				shadowMapFalloff2 = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / min(shadowDistance, max(far-32.0,32.0)),0.0)*5.0,1.0));
			#endif

			#ifndef RENDER_ENTITY_SHADOWS
				if(entities) sunSSS_density = 0.0;
			#endif

			#ifdef SCREENSPACE_CONTACT_SHADOWS
				vec2 SS_directLight = SSRT_Shadows(toScreenSpace_DH(texcoord/RENDER_SCALE, z, DH_depth1), isDHrange, normalize(WsunVec*mat3(gbufferModelViewInverse)), interleaved_gradientNoise_temporal(), sunSSS_density > 0.0 && shadowMapFalloff2 < 1.0, hand);
				// Shadows = SS_directLight.r;

				// combine shadowmap with a minumum shadow determined by the screenspace shadows.
				shadowColor *= SS_directLight.r;
				// combine shadowmap blocker depth with a minumum determined by the screenspace shadows, starting after the shadowmap ends
				ShadowBlockerDepth = mix(SS_directLight.g, ShadowBlockerDepth, shadowMapFalloff2);

				// shadowColor = vec3(SS_directLight.r*0 + 1);
				// ShadowBlockerDepth = SS_directLight.g;
			#endif
			#ifdef TRANSLUCENT_COLORED_SHADOWS
				SSSColor = tintedSunlight;
			#else
				SSSColor = DirectLightColor;
			#endif
			
			SSSColor *= SubsurfaceScattering_sun(albedo, ShadowBlockerDepth, sunSSS_density, clamp(dot(feetPlayerPos_normalized, WsunVec),0.0,1.0), SSS_shadow, shadowMapFalloff2);
			
			if(isEyeInWater != 1) SSSColor *= lightLeakFix;

			#ifndef SCREENSPACE_CONTACT_SHADOWS
				SSSColor = mix(vec3(0.0), SSSColor, shadowMapFalloff2);
			#endif

			#ifdef CLOUDS_SHADOWS
				float cloudShadows = GetCloudShadow(feetPlayerPos.xyz + cameraPosition, WsunVec);
				shadowColor *= cloudShadows;
				SSSColor *= cloudShadow*cloudShadows;
			#endif
		#endif
	#endif

	#ifdef END_SHADER
		float vortexBounds = clamp(vortexBoundRange - length(feetPlayerPos+cameraPosition), 0.0,1.0);
		vec3 lightPos = LightSourcePosition(feetPlayerPos+cameraPosition, cameraPosition,vortexBounds);

		float lightningflash = texelFetch2D(colortex4,ivec2(1,1),0).x/150.0;
		vec3 lightColors = LightSourceColors(vortexBounds, lightningflash);

		float end_NdotL = clamp(dot(slopednormal, normalize(-lightPos))*0.5+0.5,0.0,1.0);
		end_NdotL *= end_NdotL;

		float fogShadow = GetEndFogShadow(feetPlayerPos+cameraPosition, lightPos);
		float endPhase = endFogPhase(lightPos);

		Direct_lighting += lightColors * endPhase * end_NdotL * fogShadow;
	#endif

	/////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	INDIRECT LIGHTING 	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////

		#if defined OVERWORLD_SHADER
			float skylight = 1.0;
		
			#if indirect_effect == 0 || indirect_effect == 1 || indirect_effect == 2

				vec3 indirectNormal = slopednormal / dot(abs(slopednormal),vec3(1.0));

				float SkylightDir = indirectNormal.y;
				if(isGrass) SkylightDir = 1.0;
				
				SkylightDir = clamp(SkylightDir*0.7+0.3, 0.0, pow(1-pow(1-SSAO_SSS.x, 0.5),4.0) * 0.7 + 0.3);

				skylight = mix(0.2 + 2.3*(1.0-lightmap.y), 2.5, SkylightDir);

			#elif indirect_effect == 3 || indirect_effect == 4
				skylight = 2.5;
			#endif
			
			Indirect_lighting += doIndirectLighting(AmbientLightColor * skylight, MinimumLightColor, lightmap.y);

		#endif

		#ifdef NETHER_SHADER
			Indirect_lighting = volumetricsFromTex(normalize(normal), colortex4, 6).rgb / 1200.0;
			vec3 up = volumetricsFromTex(vec3(0.0,1.0,0.0), colortex4, 6).rgb / 1200.0;
			
			#if indirect_effect == 1
				Indirect_lighting = mix(up, Indirect_lighting,  clamp(pow(1.0-pow(1.0-SSAO_SSS.x, 0.5),2.0),0.0,1.0));
			#endif
			
			AmbientLightColor = Indirect_lighting;
		#endif
		
		#ifdef END_SHADER
			Indirect_lighting = vec3(0.3,0.6,1.0);
			
			Indirect_lighting = Indirect_lighting + 0.7*mix(-Indirect_lighting, Indirect_lighting * dot(slopednormal, feetPlayerPos_normalized), clamp(pow(1.0-pow(1.0-SSAO_SSS.x, 0.5),2.0),0.0,1.0));
			Indirect_lighting *= 0.1;

			Indirect_lighting += lightColors * (endPhase*endPhase) * (1.0-exp(vec3(0.6,2.0,2.0) * -(endPhase*0.01))) /1000.0;
		#endif
		
		#ifdef IS_LPV_ENABLED
			vec3 normalOffset = vec3(0.0);

			if (any(greaterThan(abs(FlatNormals), vec3(1.0e-6))))
				normalOffset = 0.5*(FlatNormals);

			#if LPV_NORMAL_STRENGTH > 0
				vec3 texNormalOffset = -normalOffset + slopednormal;
				normalOffset = mix(normalOffset, texNormalOffset, (LPV_NORMAL_STRENGTH*0.01));
			#endif

			vec3 lpvPos = GetLpvPosition(feetPlayerPos) + normalOffset;
		#else
			const vec3 lpvPos = vec3(0.0);
		#endif
		vec3 blockLightColor = doBlockLightLighting(vec3(TORCH_R,TORCH_G,TORCH_B), lightmap.x, exposure, feetPlayerPos, lpvPos, viewToWorld(FlatNormals));
		Indirect_lighting += blockLightColor;

		vec4 flashLightSpecularData = vec4(0.0);
		vec3 ssrtFLASHLIGHT = vec3(0.0);
		#ifdef FLASHLIGHT
			vec3 newViewPos = viewPos;

			float flashlightshadows = SSRT_FlashLight_Shadows(toScreenSpace_DH(texcoord/RENDER_SCALE, z, DH_depth1), isDHrange, newViewPos, interleaved_gradientNoise_temporal());

			ssrtFLASHLIGHT = calculateFlashlight(texcoord, viewPos, albedoSmooth, slopednormal, flashLightSpecularData, hand);
			Indirect_lighting += ssrtFLASHLIGHT;
		#endif

	/////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	EFFECTS FOR INDIRECT	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////

		float SkySSS = 1.0;
		vec3 AO = vec3(1.0);

		#if indirect_effect == 0
			AO = vec3(pow(1.0 - vanilla_AO*vanilla_AO,5.0));
			Indirect_lighting *= AO;

		#elif indirect_effect == 1
			SkySSS = SSAO_SSS.y;
			float SSAO_curve = pow(SSAO_SSS.x,4.0);

			AO = vec3(SSAO_curve);
			Indirect_lighting *= AO;

		// GTAO... this is so dumb but whatevverrr
		#elif indirect_effect == 2
			float vanillaAO_curve = pow(1.0 - vanilla_AO*vanilla_AO,5.0);

			vec2 r2 = fract(R2_samples((frameCounter%40000) + frameCounter*2) + bnoise);
			float GTAO =  !hand ? ambient_occlusion(vec3(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5, z), viewPos, worldToView(slopednormal), r2) : 1.0;

			AO = vec3(min(vanillaAO_curve,GTAO));
			Indirect_lighting *= AO;

		// RTGI and/or SSGI
		#elif indirect_effect == 3 || indirect_effect == 4
			if(!hand) Indirect_lighting = ApplySSRT(Indirect_lighting, blockLightColor, MinimumLightColor, viewPos, normal, vec3(bnoise, noise_2), lightmap.y, isGrass, isDHrange) + ssrtFLASHLIGHT;
		#endif

	////////////////////////////////////////////////////////////////////////////////
	///////////////////////// SUB SURFACE SCATTERING	/////////////////////////
	////////////////////////////////////////////////////////////////////////////////
	
	/////////////////////////////	SKY SSS /////////////////////////////

		#if defined Ambient_SSS && defined OVERWORLD_SHADER && indirect_effect == 1
			if (!hand){
				vec3 ambientColor = AmbientLightColor * ambientsss_brightness * ambient_brightness * 3.0;

				Indirect_SSS = SubsurfaceScattering_sky(albedo, SkySSS, LabSSS);
				Indirect_SSS *= lightmap.y;

				// if(texcoord.x>0.5) oIndirect_SSS *= 0.0;
				// apply to ambient light.

				float thingy = SkySSS;
				thingy = pow(thingy,3.5);
				thingy = 1-pow(1-thingy,5);

				Indirect_lighting = Indirect_lighting + Indirect_SSS * ambientColor;
				// Indirect_lighting = max(Indirect_lighting, Indirect_SSS * ambientColor);
				// Indirect_lighting += Indirect_SSS * ambientColor;

				// #ifdef OVERWORLD_SHADER
				// 	if(LabSSS > 0.0) Indirect_lighting += (1.0-SkySSS) * LightningPhase * lightningEffect *  pow(lightmap.y,10);
				// #endif
			}
		#endif
	
	/////////////////////////////////////////////////////////////////////////
	/////////////////////////////	FINALIZE	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////

		// shadowColor *= 0.0;
		// SSSColor *= 0.0;

		#ifdef SSS_view
			albedo = vec3(1);
			NdotL = 0;
		#endif
		#if defined END_SHADER
			Direct_lighting *= AO;
		#endif
		#ifdef OVERWORLD_SHADER
			

			#ifdef AO_in_sunlight
				// Direct_lighting = max(shadowColor*NdotL * (AO*0.7+0.3), SSSColor);
				Direct_lighting = shadowColor*NdotL*(AO*0.7+0.3) + SSSColor * (1.0-NdotL);
			#else
				// Direct_lighting = max(shadowColor*NdotL, SSSColor);
				Direct_lighting = shadowColor*NdotL + SSSColor * (1.0-NdotL);
			#endif
		#endif

		#if defined OVERWORLD_SHADER && defined DEFERRED_SPECULAR
			if(!hand && !entities) applyPuddles(feetPlayerPos + cameraPosition, FlatNormals, lightmap.y, isWater, albedo, normal, SpecularTex.r, SpecularTex.g);
		#endif

		vec3 FINAL_COLOR = (Indirect_lighting + Direct_lighting) * albedo;

		Emission(FINAL_COLOR, albedo, SpecularTex.a, exposure);
		
		if(lightningBolt) FINAL_COLOR = vec3(77.0, 153.0, 255.0);
		
		#if defined DEFERRED_SPECULAR	
			vec3 specularNoises = vec3(BN.xy, blueNoise());
			vec3 specularNormal = slopednormal;
			if (dot(slopednormal, (feetPlayerPos_normalized)) > 0.0) specularNormal = FlatNormals;
			
			FINAL_COLOR = specularReflections(viewPos, feetPlayerPos_normalized, WsunVec, specularNoises, specularNormal, SpecularTex.r, SpecularTex.g, albedo, FINAL_COLOR, shadowColor, lightmap.y, hand, isWater || (!isWater && isEyeInWater == 1), flashLightSpecularData);
		#endif

		gl_FragData[0].rgb = FINAL_COLOR;

	}else{
		vec3 Background = vec3(0.0);

		#ifdef OVERWORLD_SHADER
			float atmosphereGround = 1.0 - exp2(-50.0 * pow(clamp(feetPlayerPos_normalized.y+0.025,0.0,1.0),2.0)); // darken the ground in the sky.

			#if RESOURCEPACK_SKY == 0 || RESOURCEPACK_SKY == 1 || RESOURCEPACK_SKY == 3
				// vec3 orbitstar = vec3(feetPlayerPos_normalized.x,abs(feetPlayerPos_normalized.y),feetPlayerPos_normalized.z); orbitstar.x -= WsunVec.x*0.2;
				vec3 orbitstar = normalize(mat3(gbufferModelViewInverse) * toScreenSpace(vec3(texcoord/RENDER_SCALE,1.0)));
				float radiance = 2.39996 - worldTime * STAR_ROTATION_MULT/ 24000.0;
				mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));
				orbitstar.xy *= rotationMatrix;

				Background += stars(orbitstar) * 10.0 * clamp(-unsigned_WsunVec.y*2.0,0.0,1.0);

				#if !defined ambientLight_only && (RESOURCEPACK_SKY == 0 || RESOURCEPACK_SKY == 1)

					Background += drawSun(dot(unsigned_WsunVec, feetPlayerPos_normalized), 0, DirectLightColor,vec3(0.0));

					vec3 moonLightCol = moonCol / 2400.0;

					Background += drawMoon(feetPlayerPos_normalized, WmoonVec, moonLightCol, Background); 
					// Background += drawSun(dot(WmoonVec, feetPlayerPos_normalized),0, moonLightCol,vec3(0.0));
				#endif

				Background *= atmosphereGround;
			#endif

			// Render aurora
			Background += drawAurora(feetPlayerPos_normalized, noise) * aurMult;

			vec3 Sky = skyFromTex(feetPlayerPos_normalized, colortex4)/1200.0 * Sky_Brightness;
			Background += Sky;
			
		#endif

		#if defined OVERWORLD_SHADER && defined VOLUMETRIC_CLOUDS && !defined CLOUDS_INTERSECT_TERRAIN
			vec4 Clouds = texture2D_bicubic_offset(colortex0, texcoord*CLOUDS_QUALITY, noise, RENDER_SCALE.x);
			Background = Background * Clouds.a + Clouds.rgb;
		#endif

		gl_FragData[0].rgb = clamp(fp10Dither(Background, triangularize(noise_2)), 0.0, 65000.);
	}


	if(translucentMasks > 0.0 && isEyeInWater != 1){
		
		// water absorbtion will impact ALL light coming up from terrain underwater.
		gl_FragData[0].rgb *= Absorbtion;
		
		vec4 vlBehingTranslucents = BilateralUpscale_VLFOG(colortex13, depthtex1, gl_FragCoord.xy - 1.5, ld(z));

    	gl_FragData[0].rgb = gl_FragData[0].rgb * vlBehingTranslucents.a + vlBehingTranslucents.rgb;

	}
	
	////// DEBUG VIEW STUFF
	#if DEBUG_VIEW == debug_SHADOWMAP	
		gl_FragData[0].rgb = vec3(1.0) * (Shadows * 0.9 + 0.1);
		
		if(dot(feetPlayerPos_normalized, unsigned_WsunVec) > 0.999 ) gl_FragData[0].rgb = vec3(10,10,0);
		if(dot(feetPlayerPos_normalized, -WmoonVec) > 0.999 ) gl_FragData[0].rgb = vec3(1,1,10);
	#endif
	#if DEBUG_VIEW == debug_NORMALS
		if(swappedDepth >= 1.0) Direct_lighting = vec3(1.0);
		gl_FragData[0].rgb = normal ;
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
		if(swappedDepth < 1.0) gl_FragData[0].rgb = vec3(NdotL);
	#endif
	#if DEBUG_VIEW == debug_VIEW_POSITION
		gl_FragData[0].rgb = viewPos * 0.001;
	#endif
	#if DEBUG_VIEW == debug_FILTERED_STUFF
		if(hideGUI == 0){
			float value = SSAO_SSS.y;
			value = pow(value,3.5);
			value = 1-pow(1-value,5);

			if(hideGUI == 1) value = pow(SSAO_SSS.x,6);
			gl_FragData[0].rgb = vec3(value);

			if(swappedDepth >= 1.0) gl_FragData[0].rgb  = vec3(1.0);
		}
	#endif

	/* RENDERTARGETS:3 */
}