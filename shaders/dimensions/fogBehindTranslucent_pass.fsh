#include "/lib/settings.glsl"
// #if defined END_SHADER || defined NETHER_SHADER
	#undef IS_LPV_ENABLED
// #endif
	uniform float nightVision;

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

uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;

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

	#include "/lib/scene_controller.glsl"
	#include "/lib/diffuse_lighting.glsl"

	#define TIMEOFDAYFOG
	#include "/lib/lightning_stuff.glsl"

	#define CLOUDS_INTERSECT_TERRAIN
	// #define CLOUDSHADOWSONLY
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

vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord)%512 , 0) ;
}

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a+ 1.0/1.6180339887 * frameCounter );
}

float interleaved_gradientNoise(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+ 1.0/1.6180339887 * frameCounter);
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

vec4 waterVolumetrics( vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL, float lightleakFix){
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
		sh *= GetCloudShadow(wpos+cameraPosition, WsunVec);
	#endif
	
	float thing = -normalize(dVWorld).y;
	thing = clamp(thing - 0.333,0.0,1.0);
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
					sh *= vec3(shadow2D(shadow, pos).x);
				#endif
			}
		#endif

		vec3 sunAbsorbance = exp(-waterCoefs * estSunDepth * d);
		vec3 ambientAbsorbance = exp(-waterCoefs * (estEndDepth * d + thing));

		vec3 Directlight = lightSource * sh * phase * sunAbsorbance;
		vec3 Indirectlight = ambient * ambientAbsorbance;

		vec3 light = (Indirectlight + Directlight) * scatterCoef;
		
		vec3 volumeCoeff = exp(-waterCoefs * dd * rayLength);
		vL += (light - light * volumeCoeff) / waterCoefs * absorbance;
		absorbance *= volumeCoeff;
	}
	
    return vec4(vL, dot(absorbance,vec3(0.335)));
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

	float alpha = texture2D(colortex7,tc).a ;
	float blendedAlpha = texture2D(colortex2, tc).a;


	bool iswater = alpha > 0.99;
	//////////////////////////////////////////////////////////
	///////////////// BEHIND OF TRANSLUCENTS /////////////////
	//////////////////////////////////////////////////////////

	if(blendedAlpha > 0.0 || iswater){
		
		float noise_1 = R2_dither();
		float noise_2 = blueNoise();

		float z0 = texelFetch2D(depthtex0, ivec2((floor(gl_FragCoord.xy - 0.5)/VL_RENDER_RESOLUTION*texelSize)/texelSize), 0 ).x;

		#ifdef DISTANT_HORIZONS
			float DH_z0 = texelFetch2D(dhDepthTex, ivec2((floor(gl_FragCoord.xy - 0.5)/VL_RENDER_RESOLUTION*texelSize)/texelSize), 0 ).x;//texture2D(dhDepthTex,tc).x;
		#else
			float DH_z0 = 0.0;
		#endif

		float z = texelFetch2D(depthtex1, ivec2((floor(gl_FragCoord.xy - 0.5)/VL_RENDER_RESOLUTION*texelSize)/texelSize), 0 ).x;

		#ifdef DISTANT_HORIZONS
			// float DH_z = texture2D(dhDepthTex1,tc).x;
			float DH_z = texelFetch2D(dhDepthTex1, ivec2((floor(gl_FragCoord.xy - 0.5)/VL_RENDER_RESOLUTION*texelSize)/texelSize), 0 ).x;//texture2D(dhDepthTex,tc).x;
		#else
			float DH_z = 0.0;
		#endif

		// vec3 lightningColor = (lightningEffect / 3) * (max(eyeBrightnessSmooth.y,0)/240.);

		float dirtAmount = Dirt_Amount ;
    	// float dirtAmount = Dirt_Amount + 0.01;
		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);//dirtEpsilon * dirtAmount + waterEpsilon;
		vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

		#ifdef BIOME_TINT_WATER
			// yoink the biome tint written in this buffer for water only.
			if(iswater){
				vec2 data = texelFetch2D(colortex11,ivec2(tc/texelSize),0).gb;
				vec3 wateralbedo = vec3(decodeVec2(data.x),decodeVec2(data.y).r);
				scatterCoef = dirtAmount * normalize(wateralbedo.rgb+1e-7) / 3.14;
			}
		#endif
		
		vec3 directLightColor = lightCol.rgb / 2400.0;
		vec3 indirectLightColor = averageSkyCol / 1200.0;
		vec3 indirectLightColor_dynamic = averageSkyCol_Clouds / 1200.0;


		vec3 viewPos1 = toScreenSpace_DH(tc/RENDER_SCALE, z, DH_z);
		vec3 viewPos0 = toScreenSpace_DH(tc/RENDER_SCALE, z0, DH_z0);

		vec3 playerPos = mat3(gbufferModelViewInverse) *  viewPos1;
		vec3 playerPos0 = mat3(gbufferModelViewInverse) *  viewPos0;

		#ifdef OVERWORLD_SHADER
			vec2 lightmap = decodeVec2(texelFetch2D(colortex14,ivec2(tc/texelSize),0).x);
			
			#ifdef DISTANT_HORIZONS
				if(z >= 1.0) lightmap.y = 0.99;
			#endif
		#else
			vec2 lightmap = decodeVec2(texelFetch2D(colortex14,ivec2(tc/texelSize),0).a);
			lightmap.y = 1.0;
		#endif

		float Vdiff = distance(viewPos1, viewPos0);
		float estimatedDepth = Vdiff * abs(normalize(playerPos).y);
		float estimatedSunDepth = Vdiff / abs(WsunVec.y); //assuming water plane
		
	 	indirectLightColor_dynamic *= ambient_brightness * lightmap.y*lightmap.y;

		indirectLightColor_dynamic += MIN_LIGHT_AMOUNT * 0.02 * 0.2 + nightVision*0.02;

		indirectLightColor_dynamic += vec3(TORCH_R,TORCH_G,TORCH_B)	* pow(1.0-sqrt(1.0-clamp(lightmap.x,0.0,1.0)),2.0)  * TORCH_AMOUNT;

		vec4 finalVolumetrics = vec4(0.0,0.0,0.0,1.0);
		float cloudPlaneDistance = 0.0;

		#ifdef OVERWORLD_SHADER
			vec4 VolumetricClouds = GetVolumetricClouds(viewPos1, vec2(noise_1, noise_2), WsunVec, directLightColor, indirectLightColor, cloudPlaneDistance);

			float atmosphereAlpha = 1.0;
			vec4 VolumetricFog = GetVolumetricFog(viewPos1, WsunVec,  vec2(noise_1, noise_2), directLightColor, indirectLightColor, indirectLightColor_dynamic, atmosphereAlpha, VolumetricClouds.rgb,cloudPlaneDistance);
			
			finalVolumetrics.rgb += VolumetricClouds.rgb;
			finalVolumetrics.a *= VolumetricClouds.a;
		#endif

		#if defined NETHER_SHADER || defined END_SHADER
			vec4 VolumetricFog = GetVolumetricFog(viewPos1, noise_1, noise_2);
		#endif

		finalVolumetrics.rgb = finalVolumetrics.rgb * VolumetricFog.a + VolumetricFog.rgb;
		finalVolumetrics.a *= VolumetricFog.a;
		
		vec4 underwaterVlFog = vec4(0,0,0,1);
		
		float lightleakfix = clamp(lightmap.y + (1-caveDetection),0.0,1.0);

		if(iswater && isEyeInWater != 1) {
			vec4 underWaterFog = waterVolumetrics(viewPos0, viewPos1, estimatedDepth, estimatedSunDepth, Vdiff, noise_1, totEpsilon, scatterCoef, indirectLightColor_dynamic, directLightColor, dot(normalize(viewPos1), normalize(sunVec*lightCol.a)) ,lightleakfix); 
			finalVolumetrics.rgb = finalVolumetrics.rgb * underWaterFog.a*underWaterFog.a + underWaterFog.rgb;
			finalVolumetrics.a *= underWaterFog.a;
		}

		gl_FragData[0] = clamp(finalVolumetrics, 0.0, 65000.0);
	}
}