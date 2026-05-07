#define ANTIALIASING_RELATED_SETTINGS
#define NETHER_RELATED_SETTINGS
#define END_RELATED_SETTINGS
#define SKY_RELATED_SETTINGS
#define ATMOSPHERE_COEFF_RELATED_SETTINGS
#define DISTANCE_BASED_FOG_RELATED_SETTINGS
#define SHADOWMAP_CONSTANT_RELATED_SETTINGS
#define AMBIENT_LIGHT_RELATED_SETTINGS
#define SEASONS_RELATED_SETTINGS
#define VOLUMETRIC_CLOUD_RELATED_SETTINGS
#define VOLUMETRIC_FOG_RELATED_SETTINGS
#define WATER_RELATED_SETTINGS
#include "/lib/settings.glsl"

#include "/lib/macro_lod_mod.glsl"

#define EXCLUDE_WRITE_TO_LUT

flat varying vec4 lightCol;
flat varying vec3 averageSkyCol;
flat varying vec3 averageSkyCol_Clouds;

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
// uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex10;
uniform sampler2D colortex12;
uniform sampler2D colortex14;


flat varying vec3 WsunVec;
uniform vec3 sunVec;
uniform float sunElevation;

// uniform float far;
uniform float near;
uniform float dhFarPlane;
uniform float dhNearPlane;

uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;

#if defined VIVECRAFT
	uniform bool vivecraftIsVR;
	uniform vec3 vivecraftRelativeMainHandPos;
	uniform vec3 vivecraftRelativeOffHandPos;
	uniform mat4 vivecraftRelativeMainHandRot;
	uniform mat4 vivecraftRelativeOffHandRot;
#endif

uniform int frameCounter;
uniform float frameTimeCounter;

// varying vec2 texcoord;
uniform vec2 texelSize;

uniform float viewHeight;
uniform float viewWidth;

uniform int isEyeInWater;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;
uniform float eyeAltitude;
uniform float caveDetection;
uniform float skyLightLevelSmooth;
uniform float waterEnteredAltitude;

vec4 blueNoise(vec2 coord){
  return texelFetch(colortex6, ivec2(coord)%512 , 0) ;
}
vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}

uniform int hideGUI;
#define DHVLFOG
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/projections.glsl"
#include "/lib/res_params.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/waterBump.glsl"

#include "/lib/DistantHorizons_projections.glsl"

float DH_ld(float dist) {
    return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
}
float DH_inv_ld (float lindepth){
	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}

#define IS_LPV_ENABLED

#if defined LPV_VL_FOG_ILLUMINATION && defined IS_LPV_ENABLED
	
	#ifdef IS_LPV_ENABLED
		#extension GL_ARB_shader_image_load_store: enable
		#extension GL_ARB_shading_language_packing: enable
	#endif

	#ifdef IS_LPV_ENABLED
		uniform usampler1D texBlockData;
		uniform sampler3D texLpv1;
		uniform sampler3D texLpv2;
	#endif

	// #ifdef IS_LPV_ENABLED
	// 	uniform int heldItemId;
	// 	uniform int heldItemId2;
	// #endif

	#ifdef IS_LPV_ENABLED
		#include "/lib/hsv.glsl"
		#include "/lib/lpv_common.glsl"
		#include "/lib/lpv_render.glsl"
	#endif
	vec4 raymarchLPV(
		in vec3 viewPos,
		in float dither
	){
		#if !defined LPV_VL_FOG_ILLUMINATION
			return vec3(0.0);
		#endif

		int SAMPLECOUNT = 8;
		vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
		vec3 LPVrayStartPos = playerPos - gbufferModelViewInverse[3].xyz;
		
		// ensure the max marching distance is the voxel distance, or the render distance if the voxels go farther than it
		float LPVRayLength = length(LPVrayStartPos);
		#if LPV_SIZE == 8
			LPVrayStartPos *= min(LPVRayLength, min(256.0,far))/LPVRayLength;
		#elif LPV_SIZE == 7
			LPVrayStartPos *= min(LPVRayLength, min(128.0,far))/LPVRayLength;
		#elif LPV_SIZE == 6
			LPVrayStartPos *= min(LPVRayLength, min(64.0,far))/LPVRayLength;
		#endif
		LPVRayLength = length(LPVrayStartPos);

		vec3 LPVrayProgress = vec3(0.0);
		vec4 color = vec4(0.0,0.0,0.0,1.0);
		float expFactor = 11.0;

		for (int i = 0; i < SAMPLECOUNT; i++) {
			float d = (pow(expFactor, float(i+dither)/float(SAMPLECOUNT))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
			float dd = pow(expFactor, float(i+dither)/float(SAMPLECOUNT)) * log(expFactor) / float(SAMPLECOUNT)/(expFactor-1.0);

			LPVrayProgress = gbufferModelViewInverse[3].xyz + d*LPVrayStartPos;

			vec3 lpvPos = GetLpvPosition(LPVrayProgress);

        	float fadeLength = 10.0; // in blocks
        	vec3 cubicRadius = clamp(	min(((LpvSize3-1.0) - lpvPos)/fadeLength,      lpvPos/fadeLength) ,0.0,1.0);
        	float LpvFadeF = cubicRadius.x*cubicRadius.y*cubicRadius.z;

			if(LpvFadeF < 0.01) break;

			vec3 sampleColor = SampleLpvLinear(lpvPos).rgb;
			#ifdef VANILLA_LIGHTMAP_MASK
				vec3 lighting = sampleColor * LPV_VL_FOG_ILLUMINATION_BRIGHTNESS * 25. * exp(-10 * (1.0-luma(sampleColor)));
			#else
				vec3 lighting = sampleColor * LPV_VL_FOG_ILLUMINATION_BRIGHTNESS * 25. * exp(-5 * (1.0-luma(sampleColor)));
			#endif

			float density = 0.0001;
			float volumeCoeff = exp(-dd*density*LPVRayLength);

			color.rgb += (lighting - lighting * volumeCoeff) * color.a;
			color.a *= volumeCoeff;
		}
		return color.rgba;
	}

#endif

float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}

uniform float nightVision;

#define LIGHTNINGFLASH_VL
#include "/lib/lightning_stuff.glsl"

#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif
	
	flat varying vec3 refractedSunVec;

	
	#include "/lib/scene_controller.glsl"


	#define TIMEOFDAYFOG

	#include "/lib/volumetricClouds.glsl"
	#include "/lib/climate_settings.glsl"
	#include "/lib/overworld_fog.glsl"
#endif
#ifdef NETHER_SHADER
uniform sampler2D colortex4;
	#include "/lib/nether_fog.glsl"
#endif
#ifdef END_SHADER
uniform sampler2D colortex4;
	#include "/lib/end_fog.glsl"
	// #include "/lib/end_volumetrics.glsl"
#endif

#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)


#include "/lib/TAA_jitter.glsl"


/*
from https://blog.demofox.org/2022/01/01/interleaved-gradient-noise-a-different-kind-of-low-discrepancy-sequence/
Copyright 2019 Alan Wolfe

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
float interleaved_gradientNoise_temporal(){
	vec2 coord = gl_FragCoord.xy + 5.588238 * float(frameCounter%64);
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)) ;
	return noise;
}

float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}

float blueNoise(){
  return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter );
}

float R2_dither(){
  	// #if TAA_MODE > 0
		vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	// #else
	// 	vec2 coord = gl_FragCoord.xy;
	// #endif
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}

vec4 waterVolumetrics_insidePOV(vec3 rayStart, vec3 rayEnd, float rayLength, vec2 dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL, vec3 LPV){
	int spCount = 8;

	vec3 start = toShadowSpaceProjected(rayStart);
	vec3 end = toShadowSpaceProjected(rayEnd);
	vec3 dV = (end-start);

	//limit ray length at 32 blocks for performance and reducing integration error
	//you can't see above this anyway
	float maxZ = min(rayLength,32.0)/(1e-8+rayLength);
	
	dV *= maxZ;
	rayLength *= maxZ;

	vec3 dVWorld = mat3(gbufferModelViewInverse) * (rayEnd - rayStart) * maxZ;

	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);
	
	#ifdef OVERWORLD_SHADER
		float lowlightlevel  = clamp(eyeBrightnessSmooth.y/240.0,0.1,1.0);
		float phase = fogPhase(VdotL) * 5.0;
	#else
		float lowlightlevel  = 1.0;
		float phase = 0.0;
	#endif

	float thing = -normalize(dVWorld).y;
	thing = clamp(thing + 0.333,0.0,1.0);
	thing = pow(1.0-pow(1.0-thing,2.0),2.0);
	thing *= 15.0;

	float expFactor = 11.0;
	for (int i=0;i<spCount;i++) {
		float d = (pow(expFactor, float(i+dither.x)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);		// exponential step position (0-1)
		float dd = pow(expFactor, float(i+dither.y)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);	//step length (derivative)
		
		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
		
		float distanceFromWaterSurface = max(-(progressW.y - waterEnteredAltitude),0.0);

		vec3 sh = vec3(1.0);

		#ifdef OVERWORLD_SHADER
			vec3 spPos = start.xyz + dV*d;

			//project into biased shadowmap space
			#ifdef DISTORT_SHADOWMAP
				float distortFactor = calcDistort(spPos.xy);
			#else
				float distortFactor = 1.0;
			#endif

			vec3 pos = vec3(spPos.xy*distortFactor, spPos.z);

			if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
				pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
				// sh = shadow2D( shadow, pos).x;

				#ifdef TRANSLUCENT_COLORED_SHADOWS
					sh = vec3(shadow2D(shadowtex0, pos).x);

					if(shadow2D(shadowtex1, pos).x > pos.z && sh.x < 1.0){
						vec4 translucentShadow = texture(shadowcolor0, pos.xy);
						if(translucentShadow.a < 0.9) sh = normalize(translucentShadow.rgb+0.0001);
					}
				#else
					sh = vec3(shadow2D(shadow, pos).x);
				#endif
			}

			sh *= GetCloudShadow(progressW, WsunVec * lightCol.a);

		#endif


		float bubble = exp2(-10.0 * clamp(1.0 - length(d*dVWorld) / 16.0, 0.0,1.0));
		float caustics = max(max(waterCaustics(progressW, WsunVec, -(progressW.y - waterEnteredAltitude)), phase*0.5) * mix(0.5, 1.5, bubble), phase);

		vec3 sunAbsorbance = exp(-waterCoefs * (distanceFromWaterSurface/abs(WsunVec.y)) * WATER_DEPTH_FREQUENCY_DIRECTLIGHT);
		vec3 WaterAbsorbance = exp(-waterCoefs * (distanceFromWaterSurface + thing) * WATER_DEPTH_FREQUENCY_INDIRECTLIGHT);

		vec3 Directlight = lightSource * sh * phase * caustics * sunAbsorbance;
		vec3 Indirectlight = ambient * WaterAbsorbance;

		vec3 light = (Indirectlight + Directlight + LPV) * scatterCoef;
		
		vec3 volumeCoeff = exp(-waterCoefs * length(dd*dVWorld));
		vL += (light - light * volumeCoeff) / waterCoefs * absorbance;
		absorbance *= volumeCoeff;

	}
	// waterabsorbtion = absorbance;
	return vec4(vL, dot(absorbance,vec3(0.333333)));
}

vec4 waterVolumetrics_outsidePOV( vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
	int spCount = rayMarchSampleCount;

	vec3 start = toShadowSpaceProjected(rayStart);
	vec3 end = toShadowSpaceProjected(rayEnd);
	vec3 dV = (end-start);

	//limit ray length at 32 blocks for performance and reducing integration error
	//you can't see above this anyway
	float maxZ = min(rayLength,12.0)/(1e-8+rayLength);
	dV *= maxZ;
	rayLength *= maxZ;
	estEndDepth *= maxZ;
	estSunDepth *= maxZ;
	
	vec3 wpos = mat3(gbufferModelViewInverse) * rayStart  + gbufferModelViewInverse[3].xyz;
	vec3 dVWorld = (wpos - gbufferModelViewInverse[3].xyz);
	
    #ifdef OVERWORLD_SHADER
		float phase = fogPhase(VdotL) * 5.0;
	#else
		float phase = 1.0;
	#endif

	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);
	
	float expFactor = 11.0;
	vec3 sh = vec3(1.0);

	// do this outside raymarch loop, masking the water surface is good enough
	#if defined OVERWORLD_SHADER
		float cloudShadow = GetCloudShadow(wpos+cameraPosition, WsunVec);
	#else
		float cloudShadow = 1.0;
	#endif
	
	float thing = -normalize(dVWorld).y;
	thing = clamp(thing ,0.0,1.0);
	thing = pow(1.0-pow(1.0-thing,2.0),2.0);
	thing *= 15.0;

	for (int i=0;i<spCount;i++) {
		float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);

		// progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
		
		vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition + d*dVWorld;

		#ifdef OVERWORLD_SHADER
			vec3 spPos = start.xyz + dV*d;

			//project into biased shadowmap space
			#ifdef DISTORT_SHADOWMAP
				float distortFactor = calcDistort(spPos.xy);
			#else
				float distortFactor = 1.0;
			#endif

			vec3 pos = vec3(spPos.xy*distortFactor, spPos.z);
			if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048.){
				pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
				// sh = shadow2D( shadow, pos).x;

				#ifdef TRANSLUCENT_COLORED_SHADOWS
					sh = vec3(shadow2D(shadowtex0, pos).x);

					if(shadow2D(shadowtex1, pos).x > pos.z && sh.x < 1.0){
						vec4 translucentShadow = texture(shadowcolor0, pos.xy);
						if(translucentShadow.a < 0.9) sh = normalize(translucentShadow.rgb+0.0001);
					}
				#else
					sh = vec3(shadow2D(shadow, pos).x);
				#endif
			}
		#endif

		vec3 sunAbsorbance = exp(-waterCoefs * estSunDepth * d * WATER_DEPTH_FREQUENCY_DIRECTLIGHT);
		vec3 ambientAbsorbance = exp(-waterCoefs * (estEndDepth * d + thing) * WATER_DEPTH_FREQUENCY_INDIRECTLIGHT);

		vec3 Directlight = lightSource * sh * cloudShadow * phase * sunAbsorbance;
		vec3 Indirectlight = ambient * ambientAbsorbance;

		vec3 light = (Indirectlight + Directlight) * scatterCoef;
		
		vec3 volumeCoeff = exp(-waterCoefs * dd * rayLength);
		vL += (light - light * volumeCoeff) / waterCoefs * absorbance;
		absorbance *= volumeCoeff;
	}
	
    return vec4(vL, dot(absorbance,vec3(0.333333)));
}

float fogPhase2(float lightPoint){
	float linear = 1.0 - clamp(lightPoint*0.5+0.5,0.0,1.0);
	float linear2 = 1.0 - clamp(lightPoint,0.0,1.0);

	float exponential = exp2(pow(linear,0.3) * -15.0 ) * 1.5;
	exponential += sqrt(exp2(sqrt(linear) * -12.5));

	return exponential;
}

//encoding by jodie
float encodeVec2(vec2 a){
    const vec2 constant1 = vec2( 1., 256.) / 65535.;
    vec2 temp = floor( a * 255. );
	return temp.x*constant1.x+temp.y*constant1.y;
}

vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}

float convertHandDepth(float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    return ndcDepth * 0.5 + 0.5;
}

float swapperlinZ(float depth, float _near, float _far) {
    return (2.0 * _near) / (_far + _near - depth * (_far - _near));
	// l = (2*n)/(f+n-d(f-n))
	// f+n-d(f-n) = 2n/l
	// -d(f-n) = ((2n/l)-f-n)
	// d = -((2n/l)-f-n)/(f-n)

}

float godrayTest( in vec3 viewPos, in vec3 lightDir, float noise, float vanilladepth){

	// return 1.0;1

	float godrays = 0.0;
	float samples = 8.0;

	float _near = near; float _far = far*4.0;

	// #ifdef DISTANT_HORIZONS
	// 	bool depthCheck = true;
	// #else
	// 	bool depthCheck = false;
	// #endif

	bool depthCheck = true;

	if (depthCheck) {
		_near = dhNearPlane;
		_far = dhFarPlane;
	}
    
    float lightRange = pow(clamp(-dot(normalize(viewPos), lightDir)+0.65,0.0,1.0),2.0);
    vec3 position = toClipSpace3_DH(viewPos, depthCheck) ;
	
	//prevents the ray from going behind the camera
	float rayLength = ((viewPos.z + lightDir.z * _far * sqrt(3.)) > -_near) ? (-_near - viewPos.z) / lightDir.z : _far * sqrt(3.);

    vec3 direction = toClipSpace3_DH(viewPos + lightDir*rayLength, depthCheck) - position;

	direction.xyz = direction.xyz / max(max(abs(direction.x)/0.0005, abs(direction.y)/0.0005),500.0);	//fixed step size
	direction *= 60.0;
	
	position.xy *= RENDER_SCALE;
	direction.xy *= RENDER_SCALE;
	
	vec3 newPos = position + direction*noise;

  	vec2 screenEdges = 2.0/vec2(viewWidth, viewHeight);

	for (int i = 0; i < int(samples); i++) { 
		newPos.xy = clamp(newPos.xy, screenEdges, 1.0-screenEdges);

		float sampleDepth = invLinZ(sqrt(texelFetch(colortex4, ivec2(newPos.xy/texelSize/4.0),0).a/65000.0));
		
		#ifdef DISTANT_HORIZONS
			if(depthCheck) sampleDepth = texelFetch(dhDepthTex1, ivec2(newPos.xy/texelSize),0).x;
		#endif
		
		godrays += (swapperlinZ(sampleDepth, _near, _far) > 1.0 ? 1.0 : lightRange);
		newPos += direction;
	}

	return godrays/samples;
}

float HG_phase(float x, float g){
    float gg = g * g;
    return (gg * -0.25 + 0.25) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5) / 3.14;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	/* RENDERTARGETS:0,13 */

	gl_FragData[1] = vec4(0.0,0.0,0.0,1.0);	
	
	float noise_2 = blueNoise();
	// float noise_1 = max(1.0 - R2_dither(),0.0015);
	float noise_1 = interleaved_gradientNoise_temporal();
	vec2 bnoise = blueNoise(gl_FragCoord.xy ).rg;

	int seed = frameCounter%40000;
	vec2 r2_sequence = R2_samples(seed).xy*5.0;
	vec2 BN = fract(r2_sequence + bnoise);

	vec2 tc = floor(gl_FragCoord.xy - 0.5)/VL_RENDERING_RESOLUTION_SCALE*texelSize;

	vec2 texcoord = tc/texelSize;
	vec2 texcoord_norm = tc;
	ivec2 texcoord_cast = ivec2(texcoord);
	// vec2 tc = floor(gl_FragCoord.xy)/VL_RENDERING_RESOLUTION_SCALE*texelSize + 0.5*texelSize;

	float alpha = texelFetch(colortex7,texcoord_cast,0).a;
	float blendedAlpha = texelFetch(colortex2, texcoord_cast,0).a;

	bool iswater = alpha > 0.99;

	float z0 = texelFetch(depthtex0, texcoord_cast,0).x;
	float z1 = texelFetch(depthtex1, texcoord_cast,0).x;

	#ifdef USING_LOD_MOD
		float DH_z0 = texelFetch(LOD_DEPTHTEX0, texcoord_cast,0).x;
		float DH_z1 = texelFetch(LOD_DEPTHTEX1, texcoord_cast,0).x;
	#else
		float DH_z0 = 0.0;
		float DH_z1 = 0.0;
	#endif
	
	vec3 viewPos0 = toScreenSpace_DH(tc/RENDER_SCALE, z0, DH_z0);
	vec3 viewPos1 = toScreenSpace_DH(tc/RENDER_SCALE, z1, DH_z1);
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos0 + gbufferModelViewInverse[3].xyz;
	vec3 playerPos_normalized = normalize(playerPos);

	float Vdiff = distance(viewPos1, viewPos0);
	float estimatedDepth = Vdiff * abs(playerPos_normalized.y);
	float estimatedSunDepth = Vdiff / abs(WsunVec.y); //assuming water plane

	float dirtAmount = Dirt_Amount;
	vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
	vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
	vec3 totEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
	vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

	// vec2 lightmap = decodeVec2(texelFetch(colortex14,texcoord_cast,0).a);
	vec2 lightmap = texelFetch(colortex14,texcoord_cast,0).ba;
	lightmap.xy = min(max(lightmap.xy - 0.05,0.0)*1.06,1.0);

	#if !defined OVERWORLD_SHADER
		lightmap.y = 1.0;
	#endif
	
	#ifdef USING_LOD_MOD
		if(z0 >= 1.0) lightmap = vec2(0.0,1.0);
	#endif

	vec2 curvedLightmaps = lightmap;
    float lightmapBrightspot = min(max(lightmap.x-0.7,0.0)*3.3333,1.0);
    lightmapBrightspot *= lightmapBrightspot*lightmapBrightspot;
    float lightmapLight = 1.0-sqrt(1.0-lightmap.x);
    lightmapLight *= lightmapLight;
    curvedLightmaps.x = mix(lightmapLight, 2.5, lightmapBrightspot);
    curvedLightmaps.y = (pow(lightmap.y,15.0)*2.0 + lightmap.y*lightmap.y)/3.0;


	vec3 directLightColor = lightCol.rgb / 2400.0;
	vec3 indirectLightColor = averageSkyCol / 1200.0;
	vec3 indirectLightColor_dynamic = averageSkyCol_Clouds / 1200.0;
	
    vec3 indirectLight = indirectLightColor_dynamic * ambient_brightness; 
	float minimumLightAmount = 0.02*nightVision + 0.005 * mix(MINIMUM_INDOOR_LIGHT, MINIMUM_OUTDOOR_LIGHT, clamp(eyeBrightnessSmooth.y/240.0 + lightmap.y,0.0,1.0));

    vec3 indirectLight_fog = indirectLightColor * skyLightLevelSmooth * ambient_brightness; 
    indirectLight_fog += vec3(1.0) * (0.02*nightVision + 0.005 * mix(MINIMUM_INDOOR_LIGHT, MINIMUM_OUTDOOR_LIGHT, skyLightLevelSmooth));
	
	// the idea is to interpolate between 4 HG function calls with different G parameters
	float SdotV = dot(WsunVec, playerPos_normalized);
	float backScatterPhase = HG_phase(-SdotV, 0.25) * 2.0;
	vec4 phaseLevels = vec4(HG_phase(SdotV, 0.80), HG_phase(SdotV, 0.55), HG_phase(SdotV, 0.35), HG_phase(SdotV, 0.10));


	float cloudPlaneDistance = 0.0;
	
	// #ifdef DISTANT_HORIZONS
	// 	float godrays = godrayTest(viewPos0, normalize(WsunVec*mat3(gbufferModelViewInverse)),BN.x, z0);
	// #else
		// float godrays = 1.0;
	// #endifd

	#if defined LPV_VL_FOG_ILLUMINATION
		vec4 LPV_ILLUMINATION = raymarchLPV(viewPos0, R2_dither());
	#else
		vec4 LPV_ILLUMINATION = vec4(0.0,0.0,0.0,1.0);
	#endif
	
	float passAbsorbance = 1.0;

	#if defined OVERWORLD_SHADER
		vec4 VolumetricClouds = GetVolumetricClouds(viewPos0, BN, WsunVec, directLightColor, indirectLightColor, cloudPlaneDistance, phaseLevels, backScatterPhase);
	  	
  		#if defined OVERWORLD_SHADER && defined CAVE_FOG && defined CAVE_FOG_DARKEN_SKY
  		  if (isEyeInWater == 0 && eyeAltitude < 1500){
  		    float skyhole = pow(clamp(1.0-pow(max(playerPos_normalized.y - 0.6,0.0)*5.0,2.0),0.0,1.0),2) * caveDetection;
			VolumetricClouds.rgb *= 1.0-skyhole;
			VolumetricClouds.a = mix(VolumetricClouds.a, 1.0, skyhole);
  		  }
  		#endif
		
		vec4 VolumetricFog = GetVolumetricFog(viewPos0, vec2(noise_1), WsunVec, directLightColor, indirectLight_fog, indirectLight*skyLightLevelSmooth, cloudPlaneDistance, phaseLevels, backScatterPhase);

		#if defined LPV_VL_FOG_ILLUMINATION
			VolumetricFog.a *= LPV_ILLUMINATION.a;
			VolumetricFog.rgb = VolumetricFog.rgb * LPV_ILLUMINATION.a + LPV_ILLUMINATION.rgb;
		#endif

		// for bloomy fog mask
		gl_FragData[1].a = VolumetricFog.a;

		VolumetricFog = vec4(VolumetricClouds.rgb*VolumetricFog.a + VolumetricFog.rgb, VolumetricFog.a*VolumetricClouds.a);
	#endif

	#if defined NETHER_SHADER || defined END_SHADER
		vec4 VolumetricFog = GetVolumetricFog(viewPos0, noise_1, noise_1);
		
		#if defined LPV_VL_FOG_ILLUMINATION
			VolumetricFog.a *= LPV_ILLUMINATION.a;
			VolumetricFog.rgb = VolumetricFog.rgb * LPV_ILLUMINATION.a + LPV_ILLUMINATION.rgb;
		#endif

		// for bloomy fog mask
		gl_FragData[1].a = VolumetricFog.a;
	#endif

	if (isEyeInWater == 1){
		vec4 underWaterFog =  waterVolumetrics_insidePOV(vec3(0.0), viewPos0, length(viewPos0), vec2(noise_1), totEpsilon, scatterCoef, indirectLightColor_dynamic, directLightColor , dot(normalize(viewPos0), normalize(sunVec* lightCol.a ) ), LPV_ILLUMINATION.rgb);
		VolumetricFog = vec4(underWaterFog.rgb, 1.0);
	}
	
	// VolumetricFog = vec4(godrays,godrays,godrays,0.0);
	// VolumetricFog = raymarchTest(viewPos0, BN);
	// VolumetricFog = vec4(0.0,0.0,0.0,1.0);
	// VolumetricFog.rgb = vec3(0);
	gl_FragData[0] = clamp(VolumetricFog, 0.0, 65000.0);
	
	if(blendedAlpha > 0.0 || iswater){
		
		gl_FragData[1] = vec4(0.0,0.0,0.0,1.0);	

		#if defined OVERWORLD_SHADER
			VolumetricClouds = GetVolumetricClouds(viewPos1, vec2(noise_1), WsunVec, directLightColor, indirectLightColor, cloudPlaneDistance, phaseLevels, backScatterPhase);
	
			VolumetricFog = GetVolumetricFog(viewPos1, vec2(noise_1), WsunVec, directLightColor, indirectLight_fog, indirectLight, cloudPlaneDistance, phaseLevels, backScatterPhase);

			VolumetricFog = vec4(VolumetricClouds.rgb*VolumetricFog.a + VolumetricFog.rgb, VolumetricFog.a*VolumetricClouds.a);
		#endif
		
		#if defined NETHER_SHADER || defined END_SHADER
			VolumetricFog = GetVolumetricFog(viewPos1, noise_1, noise_1);
		#endif
		
		gl_FragData[1] = clamp(VolumetricFog, 0.0, 65000.0);

		if(iswater && isEyeInWater != 1){
			vec4 underWaterVL = waterVolumetrics_outsidePOV(viewPos0, viewPos1, estimatedDepth, estimatedSunDepth, Vdiff, noise_1, totEpsilon, scatterCoef, indirectLight*curvedLightmaps.y + vec3(TORCH_R, TORCH_G, TORCH_B) * curvedLightmaps.x + vec3(1.0) * minimumLightAmount, directLightColor, dot(normalize(viewPos0), normalize(sunVec*lightCol.a)));
			gl_FragData[1] = clamp(underWaterVL, 0.0, 65000.0);
		}
	}
}