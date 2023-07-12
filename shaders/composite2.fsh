#version 120
//Volumetric fog rendering
//#extension GL_EXT_gpu_shader4 : disable

#include "/lib/settings.glsl"

flat varying vec4 lightCol;
flat varying vec3 sunColor;
flat varying vec3 moonColor;

flat varying vec3 averageSkyCol_Clouds;
flat varying vec3 averageSkyCol;

flat varying float tempOffsets;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2DShadow shadow;
flat varying vec3 refractedSunVec;
flat varying vec3 WsunVec;

// uniform sampler2D colortex1;
// uniform sampler2D colortex3;
// // uniform sampler2D colortex0;
// uniform sampler2D colortex7;
// uniform sampler2D colortex13;
// uniform sampler2D colortex4;

uniform vec3 sunVec;
uniform float far;
uniform float near;
uniform int frameCounter;
uniform float aspectRatio;
uniform float rainStrength;
uniform float sunElevation;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform vec2 texelSize;


// uniform int worldTime; 

#include "/lib/Shadow_Params.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/projections.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/res_params.glsl"


#define TIMEOFDAYFOG
#include "/lib/volumetricClouds.glsl"
#include "/lib/bokeh.glsl"


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

// vec3 normVec (vec3 vec){
// 	return vec*inversesqrt(dot(vec,vec));
// }

#include "/lib/volumetricFog.glsl"

void waterVolumetrics(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEyeDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
	int spCount = 8;
	

	vec3 start = toShadowSpaceProjected(rayStart);
	vec3 end = toShadowSpaceProjected(rayEnd);
	vec3 dV = (end-start);



	//limit ray length at 32 blocks for performance and reducing integration error
	//you can't see above this anyway
	float maxZ = min(rayLength,48.0)/(1e-8+rayLength);
	dV *= maxZ;
	vec3 dVWorld = mat3(gbufferModelViewInverse) * (rayEnd - rayStart) * maxZ;
	rayLength *= maxZ;
	float dY = normalize(mat3(gbufferModelViewInverse) * rayEnd).y * rayLength;

		// dVWorld *= maxZ


	vec3 progressW = (gbufferModelViewInverse[3].xyz+cameraPosition);
	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;

	// vec3 wpos = mat3(gbufferModelViewInverse) * rayStart  + gbufferModelViewInverse[3].xyz;
	// vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);

	float phase = phaseg(VdotL,0.5) * 1.5 + 0.1;
	lightSource *= clamp(abs(WsunVec.y)*5,0.,1.);

	float cloudShadow = 1;
	float expFactor = 11.0;
	for (int i=0;i<spCount;i++) {
		float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);		// exponential step position (0-1)
		float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);	//step length (derivative)
		vec3 spPos = start.xyz + dV*d;

		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

		// vec3 progressW = start.xyz+cameraPosition+dVWorld;

		//project into biased shadowmap space
		float distortFactor = calcDistort(spPos.xy);
		vec3 pos = vec3(spPos.xy*distortFactor, spPos.z);
		float sh = 1.0;
		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
			sh =  shadow2D( shadow, pos).x;
		}

		// #ifdef VL_CLOUDS_SHADOWS
		// 	sh *= GetCloudShadow_VLFOG(progressW);
		// #endif

		vec3 p3 = mat3(gbufferModelViewInverse) * rayEnd;
		vec3 np3 = normVec(p3);
		float ambfogfade =  clamp(exp(np3.y*1.5 - 1.5),0.0,1.0) ;
		vec3 ambientMul = exp(-max(estEyeDepth - dY * d,0.0) * waterCoefs) + ambfogfade*0.5 * clamp(eyeBrightnessSmooth.y/240.0,0.1,1.0);
		vec3 sunMul = exp(-max((estEyeDepth - dY * d) ,0.0)/abs(refractedSunVec.y) * waterCoefs)*cloudShadow;
		
		float sunCaustics = waterCaustics(progressW, WsunVec);
		sunCaustics =  max(pow(sunCaustics*3,2),0.5);

		vec3 light = (sh * lightSource * phase  * sunMul * sunCaustics +  (ambient*ambientMul))*scatterCoef;
		vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs *absorbance;
		absorbance *= exp(-dd * rayLength * waterCoefs);
	}
	inColor += vL;
}

vec4 RainRays(vec3 rayStart, vec3 rayEnd, float rayLength, float dither, vec3 ambient, vec3 lightSource, float VdotL){
	int spCount = 8;
	
	vec3 start = toShadowSpaceProjected(rayStart);
	vec3 end = toShadowSpaceProjected(rayEnd);
	vec3 dV = (end-start);


	//limit ray length at 32 blocks for performance and reducing integration error
	//you can't see above this anyway
	float maxZ = min(rayLength,1000)/(1e-8+rayLength);

	// min(length(dVWorld),far)/length(dVWorld);
	dV *= maxZ;
	vec3 dVWorld = mat3(gbufferModelViewInverse) * (rayEnd - rayStart) * maxZ;
	rayLength *= maxZ;
	float dY = normalize(mat3(gbufferModelViewInverse) * rayEnd).y * rayLength;
	vec3 progressW = (gbufferModelViewInverse[3].xyz+cameraPosition);
	vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec * lightCol.a;



	float absorbance = 1.0;
	vec3 vL = vec3(0.0);

	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);


	//Mie phase + somewhat simulates multiple scattering (Horizon zero down cloud approx)
	float mie = phaseg(VdotL,0.7);
	float rayL = phaseRayleigh(VdotL);

	float cloudShadow = 1;
	float expFactor = 11.0;
	for (int i=0;i<spCount;i++) {
		float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);		// exponential step position (0-1)
		float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);	//step length (derivative)

		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

		float sh = 1.0;
		#ifdef VL_CLOUDS_SHADOWS
			sh *= GetCloudShadow_VLFOG(progressW,WsunVec);
		#endif

		float density =  clamp(CumulusHeight - progressW.y,0,1) ;
		vec3 m = density*mC;
		vec3 DirectLight =  (lightSource*sh) * (m*mie);

		vec3 vL0 = DirectLight*25 ;


		vL += (vL0 - vL0 * exp(-m*dd*rayLength)) / (m+0.00000001)*absorbance;
		absorbance *= dot(clamp(exp(-m*dd*rayLength),0.0,1.0), vec3(0.333333));
	}
	return vec4(vL,0);
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
/* DRAWBUFFERS:0 */
	float lightleakfix = max(eyeBrightnessSmooth.y,0)/240.;

	vec2 tc = floor(gl_FragCoord.xy)/VL_RENDER_RESOLUTION*texelSize+0.5*texelSize;
	float z = texture2D(depthtex0,tc).x;

	#if DOF_QUALITY == 5
		vec2 jitter = clamp(jitter_offsets[frameCounter % 64], -1.0, 1.0);
		jitter = rotate(radians(float(frameCounter))) * jitter;
		jitter.y *= aspectRatio;
		jitter.x *= DOF_ANAMORPHIC_RATIO;
		jitter.xy *= 0.004 * JITTER_STRENGTH;

		vec3 fragpos_DOF = toScreenSpace(vec3((tc + jitter)/RENDER_SCALE,z));
	#endif
		
	if (isEyeInWater == 0){


		vec3 fragpos = toScreenSpace(vec3(tc/RENDER_SCALE,z));
		
		#ifdef Cumulus
			#ifdef Cloud_Fog
				vec4 VL_CLOUDFOG = InsideACloudFog(fragpos, vec2(R2_dither(),blueNoise()), lightCol.rgb/80., moonColor/150., averageSkyCol/30.);

				// vec4 rays = vec4(0.0);
				// if(rainStrength > 0.0){
				// 	rays = RainRays(vec3(0.0), fragpos, length(fragpos), R2_dither(), (avgAmbient*2.0) * 8./150./3., lightCol.rgb, dot(normalize(fragpos), normalize(sunVec)	));
				// 	VL_CLOUDFOG += rays * rainStrength;
				// }

				gl_FragData[0] = clamp(VL_CLOUDFOG, 0.0,65000.);
			#else

				vec4 VL_Fog = getVolumetricRays(fragpos, blueNoise(), averageSkyCol);
				gl_FragData[0] = clamp(VL_Fog,0.0,65000.);

			#endif

		#else

			vec4 VL_Fog = getVolumetricRays(fragpos, blueNoise(), averageSkyCol);
			gl_FragData[0] = clamp(VL_Fog,0.0,65000.);

		#endif


	} else {

		float dirtAmount = Dirt_Amount;
		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
		vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B);

		#ifdef AEROCHROME_MODE
			totEpsilon *= 2.0;
			scatterCoef *= 10.0;
		#endif

		vec3 fragpos = toScreenSpace(vec3(tc/RENDER_SCALE,z));
		float noise = blueNoise();
		vec3 vl = vec3(0.0);
		float estEyeDepth = clamp((14.0-eyeBrightnessSmooth.y/255.0*16.0)/14.0,0.,1.0);
		estEyeDepth *= estEyeDepth*estEyeDepth*34.0;

	
		vec3 lightningColor = (lightningEffect / 3) * (max(eyeBrightnessSmooth.y,0)/240.);
		vec3 ambientColVol = (averageSkyCol_Clouds/30.0) + lightningColor;
		vec3 lightColVol = (lightCol.rgb / 80.);
		estEyeDepth = max(Water_Top_Layer - cameraPosition.y,0.0);

		waterVolumetrics(vl, vec3(0.0), fragpos, estEyeDepth, estEyeDepth, length(fragpos), noise, totEpsilon, scatterCoef, ambientColVol, lightColVol*(1.0-pow(1.0-sunElevation*lightCol.a,5.0)) , dot(normalize(fragpos), normalize(sunVec)	));
		gl_FragData[0] = clamp(vec4(vl,1.0),0.000001,65000.);
	}
}
