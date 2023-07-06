#version 120
//#extension GL_EXT_gpu_shader4 : enable

#include "lib/settings.glsl"


flat varying vec3 WsunVec;
flat varying vec2 TAA_Offset;
#include "/lib/res_params.glsl"
#include "lib/Shadow_Params.glsl"

uniform sampler2D depthtex1;
uniform sampler2D colortex1;
uniform sampler2D colortex6; // Noise
uniform sampler2D colortex8; // Noise
uniform sampler2D colortex15; // Noise
uniform sampler2D shadow;
uniform sampler2D noisetex;
uniform vec3 sunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int frameCounter;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform float viewWidth;
uniform float aspectRatio;
uniform float viewHeight;
uniform float far;
uniform float near;

#define ffstep(x,y) clamp((y - x) * 1e35,0.0,1.0)
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}
vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}

vec2 tapLocation(int sampleNumber,int nb, float nbRot,float jitter,float distort)
{
    float alpha = (sampleNumber+jitter)/nb;
    float angle = jitter*6.28+alpha * nbRot * 6.28;
    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*alpha;
}
// float interleaved_gradientNoise(){
// 	vec2 coord = gl_FragCoord.xy;
// 	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)+ 1.0/1.6180339887 * frameCounter) ;
// 	return noise;
// }
// float interleaved_gradientNoise2(){
// 	vec2 alpha = vec2(0.75487765, 0.56984026);
// 	vec2 coord = vec2(alpha.x * gl_FragCoord.x,alpha.y * gl_FragCoord.y)+ 1.0/1.6180339887 * frameCounter;
// 	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
// 	return noise;
// }
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000);
	// vec2 coord = gl_FragCoord.xy + frameTimeCounter;
	// vec2 coord = gl_FragCoord.xy;
	float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715)) );
	return noise ;
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
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter);
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord )%512  , 0);
}

vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}
vec2 tapLocation_alternate(
	int sampleNumber, 
	float spinAngle,
	int nb, 
	float nbRot,
	float r0
){
    float alpha = (float(sampleNumber*1.0f + r0) * (1.0 / (nb)));
    float angle = alpha * (nbRot * 3.14) ;

    float ssR = alpha + spinAngle*3.14;
    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);
    return vec2(cos_v, sin_v)*ssR;
}
vec3 viewToWorld(vec3 viewPosition) {
    vec4 pos;
    pos.xyz = viewPosition;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}


// Emin's and Gri's combined ideas to stop peter panning and light leaking, also has little shadowacne so thats nice
// https://www.complementary.dev/reimagined
// https://github.com/gri573
void GriAndEminShadowFix(
	inout vec3 WorldPos,
	vec3 FlatNormal,
	float VanillaAO,
	float SkyLightmap,
	bool Entities
){
	float DistanceOffset = clamp(0.1 + length(WorldPos) / (shadowMapResolution*0.20), 0.0,1.0) ;
	vec3 Bias = FlatNormal * DistanceOffset; // adjust the bias thingy's strength as it gets farther away.
	
	// stop lightleaking
	if(SkyLightmap < 0.1 && !Entities) {
		WorldPos += mix(Bias, 0.5 * (0.5 - fract(WorldPos + cameraPosition + FlatNormal*0.01 )	), VanillaAO) ;
	}else{
		WorldPos += Bias;
	}
}

void main() {
/* DRAWBUFFERS:3 */
	vec2 texcoord = gl_FragCoord.xy*texelSize;
	

	float z = texture2D(depthtex1,texcoord).x;

	vec2 tempOffset=TAA_Offset;

	vec4 data = texture2D(colortex1,texcoord);
	vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y));
	vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w));
	vec3 normal = mat3(gbufferModelViewInverse) * clamp(worldToView( decode(dataUnpacked0.yw) ),-1.,1.);
	vec2 lightmap = dataUnpacked1.yz;


	bool translucent = abs(dataUnpacked1.w-0.5) <0.01;
	bool translucent2 = abs(dataUnpacked1.w-0.6) <0.01;	// Weak translucency
	bool translucent3 = abs(dataUnpacked1.w-0.55) <0.01;	// Weak translucency
	bool translucent4 = abs(dataUnpacked1.w-0.65) <0.01;	// Weak translucency
	bool entities = abs(dataUnpacked1.w-0.45) <0.01;	// Weak translucency
	bool hand = abs(dataUnpacked1.w-0.75) <0.01;

	float minshadowfilt = Min_Shadow_Filter_Radius;
	float maxshadowfilt = Max_Shadow_Filter_Radius;

	float vanillAO = clamp(texture2D(colortex15,texcoord).a,0.0,1.0)  ;

	if(lightmap.y < 0.1 && !entities){
		// minshadowfilt *= vanillAO;
		maxshadowfilt = mix(minshadowfilt ,maxshadowfilt, 	vanillAO);
	}


	float SpecularTex = texture2D(colortex8,texcoord).z;
	float LabSSS = clamp((-65.0 + SpecularTex * 255.0) / 190.0 ,0.0,1.0);


	#ifndef Variable_Penumbra_Shadows
		if (translucent  && !hand)  minshadowfilt += 25;
	#endif


	gl_FragData[0] = vec4(minshadowfilt, 0.1, 0.0, 0.0);



	if (z < 1.0){

		// if( translucent || translucent2)

		if (!hand){

			float NdotL = clamp(dot(normal,WsunVec),0.0,1.0);
			
			vec3 fragpos = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z));

		#ifdef Variable_Penumbra_Shadows

			if (NdotL > 0.001 || LabSSS > 0.0) {

				vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;

				vec3 projectedShadowPosition = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
				projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

				//apply distortion
				float distortFactor = calcDistort(projectedShadowPosition.xy);
				projectedShadowPosition.xy *= distortFactor;
				//do shadows only if on shadow map
			if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0){
					const float threshMul = max(2048.0/shadowMapResolution*shadowDistance/128.0,0.95);
					float distortThresh = (sqrt(1.0-NdotL*NdotL)/NdotL+0.7)/distortFactor;
					float diffthresh = distortThresh/6000.0*threshMul;
					projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);

					float mult = maxshadowfilt;
					float avgBlockerDepth = 0.0;
					vec2 scales = vec2(0.0,Max_Filter_Depth);
					float blockerCount = 0.0;
					float rdMul = distortFactor*(1.0+mult)*d0*k/shadowMapResolution;
					float diffthreshM = diffthresh*mult*d0*k/20.;
					float avgDepth = 0.0;

					int seed = (frameCounter%40000) + (1+frameCounter);
					float randomDir = fract(R2_samples(seed).y + blueNoise(gl_FragCoord.xy).g) * 1.61803398874 ;

					for(int i = 0; i < VPS_Search_Samples; i++){

						// vec2 offsetS = tapLocation(i,VPS_Search_Samples,1.61803398874   , blueNoise(),0.0);

						vec2 offsetS = tapLocation_alternate(i, 0.0, 7, 20, randomDir);

						float weight = 3.0 + (i+blueNoise() ) *rdMul/SHADOW_FILTER_SAMPLE_COUNT*shadowMapResolution*distortFactor/2.7;
						float d = texelFetch2D( shadow, ivec2((projectedShadowPosition.xy+offsetS*rdMul)*shadowMapResolution),0).x;
						float b = smoothstep(weight*diffthresh/2.0, weight*diffthresh, projectedShadowPosition.z - d);

						blockerCount += b;
						avgDepth += max(projectedShadowPosition.z - d, 0.0)*1000.;
						avgBlockerDepth += d * b;
					}
					
					gl_FragData[0].g = avgDepth / VPS_Search_Samples;
					gl_FragData[0].b = blockerCount / VPS_Search_Samples;
					if (blockerCount >= 0.9){
						avgBlockerDepth /= blockerCount;
						float ssample = max(projectedShadowPosition.z - avgBlockerDepth,0.0)*1500.0;
						gl_FragData[0].r = clamp(ssample, scales.x, scales.y)/(scales.y)*(mult-minshadowfilt)+minshadowfilt;
					}
				}
			}
		#endif
		}

}

}
