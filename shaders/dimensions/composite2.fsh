#include "/lib/settings.glsl"

#define EXCLUDE_WRITE_TO_LUT

flat varying vec4 lightCol;
flat varying vec3 averageSkyCol;
flat varying vec3 averageSkyCol_Clouds;


uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
// uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex10;

flat varying vec3 WsunVec;
uniform vec3 sunVec;
uniform float sunElevation;

// uniform float far;
uniform float near;
uniform float dhFarPlane;
uniform float dhNearPlane;

// uniform mat4 gbufferModelViewInverse;
// uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
// uniform mat4 gbufferProjectionInverse;
// uniform mat4 gbufferProjection;
// uniform mat4 gbufferPreviousProjection;
// uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int frameCounter;
uniform float frameTimeCounter;

// varying vec2 texcoord;
uniform vec2 texelSize;
flat varying vec2 TAA_Offset;

uniform int isEyeInWater;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;
uniform float eyeAltitude;
uniform float caveDetection;

// uniform int dhRenderDistance;
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
	
	flat varying float exposure;

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


	vec3 LPV_FOG_ILLUMINATION(in vec3 playerPos, float dd, float dL){
		vec3 color = vec3(0.0);

		vec3 lpvPos = GetLpvPosition(playerPos);

        float fadeLength = 10.0; // in blocks
        vec3 cubicRadius = clamp(	min(((LpvSize3-1.0) - lpvPos)/fadeLength,      lpvPos/fadeLength) ,0.0,1.0);
        float LpvFadeF = cubicRadius.x*cubicRadius.y*cubicRadius.z;

		if(LpvFadeF > 0.0){
			// if(length(lpvSample.xyz) > 1e-5){

				vec3 lighting = SampleLpvLinear(lpvPos).rgb * (LPV_VL_FOG_ILLUMINATION_BRIGHTNESS/100.0);
				// float density = exp(-5.0 * clamp( 1.0 - length(lpvSample.xyz) / 16.0,0.0,1.0)) * (LPV_VL_FOG_ILLUMINATION_BRIGHTNESS/100.0) * LpvFadeF;
				float density = exp(-5.0 * (1.0-length(lighting.xyz)))  * LpvFadeF;
				// float density = (1-exp(-1.0-clamp(length(lighting.rgb),0.0,1.0),25) )* LpvFadeF;

				// float density = 0.01 * LpvFadeF;

				color = lighting - lighting * exp(-density*dd*dL);
			// }
		}

		return color;
	}

#endif
float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}

uniform float nightVision;

#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif
	flat varying vec3 refractedSunVec;


	#ifdef Daily_Weather
		flat varying vec4 dailyWeatherParams0;
		flat varying vec4 dailyWeatherParams1;
	#else
		vec4 dailyWeatherParams0 = vec4(CloudLayer0_coverage, CloudLayer1_coverage, CloudLayer2_coverage, 0.0);
		vec4 dailyWeatherParams1 = vec4(CloudLayer0_density, CloudLayer1_density, CloudLayer2_density, 0.0);
	#endif


	// uniform int dhRenderDistance;
	#define TIMEOFDAYFOG
	#include "/lib/lightning_stuff.glsl"

	// #define CLOUDS_INTERSECT_TERRAIN
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
#endif

#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)

float interleaved_gradientNoise_temporal(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter );
}

float R2_dither(){
  	// #ifdef TAA
		vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	// #else
	// 	vec2 coord = gl_FragCoord.xy;
	// #endif
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}

void waterVolumetrics_notoverworld(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient){
	inColor *= exp(-rayLength * waterCoefs);	//No need to take the integrated value
	
	int spCount = rayMarchSampleCount;
	vec3 start = toShadowSpaceProjected(rayStart);
	vec3 end = toShadowSpaceProjected(rayEnd);
	vec3 dV = (end-start);
	//limit ray length at 32 blocks for performance and reducing integration error
	//you can't see above this anyway
	float maxZ = min(rayLength,12.0)/(1e-8+rayLength);
	dV *= maxZ;


	rayLength *= maxZ;
	
	float dY = normalize(mat3(gbufferModelViewInverse) * rayEnd).y * rayLength;
	estEndDepth *= maxZ;
	estSunDepth *= maxZ;

	vec3 wpos = mat3(gbufferModelViewInverse) * rayStart  + gbufferModelViewInverse[3].xyz;
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);

	float expFactor = 11.0;
	for (int i=0;i<spCount;i++) {
		float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);
		vec3 spPos = start.xyz + dV*d;

		vec3 progressW = start.xyz+cameraPosition+dVWorld;

		vec3 ambientMul = exp(-max(estEndDepth * d,0.0) * waterCoefs );
		vec3 Indirectlight = ambientMul*ambient;

		vec3 light = Indirectlight * scatterCoef;

		vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs * absorbance;
		absorbance *= exp(-dd * rayLength * waterCoefs);
	}
	inColor += vL;

}

vec3 waterVolumetrics(vec3 rayStart, vec3 rayEnd, float rayLength, vec2 dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
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

	float expFactor = 11.0;
	for (int i=0;i<spCount;i++) {
		float d = (pow(expFactor, float(i+dither.x)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);		// exponential step position (0-1)
		float dd = pow(expFactor, float(i+dither.y)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);	//step length (derivative)
		
		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
		
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
						vec4 translucentShadow = texture2D(shadowcolor0, pos.xy);
						if(translucentShadow.a < 0.9) sh = normalize(translucentShadow.rgb+0.0001);
					}
				#else
					sh = vec3(shadow2D(shadow, pos).x);
				#endif
			}

			#ifdef VL_CLOUDS_SHADOWS
				sh *= GetCloudShadow(progressW, WsunVec);
			#endif
		#endif


		float bubble = exp2(-10.0 * clamp(1.0 - length(d*dVWorld) / 16.0, 0.0,1.0));
		float caustics = mix(max(max(waterCaustics(progressW, WsunVec), phase*0.5) * mix(0.5, 200.0, bubble), phase), 1.0, lowlightlevel);

		vec3 Directlight = lightSource * sh * phase * caustics*abs(WsunVec.y) * lowlightlevel;
		vec3 Indirectlight = ambient * lowlightlevel;

		vec3 WaterAbsorbance = exp(-waterCoefs * rayLength * d);

		vec3 light = (Indirectlight + Directlight) * WaterAbsorbance * scatterCoef;
		
		vec3 volumeCoeff = exp(-waterCoefs * rayLength * dd);
		vL += (light - light * volumeCoeff) / waterCoefs * absorbance;
		absorbance *= volumeCoeff;

	}
	return vL;
}

vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord)%512 , 0) ;
}
vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
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



uniform int framemod8;
#include "/lib/TAA_jitter.glsl"




vec3 toClipSpace3Prev(vec3 viewSpacePosition) {
    return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 closestToCamera5taps(vec2 texcoord, sampler2D depth)
{
	vec2 du = vec2(texelSize.x*2., 0.0);
	vec2 dv = vec2(0.0, texelSize.y*2.);

	vec3 dtl = vec3(texcoord,0.) + vec3(-texelSize, 				texture2D(depth, texcoord - dv - du).x);
	vec3 dtr = vec3(texcoord,0.) + vec3( texelSize.x, -texelSize.y, texture2D(depth, texcoord - dv + du).x);
	vec3 dmc = vec3(texcoord,0.) + vec3( 0.0, 0.0, 					texture2D(depth, texcoord).x);
	vec3 dbl = vec3(texcoord,0.) + vec3(-texelSize.x, texelSize.y, 	texture2D(depth, texcoord + dv - du).x);
	vec3 dbr = vec3(texcoord,0.) + vec3( texelSize.x, texelSize.y, 	texture2D(depth, texcoord + dv + du).x);

	vec3 dmin = dmc;
	dmin = dmin.z > dtr.z ? dtr : dmin;
	dmin = dmin.z > dtl.z ? dtl : dmin;
	dmin = dmin.z > dbl.z ? dbl : dmin;
	dmin = dmin.z > dbr.z ? dbr : dmin;
	
	#ifdef TAA_UPSCALING
		dmin.xy = dmin.xy/RENDER_SCALE;
	#endif

	return dmin;
}

vec3 toClipSpace3Prev_DH( vec3 viewSpacePosition, bool depthCheck ) {

	#ifdef DISTANT_HORIZONS
		mat4 projectionMatrix = depthCheck ? dhPreviousProjection : gbufferPreviousProjection;
   		return projMAD(projectionMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#else
    	return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#endif
}

vec3 toScreenSpace_DH_special(vec3 POS, bool depthCheck ) {

	vec4 viewPos = vec4(0.0);
	vec3 feetPlayerPos = vec3(0.0);
	vec4 iProjDiag = vec4(0.0);

	#ifdef DISTANT_HORIZONS
    	if (depthCheck) {
			iProjDiag = vec4(dhProjectionInverse[0].x, dhProjectionInverse[1].y, dhProjectionInverse[2].zw);

    		feetPlayerPos = POS * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + dhProjectionInverse[3];
			viewPos.xyz /= viewPos.w;

		} else {
	#endif
			iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);

    		feetPlayerPos = POS * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
			viewPos.xyz /= viewPos.w;
			
	#ifdef DISTANT_HORIZONS
		}
	#endif

    return viewPos.xyz;
}
vec4 VLTemporalFiltering(vec3 viewPos, bool depthCheck, vec4 color){
	vec2 texcoord = gl_FragCoord.xy * texelSize;	

	vec2 VLtexCoord = texcoord/VL_RENDER_RESOLUTION;

	// vec3 closestToCamera = closestToCamera5taps(texcoord, depthtex0);
	// vec3 viewPos_5tap = toScreenSpace(closestToCamera);

	// get previous frames position stuff for UV
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * playerPos + gbufferPreviousModelView[3].xyz;
	previousPosition = toClipSpace3Prev(previousPosition);

	vec2 velocity = previousPosition.xy - VLtexCoord/RENDER_SCALE;
	previousPosition.xy = VLtexCoord + velocity;

	vec4 currentFrame = color;
	if (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0) return currentFrame;

	// vec4 col0 = currentFrame; // can use this because its the center sample.
	// vec4 col1 = texture2D(colortex0, VLtexCoord + vec2( texelSize.x,  texelSize.y));
	// vec4 col2 = texture2D(colortex0, VLtexCoord + vec2( texelSize.x, -texelSize.y));
	// vec4 col3 = texture2D(colortex0, VLtexCoord + vec2(-texelSize.x, -texelSize.y));
	// vec4 col4 = texture2D(colortex0, VLtexCoord + vec2(-texelSize.x,  texelSize.y));
	// vec4 col5 = texture2D(colortex0, VLtexCoord + vec2( 0.0,			    texelSize.y));
	// vec4 col6 = texture2D(colortex0, VLtexCoord + vec2( 0.0,			   -texelSize.y));
	// vec4 col7 = texture2D(colortex0, VLtexCoord + vec2(-texelSize.x,  		     0.0));
	// vec4 col8 = texture2D(colortex0, VLtexCoord + vec2( texelSize.x,  		     0.0));

	// vec4 colMax = max(col0,max(col1,max(col2,max(col3, max(col4, max(col5, max(col6, max(col7, col8))))))));
	// vec4 colMin = min(col0,min(col1,min(col2,min(col3, min(col4, min(col5, min(col6, min(col7, col8))))))));

	// // colMin = 0.5 * (colMin + min(col0,min(col5,min(col6,min(col7,col8)))));
	// // colMax = 0.5 * (colMax + max(col0,max(col5,max(col6,max(col7,col8)))));

	vec4 frameHistory = texture2D(colortex10, previousPosition.xy*VL_RENDER_RESOLUTION);
	vec4 clampedFrameHistory = frameHistory;
  	// vec4 clampedFrameHistory = clamp(frameHistory, colMin, colMax);

	float blendFactor = 0.25;
	blendFactor = clamp(length(velocity/texelSize),blendFactor,0.2);

	// if(min(frameHistory.a,rejection) > 0.0) blendFactor = 1.0;

	return mix(clampedFrameHistory, currentFrame, blendFactor);
}

float convertHandDepth(float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    return ndcDepth * 0.5 + 0.5;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////


void main() {

	/* RENDERTARGETS:0 */

	float noise_2 = blueNoise();
	float noise_1 = max(1.0 - R2_dither(),0.0015);
	// float noise_2 = interleaved_gradientNoise_temporal();
	vec2 bnoise = blueNoise(gl_FragCoord.xy ).rg;

	int seed = (frameCounter*5)%40000;
	vec2 r2_sequence = R2_samples(seed).xy;
	vec2 BN = fract(r2_sequence + bnoise);

	// vec2 tc = floor(gl_FragCoord.xy)/VL_RENDER_RESOLUTION*texelSize + texelSize*0.5;
	vec2 tc = gl_FragCoord.xy/VL_RENDER_RESOLUTION*texelSize;// + texelSize*0.5;

	bool iswater = texture2D(colortex7,tc).a > 0.99;

	vec2 jitter = TAA_Offset/VL_RENDER_RESOLUTION*texelSize*0.5;

	float depth = texture2D(depthtex0, tc + jitter).x;
	
	float z0 = depth < 0.56 ? convertHandDepth(depth) : depth;

	#ifdef DISTANT_HORIZONS
		float DH_z0 = texture2D(dhDepthTex,tc).x;
	#else
		float DH_z0 = 0.0;
	#endif
	
	vec3 viewPos0 = toScreenSpace_DH(tc/RENDER_SCALE, z0, DH_z0);
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos0 + gbufferModelViewInverse[3].xyz;
	vec3 playerPos_normalized = normalize(playerPos);

	float dirtAmount = Dirt_Amount;
	vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
	vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
	vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
	vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

	vec3 directLightColor = lightCol.rgb / 2400.0;
	vec3 indirectLightColor = averageSkyCol / 1200.0;
	vec3 indirectLightColor_dynamic = averageSkyCol_Clouds / 1200.0;
	
	// indirectLightColor_dynamic += MIN_LIGHT_AMOUNT * 0.02 * 0.2 + nightVision*0.02;

	#if defined OVERWORLD_SHADER
		// z0 = texture2D(depthtex0, tc + jitter/VL_RENDER_RESOLUTION).x;
		// viewPos0 = toScreenSpace_DH(tc/RENDER_SCALE, z0, DH_z0);
		vec4 VolumetricClouds = GetVolumetricClouds(viewPos0, BN, WsunVec, directLightColor, indirectLightColor);
		
		#ifdef CAVE_FOG
		
  	  		float skyhole = pow(clamp(1.0-pow(max(playerPos_normalized.y - 0.6,0.0)*5.0,2.0),0.0,1.0),2)* caveDetection;
			VolumetricClouds.rgb *= 1.0-skyhole;
			VolumetricClouds.a = mix(VolumetricClouds.a, 1.0,  skyhole);
		#endif
	#endif

	#ifdef OVERWORLD_SHADER
		float atmosphereAlpha = 1.0;

		vec3 sceneColor = texelFetch2D(colortex3,ivec2(tc/texelSize),0).rgb * VolumetricClouds.a + VolumetricClouds.rgb;
		vec4 VolumetricFog = GetVolumetricFog(viewPos0, BN, directLightColor, indirectLightColor, indirectLightColor_dynamic, atmosphereAlpha, VolumetricClouds.rgb);

	#endif
	
	#if defined NETHER_SHADER || defined END_SHADER
		vec4 VolumetricFog = GetVolumetricFog(viewPos0, BN.x, BN.y);
	#endif

	#if defined OVERWORLD_SHADER
		VolumetricFog = vec4(VolumetricClouds.rgb * VolumetricFog.a  + VolumetricFog.rgb, VolumetricFog.a*VolumetricClouds.a);
		// VolumetricFog = vec4(VolumetricClouds.rgb * VolumetricFog.a  + VolumetricFog.rgb, VolumetricFog.a*VolumetricClouds.a);
	#endif

	if (isEyeInWater == 1){
		vec3 underWaterFog =  waterVolumetrics(vec3(0.0), viewPos0, length(viewPos0), BN, totEpsilon, scatterCoef, indirectLightColor_dynamic, directLightColor , dot(normalize(viewPos0), normalize(sunVec* lightCol.a ) 	));
		
		VolumetricFog = vec4(underWaterFog, 1.0);
	}

	gl_FragData[0] = clamp(VolumetricFog, 0.0, 65000.0);
	

	// vec4 currentFrame = VolumetricFog;
	// vec4 previousFrame = texture2D(colortex10, gl_FragCoord.xy * texelSize);

	// vec4 temporallyFilteredVL = VLTemporalFiltering(viewPos0, z0 >= 1.0, VolumetricFog);

	// gl_FragData[1] = temporallyFilteredVL;

}