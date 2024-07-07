#include "/lib/settings.glsl"
// #if defined END_SHADER || defined NETHER_SHADER
	#undef IS_LPV_ENABLED
// #endif
#ifndef OVERWORLD_SHADER
	uniform float nightVision;
#endif

flat varying vec4 lightCol;
flat varying vec3 averageSkyCol;
flat varying vec3 averageSkyCol_Clouds;
flat varying float exposure;

// uniform int dhRenderDistance;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
#endif

uniform sampler2D colortex2;
uniform sampler2D colortex3;
// uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex11;
uniform sampler2D colortex14;

flat varying vec3 WsunVec;
uniform vec3 sunVec;
uniform float sunElevation;

// uniform float far;
uniform float dhFarPlane;
uniform float dhNearPlane;
uniform float near;

uniform int frameCounter;
uniform float frameTimeCounter;

// varying vec2 texcoord;
uniform vec2 texelSize;
// flat varying vec2 TAA_Offset;

uniform int isEyeInWater;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;
uniform float eyeAltitude;
uniform float caveDetection;

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
    return (2.0 * near) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
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

	#define CLOUDS_INTERSECT_TERRAIN
	// #define CLOUDSHADOWSONLY
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

#include "/lib/diffuse_lighting.glsl"

#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)

float interleaved_gradientNoise(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+ 1.0/1.6180339887 * frameCounter);
}
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

vec4 waterVolumetrics_test( vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
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

	vec3 newabsorbance = exp(-rayLength * waterCoefs);	// No need to take the integrated value
    #ifdef OVERWORLD_SHADER
		float phase = fogPhase(VdotL) * 5.0;
	#else
		float phase = 1.0;
	#endif
	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);
	
	ambient = max(ambient * (normalize(wpos).y*0.3+0.7),0.0);

	float expFactor = 11.0;
	for (int i=0;i<spCount;i++) {
		float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);

		vec3 progressW = start.xyz+cameraPosition+dVWorld;

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
				sh *= GetCloudShadow_VLFOG(progressW,WsunVec);
			#endif
		#endif

		vec3 sunMul = exp(-estSunDepth * d * waterCoefs * 1.1);
		vec3 ambientMul = exp(-estEndDepth * d * waterCoefs );

		vec3 Directlight = ((lightSource * sh) * phase * sunMul) ;
		vec3 Indirectlight = max(ambient * ambientMul, vec3(0.01,0.2,0.4) * ambientMul * MIN_LIGHT_AMOUNT * 0.03) ;

		vec3 light = (Indirectlight + Directlight) * scatterCoef;

		vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs * absorbance;
		absorbance *= exp(-waterCoefs * dd * rayLength);
	}
	// inColor += vL;
    return vec4( vL, dot(newabsorbance,vec3(0.335)));
}
vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////


void main() {
/* RENDERTARGETS:13 */

	gl_FragData[0] = vec4(0,0,0,1);

	vec2 tc = floor(gl_FragCoord.xy)/VL_RENDER_RESOLUTION*texelSize+0.5*texelSize;

	bool iswater = texture2D(colortex7,tc).a > 0.99;

	//////////////////////////////////////////////////////////
	///////////////// BEHIND OF TRANSLUCENTS /////////////////
	//////////////////////////////////////////////////////////

	if(texture2D(colortex2, tc).a > 0.0 || iswater){
		
		float noise_1 = R2_dither();
		float noise_2 = blueNoise();

		float z0 = texture2D(depthtex0,tc).x;

		#ifdef DISTANT_HORIZONS
			float DH_z0 = texture2D(dhDepthTex,tc).x;
		#else
			float DH_z0 = 0.0;
		#endif

		float z = texture2D(depthtex1,tc).x;

		#ifdef DISTANT_HORIZONS
			float DH_z = texture2D(dhDepthTex1,tc).x;
		#else
			float DH_z = 0.0;
		#endif

		// vec3 lightningColor = (lightningEffect / 3) * (max(eyeBrightnessSmooth.y,0)/240.);

		float dirtAmount = Dirt_Amount + 0.1;
    	// float dirtAmount = Dirt_Amount + 0.01;
		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
		vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

		#ifdef BIOME_TINT_WATER
			// yoink the biome tint written in this buffer for water only.
			if(iswater){
				vec2 translucentdata = texture2D(colortex11,tc).gb;
				vec3 wateralbedo = normalize(vec3(decodeVec2(translucentdata.x),decodeVec2(translucentdata.y).x)+0.00001) * 0.5 + 0.5;
				scatterCoef = dirtAmount * wateralbedo / 3.14;
			}
		#endif

		vec3 directLightColor = lightCol.rgb/80.0;
		vec3 indirectLightColor = averageSkyCol/30.0;
		vec3 indirectLightColor_dynamic = averageSkyCol_Clouds/30.0;

		vec3 viewPos1 = toScreenSpace_DH(tc/RENDER_SCALE, z, DH_z);
		vec3 viewPos0 = toScreenSpace_DH(tc/RENDER_SCALE, z0, DH_z0);
		vec3 playerPos = normalize(mat3(gbufferModelViewInverse) *  viewPos1);

		#ifdef OVERWORLD_SHADER
			// vec2 lightmap = decodeVec2(texture2D(colortex14, tc).a);
			
			vec2 lightmap = vec2(0.0,texture2D(colortex14, tc).a);
			
			#ifdef DISTANT_HORIZONS
				if(z >= 1.0) lightmap.y = 0.99;
			#endif
		#else
			vec2 lightmap = decodeVec2(texture2D(colortex14, tc).a);
			lightmap.y = 1.0;
		#endif

		float Vdiff = distance(viewPos1, viewPos0) * 2.0;
		float VdotU = playerPos.y;
		float estimatedDepth = Vdiff * abs(VdotU) ;	//assuming water plane
		float estimatedSunDepth = estimatedDepth / abs(WsunVec.y); //assuming water plane

	 	indirectLightColor_dynamic *= ambient_brightness * pow(1.0-pow(1.0-lightmap.y,0.5),3.0)	;
		// float TorchBrightness_autoAdjust = mix(1.0, 30.0,  clamp(exp(-10.0*exposure),0.0,1.0)) ;
		// indirectLightColor_dynamic += vec3(TORCH_R,TORCH_G,TORCH_B)	* TorchBrightness_autoAdjust * pow(1.0-sqrt(1.0-clamp(lightmap.x,0.0,1.0)),2.0) * 2.0;

		vec3 cloudDepth = vec3(0.0);
		vec4 VolumetricFog2 = vec4(0,0,0,1);
		vec4 VolumetricClouds = vec4(0,0,0,1);
		
		#ifdef OVERWORLD_SHADER
			if(!iswater){

				#if defined CLOUDS_INTERSECT_TERRAIN
					VolumetricClouds = renderClouds(viewPos1, vec2(noise_1,noise_2), directLightColor, indirectLightColor, cloudDepth);
				#endif

				float atmosphereAlpha = 1.0;
				VolumetricFog2 = GetVolumetricFog(viewPos1, vec2(noise_1, noise_2), directLightColor, indirectLightColor,indirectLightColor_dynamic, atmosphereAlpha);
				VolumetricClouds.a *= atmosphereAlpha;

				#if defined CLOUDS_INTERSECT_TERRAIN
					VolumetricFog2 = vec4(VolumetricClouds.rgb * VolumetricFog2.a * atmosphereAlpha  + VolumetricFog2.rgb, VolumetricFog2.a*VolumetricClouds.a);
				#endif
			}
		#endif
		
		vec4 underwaterVlFog = vec4(0,0,0,1);
		if(iswater) underwaterVlFog = waterVolumetrics_test(viewPos0, viewPos1, estimatedDepth, estimatedSunDepth, Vdiff, noise_1, totEpsilon, scatterCoef, indirectLightColor_dynamic, directLightColor* (1.0-caveDetection), dot(normalize(viewPos1), normalize(sunVec*lightCol.a)) );		
		
		vec4 fogFinal = vec4(underwaterVlFog.rgb * VolumetricFog2.a + VolumetricFog2.rgb, VolumetricFog2.a * underwaterVlFog.a);

		gl_FragData[0] = clamp(fogFinal, 0.0, 65000.0);
	}
}