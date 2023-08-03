#include "/lib/settings.glsl"


uniform sampler2D noisetex;
uniform sampler2D depthtex0;

uniform sampler2D colortex2;
uniform sampler2D colortex3;
// uniform sampler2D colortex4;

uniform vec3 sunVec;
uniform float sunElevation;
uniform float far;

uniform int frameCounter;
uniform float frameTimeCounter;

varying vec2 texcoord;
uniform vec2 texelSize;
flat varying vec2 TAA_Offset;

uniform int isEyeInWater;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;

#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/projections.glsl"

#ifdef END_SHADER
	#include "/lib/end_fog.glsl"
#endif

#ifdef NETHER_SHADER
	#include "/lib/nether_fog.glsl"
#endif

#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)

float interleaved_gradientNoise(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+TAA_Offset.x);
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}

void waterVolumetrics(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient){
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

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////


void main() {
/* DRAWBUFFERS:0 */

	vec2 tc = floor(gl_FragCoord.xy)*2.0*texelSize+0.5*texelSize;
	float z = texture2D(depthtex0,tc).x;
	vec3 fragpos = toScreenSpace(vec3(tc,z));

	if (isEyeInWater == 0){

		vec4 VolumetricFog = GetVolumetricFog(fragpos, blueNoise(), interleaved_gradientNoise());

		gl_FragData[0] = clamp(VolumetricFog, 0.000001, 65000.0);
	} 
	
	if (isEyeInWater == 1){

		float dirtAmount = Dirt_Amount;
		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
		vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

		vec3 fragpos0 = toScreenSpace(vec3(texcoord - TAA_Offset*texelSize*0.5,z));

		vec3 ambientColVol =  max(vec3(1.0,0.5,1.0) * 0.6, vec3(0.2,0.4,1.0) * MIN_LIGHT_AMOUNT*0.01);

		gl_FragData[0].a = 1;
		waterVolumetrics(gl_FragData[0].rgb, fragpos0, fragpos, 1 , 1, 1, blueNoise(), totEpsilon, scatterCoef, ambientColVol);

	}
}
