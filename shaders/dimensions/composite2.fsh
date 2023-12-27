#include "/lib/settings.glsl"

flat varying vec4 lightCol;
flat varying vec3 averageSkyCol;
// flat varying vec3 averageSkyCol_Clouds;

uniform sampler2D noisetex;
uniform sampler2D depthtex0;

uniform sampler2D colortex2;
uniform sampler2D colortex3;
// uniform sampler2D colortex4;
uniform sampler2D colortex6;

flat varying vec3 WsunVec;
uniform vec3 sunVec;
uniform float sunElevation;
// uniform float far;

uniform int frameCounter;
uniform float frameTimeCounter;

varying vec2 texcoord;
uniform vec2 texelSize;
flat varying vec2 TAA_Offset;

uniform int isEyeInWater;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;

uniform float eyeAltitude;
#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/projections.glsl"
#include "/lib/res_params.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/Shadow_Params.glsl"

#ifdef OVERWORLD_SHADER
	
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;

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

float interleaved_gradientNoise(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+ 1.0/1.6180339887 * frameCounter);
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a+ 1.0/1.6180339887 * frameCounter );
}
float R2_dither(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
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

#ifdef OVERWORLD_SHADER
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
	// vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;

	// float phase = (phaseg(VdotL,0.6) + phaseg(VdotL,0.8)) * 0.5;
	float phase = fogPhase(VdotL) ;
	
	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);
	float expFactor = 11.0;

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

		sh *= GetCloudShadow_VLFOG(progressW, WsunVec);


		vec3 sunMul = exp(-max((estSunDepth - dY * d) ,0.0)/abs(refractedSunVec.y) * waterCoefs);
		vec3 ambientMul = exp(-max(estEyeDepth - dY * d,0.0) * waterCoefs) * 2.0 ;

		float np3_Y = normalize(mat3(gbufferModelViewInverse) * rayEnd).y;
		float ambfogfade =  clamp(exp(np3_Y*1.5 - 1.5),0.0,1.0) ;

		float sunCaustics =  clamp(pow(waterCaustics(progressW, WsunVec)+1,5) * 2.0, phase*0.8+0.2, 1.0);


		// make it such that the volume is brighter farther away from the camera.
		float bubbleOfClearness =  max(pow(length(d*dVWorld)/16,5)*100.0,0.0) + 1;
		float bubbleOfClearness2 = max(pow(length(d*dVWorld)/24,5)*100.0,0.0) + 1;

		vec3 Directlight = (lightSource * sunCaustics * phase * (sunMul+0.5)) * sh * pow(abs(WsunVec.y),2) * bubbleOfClearness; 
		vec3 Indirectlight = max(ambient * ambientMul, vec3(0.6,0.6,1.0) * exp(-waterCoefs) * bubbleOfClearness2) * ambfogfade ;

		vec3 light = (Directlight + Indirectlight) * scatterCoef ;

		vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs * absorbance;
		absorbance *= exp(-dd * rayLength * waterCoefs);
	}
	inColor += vL;
}
#endif
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord)%512 , 0) ;
}
vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}

void main() {
/* DRAWBUFFERS:0 */

	// vec2 tc = floor(gl_FragCoord.xy)/VL_RENDER_RESOLUTION*texelSize+0.5*texelSize;
	vec2 tc = floor(gl_FragCoord.xy)/VL_RENDER_RESOLUTION*texelSize+0.5*texelSize;
	float z = texture2D(depthtex0,tc).x;
	vec3 viewPos = toScreenSpace(vec3(tc/RENDER_SCALE,z));

	float noise_1 = R2_dither();
	float noise_2 = blueNoise();


	if (isEyeInWater == 0){
		
		#ifdef OVERWORLD_SHADER
			vec4 VolumetricFog = GetVolumetricFog(viewPos, vec2(noise_1,noise_2), lightCol.rgb/80.0, averageSkyCol/30.0);
		#endif
		
		#if defined NETHER_SHADER || defined END_SHADER
			vec4 VolumetricFog = GetVolumetricFog(viewPos, noise_1, noise_2);
		#endif

		// VolumetricFog = vec4(0,0,0,1);

		gl_FragData[0] = clamp(VolumetricFog, 0.0, 65000.0);
	} 
	
	if (isEyeInWater == 1){

		float dirtAmount = Dirt_Amount;
		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
		vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

		#ifdef OVERWORLD_SHADER

			float estEyeDepth = 1.0-clamp(eyeBrightnessSmooth.y/240.0,0.,1.0);
			estEyeDepth = pow(estEyeDepth,3.0) * 32.0;

			vec3 lightColVol = lightCol.rgb / 80.;

			vec3 lightningColor = (lightningEffect / 3) * (max(eyeBrightnessSmooth.y,0)/240.);
			vec3 ambientColVol = (averageSkyCol/30.0);

			vec3 vl = vec3(0.0);
			waterVolumetrics(vl, vec3(0.0), viewPos, estEyeDepth, estEyeDepth, length(viewPos), noise_1, totEpsilon, scatterCoef, ambientColVol, lightColVol*(1.0-pow(1.0-sunElevation*lightCol.a,5.0)) , dot(normalize(viewPos), normalize(sunVec* lightCol.a ) 	));
			gl_FragData[0] = clamp(vec4(vl,1.0),0.000001,65000.);
		#else
			vec3 fragpos0 = toScreenSpace(vec3(texcoord - TAA_Offset*texelSize*0.5,z));
			vec3 ambientColVol =  max(vec3(1.0,0.5,1.0) * 0.6, vec3(0.2,0.4,1.0) * MIN_LIGHT_AMOUNT*0.01);
			gl_FragData[0].a = 1;
			waterVolumetrics_notoverworld(gl_FragData[0].rgb, fragpos0, viewPos, 1.0, 1.0, 1.0, blueNoise(), totEpsilon, scatterCoef, ambientColVol);
		#endif
	}
}