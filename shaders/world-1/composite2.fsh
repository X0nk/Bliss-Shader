#version 120
//Render sky, volumetric clouds, direct lighting
#extension GL_EXT_gpu_shader4 : enable
#define SCREENSPACE_CONTACT_SHADOWS	//Raymarch towards the sun in screen-space, in order to cast shadows outside of the shadow map or at the contact of objects. Can get really expensive at high resolutions.
#define SHADOW_FILTER_SAMPLE_COUNT 9 // Number of samples used to filter the actual shadows [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 ]
#define CAVE_LIGHT_LEAK_FIX // Hackish way to remove sunlight incorrectly leaking into the caves. Can inacurrately remove shadows in some places
#define CLOUDS_SHADOWS
#define CLOUDS_SHADOWS_STRENGTH 1.0 //[0.1 0.125 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.9 1.0]
#define CLOUDS_QUALITY 0.5 //[0.1 0.125 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.9 1.0]
#define SSAO //It is also recommended to reduce the ambientOcclusionLevel value with this enabled
#define SSAO_SAMPLES 7 //[4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32]
#define TORCH_R 1.0 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define TORCH_G 0.75 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define TORCH_B 0.5 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define indirect_effect 1 // Choose what effect is applied to indirect light. [0 1 2 3]
#define AO_Strength 0.8 // strength of shadowed areas   [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 ]
#define GI_Strength 5.0 // strength of bounced light areas [ 1 2 3 4 5 6 7 8 9 10]

// #define HQ_SSGI

//////////// misc settings

// #define WhiteWorld // THIS IS A DEBUG VIEW. uses to see AO easier. used to see fake GI better (green light)
// #define LabPBR_Emissives
#define Emissive_Brightness 10.0 // [1. 2. 3. 4. 5. 6. 7. 8. 9. 10. 15. 20. 25. 30. 35. 40. 45. 50. 100.]
#define Emissive_Curve 2.0 // yes i blatantly copied kappa here. [1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 ]

#define n_MIN_LIGHT_AMOUNT 1.0 //[0.0 0.5 1.0 1.5 2.0 3.0 4.0 5.0]

const bool shadowHardwareFiltering = true;

varying vec2 texcoord;

uniform float nightVision;
flat varying vec4 lightCol; //main light source color (rgb),used light source(1=sun,-1=moon)
flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;
flat varying vec3 avgAmbient;
flat varying vec3 WsunVec;
flat varying vec2 TAA_Offset;
flat varying float tempOffsets;

uniform sampler2D colortex0;//clouds
uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
uniform sampler2D colortex3;
uniform sampler2D colortex4;//Skybox
uniform sampler2D colortex5;
uniform sampler2D colortex6;//Skybox
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D depthtex1;//depth
uniform sampler2D depthtex0;//depth
uniform sampler2D noisetex;//depth


uniform float isWastes;
uniform float isWarpedForest;
uniform float isCrimsonForest;
uniform float isSoulValley;
uniform float isBasaltDelta;

uniform int heldBlockLightValue;
uniform int frameCounter;
uniform int isEyeInWater;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;
uniform float far;
uniform float near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelView;

uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform vec3 cameraPosition;
// uniform int framemod8;
uniform vec3 sunVec;
uniform ivec2 eyeBrightnessSmooth;
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}
#include "lib/waterOptions.glsl"
#include "lib/color_transforms.glsl"
#include "lib/sky_gradient.glsl"
#include "lib/stars.glsl"
#include "lib/volumetricClouds.glsl"
#include "lib/waterBump.glsl"


float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}
vec3 ld(vec3 dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

#include "lib/specular.glsl"

vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}
float lengthVec (vec3 vec){
	return sqrt(dot(vec,vec));
}
#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)
float triangularize(float dither)
{
    float center = dither*2.0-1.0;
    dither = center*inversesqrt(abs(center));
    return clamp(dither-fsign(center),0.0,1.0);
}
float interleaved_gradientNoise(float temp){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+temp);
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
vec3 fp10Dither(vec3 color,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}

vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}
float facos(float sx){
    float x = clamp(abs( sx ),0.,1.);
    return sqrt( 1. - x ) * ( -0.16882 * x + 1.56734 );
}
vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
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

vec2 tapLocation(int sampleNumber,int nb, float nbRot,float jitter,float distort)
{
		float alpha0 = sampleNumber/nb;
    float alpha = (sampleNumber+jitter)/nb;
    float angle = jitter*6.28 + alpha * 4.0 * 6.28;

    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*sqrt(alpha);
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord )%512  , 0);
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y);
}
vec3 toShadowSpaceProjected(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    p3 = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
    p3 = diagonal3(shadowProjection) * p3 + shadowProjection[3].xyz;

    return p3;
}
vec2 tapLocation(int sampleNumber, float spinAngle,int nb, float nbRot,float r0)
{
    float alpha = (float(sampleNumber*1.0f + r0) * (1.0 / (nb)));
    float angle = alpha * (nbRot * 6.28) + spinAngle*6.28;

    float ssR = alpha;
    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*ssR;
}
void ssAO(inout vec3 lighting,vec3 fragpos,float mulfov, vec2 noise, vec3 normal, float lightmap){

	ivec2 pos = ivec2(gl_FragCoord.xy);
	const float tan70 = tan(70.*3.14/240.);
	float mulfov2 = gbufferProjection[1][1]/tan70;

	float maxR2 = fragpos.z*fragpos.z*mulfov2*2.*1.412/50.0;


	float rd = mulfov2 * 0.04 ;
	//pre-rotate direction
	float n = 0.0;

	float occlusion = 0.0;

	vec2 acc = -(TAA_Offset*(texelSize/2)) ;

	int seed = (frameCounter%40000)*2 + frameCounter;
	vec2  ij = fract(R2_samples(seed) + noise.rg );
	vec2 v = ij;

	for (int j = 0; j < 7 ;j++) {
		vec2 sp = tapLocation(j,v.x,7,1.682,v.y);
		vec2 sampleOffset = sp*rd ;
		ivec2 offset = ivec2(gl_FragCoord.xy + sampleOffset*vec2(viewWidth,viewHeight*aspectRatio));

		if (offset.x >= 0 && offset.y >= 0 && offset.x < viewWidth && offset.y < viewHeight ) {
			vec3 t0 = toScreenSpace(vec3(offset*texelSize+acc+0.5*texelSize,texelFetch2D(depthtex1,offset,0).x));
			vec3 vec = t0.xyz - fragpos;
			float dsquared = dot(vec,vec);

				if (dsquared > 1e-5){
					if (dsquared < maxR2){
						float NdotV = clamp(dot(vec*inversesqrt(dsquared), normalize(normal) 		),0.,1.);
						occlusion += NdotV * clamp(1.0-dsquared/maxR2,0.0,1.0);
					}
					n += 1.0 ;
				}
		}
	}
	occlusion *= mix(2.25,0.0,clamp(pow(lightmap,2),0,1));
	occlusion = max(1.0 - occlusion/n, 0.0);
	lighting = lighting * occlusion;
}


vec3 cosineHemisphereSample(vec2 Xi, float roughness)
{
    float r = sqrt(Xi.x);
    float theta = 2.0 * 3.14159265359 * Xi.y;

    float x = r * cos(theta);
    float y = r * sin(theta);

    return vec3(x, y, sqrt(clamp(1.0 - Xi.x,0.,1.)));
}
vec3 TangentToWorld(vec3 N, vec3 H, float roughness)
{
    vec3 UpVector = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(UpVector, N));
    vec3 B = cross(N, T);

    return vec3((T * H.x) + (B * H.y) + (N * H.z));
}

vec3 RT(vec3 dir, vec3 position, float noise, float stepsizes){
	float stepSize = stepsizes;
	int maxSteps = 12;
	vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * sqrt(3.0)*far) > -sqrt(3.0)*near) ?
	   								(-sqrt(3.0)*near -position.z) / dir.z : sqrt(3.0)*far;
	vec3 end = toClipSpace3(position+dir*rayLength) ;
	vec3 direction = end-clipPosition ;  //convert to clip space
	float len = max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y)/stepSize;
	//get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
	
	float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z)*2000.0;

	vec3 stepv = direction/len;

	int iterations = min(int(min(len, mult*len)-2), maxSteps);
	
	//Do one iteration for closest texel (good contact shadows)
	vec3 spos = clipPosition ;
	spos.xy += TAA_Offset*texelSize*0.5;
	spos += stepv/(stepSize/2);
	
  	for(int i = 0; i < iterations; i++){
		spos += stepv*noise;
		
		float sp=texelFetch2D(depthtex1,ivec2(spos.xy/texelSize),0).x;
		float currZ = (spos.z);
		
		if( sp < currZ) {
			// float dist = abs(sp-currZ)/currZ;
			 return vec3(spos.xy, invLinZ(sp));
		}
	}
	return vec3(1.1);
}
void rtAO(inout vec3 lighting, vec3 normal, vec2 noise, vec3 fragpos){
	int nrays = 4;
	float occlude = 0.0;

	for (int i = 0; i < nrays; i++){
		int seed = (frameCounter%40000)*nrays+i;
		vec2 ij = fract(R2_samples(seed) + noise );

		vec3 rayDir = TangentToWorld(  normal, normalize(cosineHemisphereSample(ij,1.0)) ,1.0) ;
		
		vec3 rayHit = RT(mat3(gbufferModelView)*rayDir, fragpos, blueNoise(), 12.);  // choc sspt 

		float skyLightDir = rayDir.y < 0.0 ? 1.0 : 1.0 ; // the positons where the occlusion happens
		if (rayHit.z > 1.0) occlude += skyLightDir;
	}
	lighting *= occlude/nrays;
}

void main() {
	float dirtAmount = Dirt_Amount;
	vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
	vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
	vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
	vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / pi;
	float z = texture2D(depthtex1,texcoord).x;
	vec2 tempOffset=TAA_Offset;

	vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(tempOffset)*texelSize*0.5,z));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);
 
	vec4 SpecularTex = texture2D(colortex8,texcoord);

	// for a thing
	vec3 wpos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);
	float dL = length(dVWorld);
	vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;
	progressW = gbufferModelViewInverse[3].xyz+cameraPosition + dVWorld;

	p3 += gbufferModelViewInverse[3].xyz;

	bool iswater = texture2D(colortex7,texcoord).a > 0.99;

	vec4 data = texture2D(colortex1,texcoord);
	vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y));
	vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w));

	vec3 albedo = toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));
	vec3 normal =  mat3(gbufferModelViewInverse) *	worldToView(decode(dataUnpacked0.yw));

	vec2 lightmap = dataUnpacked1.yz;
	bool translucent = abs(dataUnpacked1.w-0.5) <0.01;
	bool hand = abs(dataUnpacked1.w-0.75) <0.01;
	bool blocklights = abs(dataUnpacked1.w-0.8) <0.01;

	vec3 lightSource = normalize(vec3(0.0, -1.0,0.0));
	vec3 viewspace_sunvec = mat3(gbufferModelView) * lightSource;

	vec3 WsunVec = normalize(mat3(gbufferModelViewInverse) * viewspace_sunvec);
	float LightDir = max(dot(normal, WsunVec),0.0);


	vec3 ambientCoefs = normal/dot(abs(normal),vec3(1.));

	#ifdef WhiteWorld
		albedo = vec3(1.0);
	#endif

////// ----- indirect ----- //////
	
	vec3 custom_lightmap = texture2D(colortex4, (vec2(lightmap.x, pow(lightmap.y,2))*15.0+0.5+vec2(0.0,19.))*texelSize).rgb*8./150./3.; // y = torch

	// vec3 ambientLight = vec3(1.0) / 30;
	vec3 ambientLight = ((ambientUp + ambientDown + ambientRight + ambientLeft + ambientB + ambientF) )  * (abs(ambientCoefs.y * 0.5) + 0.5) ;

	
	vec3 Lightsources = custom_lightmap.y * vec3(TORCH_R,TORCH_G,TORCH_B) * 0.5;
	if(hand) Lightsources *= 0.15;
	if(blocklights) Lightsources *= 0.3;
	if(custom_lightmap.y > 10.) Lightsources *= 0.3;

	//apply a curve for the torch light so it doesnt mix with lab emissive colors too much
	#ifdef LabPBR_Emissives
		if(blocklights && (SpecularTex.a > 0.0 && SpecularTex.a < 1.0))  Lightsources = mix(vec3(0.0), Lightsources, SpecularTex.a);
	#endif

	ambientLight += Lightsources;

	#if indirect_effect == 1
		if (!hand) ssAO(ambientLight, fragpos, 1.0, blueNoise(gl_FragCoord.xy).rg, worldToView(decode(dataUnpacked0.yw)), lightmap.x) ;
	#endif
	// #if indirect_effect == 2
		// if (!hand ) rtAO(ambientLight, normal, blueNoise(gl_FragCoord.xy).rg, fragpos);
	// #endif
	// #if indirect_effect == 3
	// 	if (!hand) rtGI(ambientLight, normal, blueNoise(gl_FragCoord.xy).rg, fragpos, 1, albedo);
	// #endif


	vec3 Indirect_lighting = ambientLight;
	
////// ----- finalize ----- //////

	gl_FragData[0].rgb = Indirect_lighting * albedo ;
	
	#ifdef LabPBR_Emissives
		gl_FragData[0].rgb = SpecularTex.a < 255.0/255.0 ? mix(gl_FragData[0].rgb, albedo * Emissive_Brightness*0.5 , SpecularTex.a): gl_FragData[0].rgb;
	#endif
	
	// do this after water and stuff is done because yea
	#ifdef Specular_Reflections	
		MaterialReflections(gl_FragData[0].rgb, SpecularTex.r, SpecularTex.ggg, albedo, WsunVec, vec3(0), 0.0 , lightmap.y,  normal, np3, fragpos, vec3(blueNoise(gl_FragCoord.xy).rg,blueNoise()), hand);
	#endif

/* DRAWBUFFERS:3 */
}
