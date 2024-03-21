#include "/lib/settings.glsl"

flat varying vec4 lightCol;
flat varying vec3 averageSkyCol;
flat varying vec3 averageSkyCol_Clouds;

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;

uniform sampler2D colortex2;
uniform sampler2D colortex3;
// uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D colortex7;

flat varying vec3 WsunVec;
uniform vec3 sunVec;
uniform float sunElevation;

// uniform float far;
uniform float dhFarPlane;
uniform float dhNearPlane;

uniform int frameCounter;
uniform float frameTimeCounter;

// varying vec2 texcoord;
uniform vec2 texelSize;
// flat varying vec2 TAA_Offset;

uniform int isEyeInWater;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;
uniform float eyeAltitude;

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


#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;
	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif
	flat varying vec3 refractedSunVec;
	
	#define TIMEOFDAYFOG
	#include "/lib/lightning_stuff.glsl"
	#include "/lib/volumetricClouds.glsl"
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
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+frameTimeCounter*51.9521);
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}

// float interleaved_gradientNoise(){
// 	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+ 1.0/1.6180339887 * frameCounter);
// }
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a+ 1.0/1.6180339887 * frameCounter );
}
float R2_dither(){
  	#ifdef TAA
		vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	#else
		vec2 coord = gl_FragCoord.xy;
	#endif
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

// #ifdef OVERWORLD_SHADER
// vec4 waterVolumetrics_test( vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
// 	int spCount = rayMarchSampleCount;

// 	vec3 start = toShadowSpaceProjected(rayStart);
// 	vec3 end = toShadowSpaceProjected(rayEnd);
// 	vec3 dV = (end-start);

// 	//limit ray length at 32 blocks for performance and reducing integration error
// 	//you can't see above this anyway
// 	float maxZ = min(rayLength,12.0)/(1e-8+rayLength);
// 	dV *= maxZ;
// 	rayLength *= maxZ;
// 	estEndDepth *= maxZ;
// 	estSunDepth *= maxZ;
	
// 	vec3 wpos = mat3(gbufferModelViewInverse) * rayStart  + gbufferModelViewInverse[3].xyz;
// 	vec3 dVWorld = (wpos - gbufferModelViewInverse[3].xyz);

// 	vec3 newabsorbance = exp(-rayLength * waterCoefs);	// No need to take the integrated value
    
// 	float phase = fogPhase(VdotL) * 5.0;
// 	vec3 absorbance = vec3(1.0);
// 	vec3 vL = vec3(0.0);


// 	float expFactor = 11.0;
// 	for (int i=0;i<spCount;i++) {
// 		float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
// 		float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);
// 		vec3 spPos = start.xyz + dV*d;

// 		vec3 progressW = start.xyz+cameraPosition+dVWorld;

// 		//project into biased shadowmap space
// 		#ifdef DISTORT_SHADOWMAP
// 			float distortFactor = calcDistort(spPos.xy);
// 		#else
// 			float distortFactor = 1.0;
// 		#endif

// 		vec3 pos = vec3(spPos.xy*distortFactor, spPos.z);
// 		float sh = 1.0;
// 		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
// 			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
// 			sh =  shadow2D( shadow, pos).x;
// 		}

// 		#ifdef VL_CLOUDS_SHADOWS
// 			sh *= GetCloudShadow_VLFOG(progressW,WsunVec);
// 		#endif

// 		vec3 sunMul = exp(-estSunDepth * d * waterCoefs * 1.1);
// 		vec3 ambientMul = exp(-estEndDepth * d * waterCoefs );

// 		vec3 Directlight = (lightSource * phase * sunMul) * sh;
// 		// vec3 Indirectlight = ambient * ambientMul;
// 		vec3 Indirectlight = max(ambient * ambientMul, vec3(0.01,0.2,0.4) * ambientMul * 0.1) ;

// 		vec3 light = (Indirectlight + Directlight) * scatterCoef;

// 		vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs * absorbance;
// 		absorbance *= exp(-waterCoefs * dd * rayLength);
// 	}
// 	// inColor += vL;
//     return vec4( vL, dot(newabsorbance,vec3(0.335)));
// }


void waterVolumetrics(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEyeDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
	int spCount = 8;

	vec3 start = toShadowSpaceProjected(rayStart);
	vec3 end = toShadowSpaceProjected(rayEnd);
	vec3 dV = (end-start);

	//limit ray length at 32 blocks for performance and reducing integration error
	//you can't see above this anyway
	float maxZ = min(rayLength,32.0)/(1e-8+rayLength);
	dV *= maxZ;
	vec3 dVWorld = mat3(gbufferModelViewInverse) * (rayEnd - rayStart) * maxZ;
	rayLength *= maxZ;
	float dY = normalize(mat3(gbufferModelViewInverse) * rayEnd).y * rayLength;

	vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;

	#ifdef OVERWORLD_SHADER
		float phase = fogPhase(VdotL) * 5.0;
	#endif
	
	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);

	float YFade = pow(normalize(dVWorld).y*0.3+0.7,1.5);

	#ifdef OVERWORLD_SHADER
	float lowlightlevel  = clamp(eyeBrightnessSmooth.y/240.0,0.1,1.0);
	#else
	float lowlightlevel  = 1.0;
	#endif
	// lowlightlevel = pow(lowlightlevel,0.5);

	float expFactor = 11.0;
	for (int i=0;i<spCount;i++) {
		float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);		// exponential step position (0-1)
		float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);	//step length (derivative)
		
		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
		
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
				// sh =  shadow2D( shadow, pos).x;
				#ifdef TRANSLUCENT_COLORED_SHADOWS
					sh = vec3(shadow2D(shadowtex0, pos).x);

					if(shadow2D(shadowtex1, pos).x > pos.z && sh.x < 1.0){
						sh = normalize(texture2D(shadowcolor0, pos.xy).rgb+0.0001);
					}
				#else
					sh = vec3(shadow2D(shadow, pos).x);
				#endif
			}

			#ifdef VL_CLOUDS_SHADOWS
				sh *= GetCloudShadow_VLFOG(progressW,WsunVec);
			#endif


			// float bubble = 1.0 - pow(1.0-pow(1.0-min(max(1.0 - length(d*dVWorld) / (16),0.0)*5.0,1.0),2.0),2.0);
			float bubble = exp( -7.0 * clamp(1.0 - length(d*dVWorld) / 16.0, 0.0,1.0) );
			float bubble2 = max(pow(length(d*dVWorld)/24,5)*100.0,0.0) + 1;

			float sunCaustics = (waterCaustics(progressW, WsunVec)) * mix(0.25,10.0,bubble) + 0.75;

			vec3 sunMul = exp(-1 * d * waterCoefs * 1.1);
			vec3 Directlight = ((lightSource* sh) * phase * sunMul * sunCaustics) * lowlightlevel * pow(abs(WsunVec.y),1);
		#else
			vec3 Directlight = vec3(0.0);
		#endif

		vec3 ambientMul = exp(-1 * d * waterCoefs);
		vec3 Indirectlight = ambient * ambientMul * YFade * lowlightlevel;

		vec3 light = (Indirectlight + Directlight) * scatterCoef;

		vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs * absorbance;
		absorbance *= exp(-waterCoefs * dd * rayLength);
	}
	inColor += vL;
}
// #endif

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

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////


void main() {
/* RENDERTARGETS:0 */

	float noise_1 = max(1.0 - R2_dither(),0.0015);
	float noise_2 = blueNoise();
	

	vec2 tc = floor(gl_FragCoord.xy)/VL_RENDER_RESOLUTION*texelSize+0.5*texelSize;

	bool iswater = texture2D(colortex7,tc).a > 0.99;

	float z0 = texture2D(depthtex0,tc).x;
	
	#ifdef DISTANT_HORIZONS
		float DH_z0 = texture2D(dhDepthTex,tc).x;
	#else
		float DH_z0 = 0.0;
	#endif
	
	float z = texture2D(depthtex1,tc).x;
	float DH_z = texture2D(dhDepthTex1,tc).x;
	
	vec3 viewPos1 = toScreenSpace_DH(tc/RENDER_SCALE, z, DH_z);
	vec3 viewPos0 = toScreenSpace_DH(tc/RENDER_SCALE, z0, DH_z0);

	vec3 playerPos = normalize(mat3(gbufferModelViewInverse) *  viewPos1);
	// vec3 lightningColor = (lightningEffect / 3) * (max(eyeBrightnessSmooth.y,0)/240.);
	
	
	
	float dirtAmount = Dirt_Amount + 0.01;
	vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
	vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
	vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
	vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

	vec3 directLightColor = lightCol.rgb/80.0;
	vec3 indirectLightColor = averageSkyCol/30.0;
	vec3 indirectLightColor_dynamic = averageSkyCol_Clouds/30.0;

		////////////////////////////////////////////////////////////
		///////////////// IN FRONT OF TRANSLUCENTS /////////////////
		////////////////////////////////////////////////////////////

		#ifdef OVERWORLD_SHADER
			vec4 VolumetricFog = GetVolumetricFog(viewPos0, vec2(noise_1,noise_2), directLightColor, indirectLightColor);
		#endif
		
		#if defined NETHER_SHADER || defined END_SHADER
			vec4 VolumetricFog = GetVolumetricFog(viewPos0, noise_1, noise_2);
		#endif

		gl_FragData[0] = clamp(VolumetricFog, 0.0, 65000.0);

		//////////////////////////////////////////////////////////
		///////////////// BEHIND OF TRANSLUCENTS /////////////////
		//////////////////////////////////////////////////////////

	if (isEyeInWater == 1){

		float estEyeDepth = clamp(eyeBrightnessSmooth.y/240.0,0.,1.0);
		// estEyeDepth = pow(estEyeDepth,3.0) * 32.0;
		estEyeDepth = 0.0;

		// vec3 lightningColor = (lightningEffect / 3) * (max(eyeBrightnessSmooth.y,0)/240.);

		vec3 vl = vec3(0.0);
		waterVolumetrics(vl, vec3(0.0), viewPos0, estEyeDepth, estEyeDepth, length(viewPos0), noise_1, totEpsilon, scatterCoef, indirectLightColor_dynamic, directLightColor , dot(normalize(viewPos0), normalize(sunVec* lightCol.a ) 	));
		
		gl_FragData[0] = clamp(vec4(vl,1.0),0.000001,65000.);

	}
}