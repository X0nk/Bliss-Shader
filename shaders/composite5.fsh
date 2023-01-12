#version 120
//Volumetric fog rendering
#extension GL_EXT_gpu_shader4 : enable
#define CLOUDS_SHADOWS
#define VL_CLOUDS_SHADOWS // Casts shadows from clouds on VL (slow)
#define CLOUDS_SHADOWS_STRENGTH 1.0 //[0.1 0.125 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.9 1.0]
#define VL_SAMPLES 8 //[4 6 8 10 12 14 16 20 24 30 40 50]
#define Ambient_Mult 1.0 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.5 2.0 3.0 4.0 5.0 6.0 10.0]
#define SEA_LEVEL 70 //[0 10 20 30 40 50 60 70 80 90 100 110 120 130 150 170 190]	//The volumetric light uses an altitude-based fog density, this is where fog density is the highest, adjust this value according to your world.
#define ATMOSPHERIC_DENSITY 1.0 //[0.0 0.5 1.0 1.5 2.0 2.5 3.0 4.0 5.0 7.5 10.0 12.5 15.0 20.]
#define fog_mieg1 0.40 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define fog_mieg2 0.10 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define fog_coefficientRayleighR 5.8 //[0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]
#define fog_coefficientRayleighG 1.35 //[0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]
#define fog_coefficientRayleighB 3.31 //[0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]

#define fog_coefficientMieR 3.0 //[0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]
#define fog_coefficientMieG 3.0 //[0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]
#define fog_coefficientMieB 3.0 //[0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]
 
#define Cloudy_Fog_Density 5.0 //[0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]
#define Uniform_Fog_Density 1.0 //[0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]

#define uniformfog_fade 10 // does not change rain or cave fog [5 10 20 30 40 50 60 70 80  90 100]
#define cloudyfog_fade 10 //  does not change rain or cave fog [5 10 20 30 40 50 60 70 80  90 100]

#define RainFog_amount  5 // [0 1 2 3 4 5 6 7 8 9  10 15 20 25]
#define CaveFog_amount  5 // [0 1 2 3 4 5 6 7 8 9  10 15 20 25]
#define cloudray_amount 0.2 // rain boost this [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

#define UniformFog_amount 1.0 // [0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0 10.0 20.0 30.0 50.0 100.0 150.0 200.0]
#define CloudyFog_amount 1.0 // [0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0 10 20 30 40 50 100 500 10000]
#define TimeOfDayFog_multiplier 1.0 // Influence of time of day on fog amount [0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0] 
#define Haze_amount 1.0 // [0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0]
// #define fog_selfShadowing // make the fog cast a shadow onto itself



flat varying vec4 lightCol;
flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;
flat varying vec3 avgAmbient;
flat varying float tempOffsets;
flat varying float fogAmount;
flat varying float VFAmount;
flat varying float FogSchedule;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2DShadow shadow;
flat varying vec3 refractedSunVec;
flat varying vec3 WsunVec;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
// uniform sampler2D colortex4;

uniform vec3 sunVec;
uniform float far;
uniform float near;
uniform int frameCounter;
uniform float rainStrength;
uniform float sunElevation;
uniform ivec2 eyeBrightnessSmooth;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform vec2 texelSize;


#include "lib/waterOptions.glsl"
#include "lib/Shadow_Params.glsl"
#include "lib/color_transforms.glsl"
#include "lib/color_dither.glsl"
#include "lib/projections.glsl"
#include "lib/sky_gradient.glsl"
#include "/lib/res_params.glsl"
// #include "lib/biome_specifics.glsl"

#define TIMEOFDAYFOG
#include "lib/volumetricClouds.glsl"


float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter) ;
}
float R2_dither2(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x *(1- gl_FragCoord.x) + alpha.y * (1-gl_FragCoord.y) + 1.0/1.6180339887 * frameCounter) ;
}
float interleaved_gradientNoise(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	vec2 coord = vec2(alpha.x * gl_FragCoord.x,alpha.y * gl_FragCoord.y)+ 1.0/1.6180339887 * frameCounter;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}

float phaseRayleigh(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) /acos(-1.0);
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

float GetCloudShadow(vec3 eyePlayerPos){
	vec3 worldPos = (eyePlayerPos + cameraPosition) - Cloud_Height;
	vec3 cloudPos = worldPos*Cloud_Size + WsunVec/abs(WsunVec.y) * ((3250 - 3250*0.35) - worldPos.y*Cloud_Size) ;
	float shadow = getCloudDensity(cloudPos, 1);

	shadow = clamp(exp(-shadow*5),0.0,1.0);

	return shadow ;
}

float densityAtPosFog(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	f = (f*f) * (3.-2.*f);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	vec2 xy = texture2D(noisetex, coord).yx;
	return mix(xy.r,xy.g, f.y);
}

float fog_densities_atmospheric = 24 * Haze_amount; // this is seperate from the cloudy and uniform fog.

float cloudVol(in vec3 pos){

	vec3 samplePos = pos*vec3(1.0,1./24.,1.0);
	vec3 samplePos2 = pos*vec3(1.0,1./48.,1.0);


	float mult = exp( -max((pos.y - SEA_LEVEL) / 35.,0.0));

	float fog_shape = 1-densityAtPosFog(samplePos * 24.0);
	float fog_eroded = 1-densityAtPosFog(	samplePos2 * 200.0);

	float CloudyFog = max(	(fog_shape*2.0 - fog_eroded*0.5) - 1.2, 0.0) * mult;
	float UniformFog = exp2( -max((pos.y - SEA_LEVEL) / 25.,0.0));
	
	float RainFog = max(fog_shape*10. - 7.,0.5) * exp2( -max((pos.y - SEA_LEVEL) / 25.,0.0)) * 5. * rainStrength;
	
	TimeOfDayFog(UniformFog, CloudyFog);

	return CloudyFog + UniformFog + RainFog;
}

mat2x3 getVolumetricRays(
	float dither,
	vec3 fragpos,
	float dither2
){
	//project pixel position into projected shadowmap space
	vec3 wpos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
	vec3 fragposition = mat3(shadowModelView) * wpos + shadowModelView[3].xyz;
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;

	//project view origin into projected shadowmap space
	vec3 start = toShadowSpaceProjected(vec3(0.));

	//rayvector into projected shadow map space
	//we can use a projected vector because its orthographic projection
	//however we still have to send it to curved shadow map space every step
	vec3 dV = fragposition-start;
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	float maxLength = min(length(dVWorld),far*5)/length(dVWorld);
	dV *= maxLength;
	dVWorld *= maxLength;

	//apply dither
	vec3 progress = start.xyz;
	vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;

	vec3 vL = vec3(0.);

	float SdotV = dot(sunVec,normalize(fragpos))*lightCol.a;
	float dL = length(dVWorld);

	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
	float mie = phaseg(SdotV,0.7)*5.0 + 1.0;
	float rayL = phaseRayleigh(SdotV);

	// Makes fog more white idk how to simulate it correctly
	vec3 sunColor = lightCol.rgb / 127.0;
	vec3 skyCol0 = (ambientUp / 150. * 5.); // * max(abs(WsunVec.y)/150.0,0.);

	vec3 rC = vec3(fog_coefficientRayleighR*1e-6, fog_coefficientRayleighG*1e-5, fog_coefficientRayleighB*1e-5);
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);

	float mu = 1.0;
	float muS = mu;
	vec3 absorbance = vec3(1.0);
	float expFactor = 11.0;
	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;

	float cloudShadow = 1.0;

	for (int i=0;i<VL_SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither)/float(VL_SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(VL_SAMPLES)) * log(expFactor) / float(VL_SAMPLES)/(expFactor-1.0);
		progress = start.xyz + d*dV;
		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
		//project into biased shadowmap space
		float distortFactor = calcDistort(progress.xy);
		vec3 pos = vec3(progress.xy*distortFactor, progress.z);
		float densityVol = cloudVol(progressW);
		float sh = 1.0;
		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
			sh = shadow2D( shadow, pos).x;
		}
		#ifdef VOLUMETRIC_CLOUDS
		#ifdef CLOUDS_SHADOWS
		#ifdef VL_CLOUDS_SHADOWS
			float max_height = clamp(400.0 - progressW.y, 0.0,1.0); // so it doesnt go beyond the height of the clouds
			vec3 campos = (progressW)-319;
			// get cloud position
			vec3 cloudPos = campos*Cloud_Size + WsunVec/abs(WsunVec.y) * (2250 - campos.y*Cloud_Size);
			// get the cloud density and apply it
			cloudShadow = getCloudDensity(cloudPos, 1);
			cloudShadow = exp(-cloudShadow*cloudDensity*200);
			cloudShadow *= max_height;
			// cloudShadow *= 1000; //debug 
		#endif
		#endif
		#endif

		//Water droplets(fog)
		float density = densityVol*ATMOSPHERIC_DENSITY*mu*300.;

		//Just air
		vec2 airCoef = exp(-max(progressW.y-SEA_LEVEL,0.0)/vec2(8.0e3, 1.2e3)*vec2(6.,7.0)) * 24;

		//Pbr for air, yolo mix between mie and rayleigh for water droplets
		vec3 rL = rC*airCoef.x;
		vec3 m = (airCoef.y+density)*mC;


		vec3 DirectLight =  (sunColor*sh*cloudShadow) * (rayL*rL+m*mie);
		vec3 AmbientLight =  skyCol0 * m;
		vec3 AtmosphericFog = skyCol0 * (rL+m)  ;

		// extra fog effects
		vec3 rainRays =   (sunColor*sh*cloudShadow) * (rayL*phaseg(SdotV,0.6)) * clamp(pow(WsunVec.y,5)*2,0.0,1) * rainStrength;
		vec3 CaveRays = (sunColor*sh*cloudShadow)  * phaseg(SdotV,0.7) * 0.001 * (1.0 - max(eyeBrightnessSmooth.y,0)/240.);

		vec3 vL0 = ( DirectLight + AmbientLight + AtmosphericFog + rainRays) * max(eyeBrightnessSmooth.y,0)/240. + CaveRays ;
		
		#ifdef Biome_specific_environment
			BiomeFogColor(vL0); // ?????
		#endif

		vL += (vL0 - vL0 * exp(-(rL+m)*dd*dL)) / ((rL+m)+0.00000001)*absorbance;
		absorbance *= clamp(exp(-(rL+m)*dd*dL),0.0,1.0);

	}
	return mat2x3(vL,absorbance);
}

float waterCaustics(vec3 wPos, vec3 lightSource) { // water waves

	vec2 pos = wPos.xz + (lightSource.xz/lightSource.y*wPos.y);
	if(isEyeInWater==1) pos = wPos.xz - (lightSource.xz/lightSource.y*wPos.y); // fix the fucky
	vec2 movement = vec2(-0.035*frameTimeCounter);
	float caustic = 0.0;
	float weightSum = 0.0;
	float radiance =  2.39996;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

	const vec2 wave_size[4] = vec2[](
		vec2(64.),
		vec2(32.,16.),
		vec2(16.,32.),
		vec2(48.)
	);

	for (int i = 0; i < 4; i++){
		pos = rotationMatrix * pos;

		vec2 speed = movement;
		float waveStrength = 1.0;
		
		if( i == 0) {
			speed *= 0.15;
			waveStrength = 2.0;
		}

		float small_wave = texture2D(noisetex, pos / wave_size[i] + speed ).b * waveStrength;

		caustic +=  max( 1.0-sin( 1.0-pow(	0.5+sin( small_wave*3.0	)*0.5,	25.0)	),	0);

		weightSum -= exp2(caustic*0.1);
	}
	return caustic / weightSum;
}
vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}
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
		vec3 absorbance = vec3(1.0);
		vec3 vL = vec3(0.0);
		float phase =  2*mix(phaseg(VdotL, 0.4),phaseg(VdotL, 0.8),0.5);
		float expFactor = 11.0;
		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;
		vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;
		float cloudShadow = 1;
		for (int i=0;i<spCount;i++) {
			float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);		// exponential step position (0-1)
			float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);	//step length (derivative)
			vec3 spPos = start.xyz + dV*d;
			progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
			//project into biased shadowmap space
			float distortFactor = calcDistort(spPos.xy);
			vec3 pos = vec3(spPos.xy*distortFactor, spPos.z);
			float sh = 1.0;
			if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
				pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
				sh =  shadow2D( shadow, pos).x;
			}
			
			#ifdef VOLUMETRIC_CLOUDS
			#ifdef CLOUDS_SHADOWS
				vec3 campos = (progressW)-319;
				// get cloud position
				vec3 cloudPos = campos*Cloud_Size + WsunVec/abs(WsunVec.y) * (2250 - campos.y*Cloud_Size);
				// get the cloud density and apply it
				float cloudShadow = getCloudDensity(cloudPos, 1);
				// cloudShadow = exp(-cloudShadow*sqrt(cloudDensity)*50);
				cloudShadow = clamp(exp(-cloudShadow*6),0.0,1.0);
				sh *= cloudShadow;
			#endif
			#endif

			vec3 p3 = mat3(gbufferModelViewInverse) * rayEnd;
			vec3 np3 = normVec(p3);
			float ambfogfade =  clamp(exp(np3.y*1.5 - 1.5),0.0,1.0) ;

			vec3 ambientMul = exp(-max(estEyeDepth - dY * d,0.0) * waterCoefs) + ambfogfade*0.5 ;
			vec3 sunMul = exp(-max((estEyeDepth - dY * d) ,0.0)/abs(refractedSunVec.y) * waterCoefs)*cloudShadow;
			
			float sunCaustics = waterCaustics(progressW, WsunVec);
			sunCaustics =  max(pow(sunCaustics*3,2),0.5);

			vec3 light = (sh * lightSource * phase * sunCaustics * sunMul  +  (ambient*ambientMul))*scatterCoef;
			vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs *absorbance;
			absorbance *= exp(-dd * rayLength * waterCoefs);
		}
		inColor += vL;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
/* DRAWBUFFERS:0 */
	float lightleakfix = max(eyeBrightnessSmooth.y,0)/240.;

	if (isEyeInWater == 0){

		vec2 tc = floor(gl_FragCoord.xy)/VL_RENDER_RESOLUTION*texelSize+0.5*texelSize;
		float z = texture2D(depthtex0,tc).x;
		vec3 fragpos = toScreenSpace(vec3(tc/RENDER_SCALE,z));
		float noise = blueNoise();
		mat2x3 vl = getVolumetricRays(noise,fragpos,blueNoise());
		float absorbance = dot(vl[1],vec3(0.22,0.71,0.07));
		gl_FragData[0] = clamp(vec4(vl[0],absorbance),0.000001,65000.);

	} else {

		float dirtAmount = Dirt_Amount;
		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
		vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B);
		vec2 tc = floor(gl_FragCoord.xy)/VL_RENDER_RESOLUTION*texelSize+0.5*texelSize;
		float z = texture2D(depthtex0,tc).x;
		vec3 fragpos = toScreenSpace(vec3(tc/RENDER_SCALE,z));
		float noise = R2_dither();
		vec3 vl = vec3(0.0);
		float estEyeDepth = clamp((14.0-eyeBrightnessSmooth.y/255.0*16.0)/14.0,0.,1.0);
		estEyeDepth *= estEyeDepth*estEyeDepth*34.0;
		#ifndef lightMapDepthEstimation
			estEyeDepth = max(Water_Top_Layer - cameraPosition.y,0.0);
		#endif

		waterVolumetrics(vl, vec3(0.0), fragpos, estEyeDepth, estEyeDepth, length(fragpos), noise, totEpsilon, scatterCoef, (ambientUp*8./150./3.*0.5) , lightCol.rgb*8./150./3.0*(1.0-pow(1.0-sunElevation*lightCol.a,5.0)), dot(normalize(fragpos), normalize(sunVec)	));
		gl_FragData[0] = clamp(vec4(vl,1.0),0.000001,65000.);
	}
}
