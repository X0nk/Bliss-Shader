#define ANTIALIASING_RELATED_SETTINGS
#define SHADOWMAP_CONSTANT_RELATED_SETTINGS
#define DIRECT_LIGHT_RELATED_SETTINGS
#define SUB_SURFACE_SCATTERING_RELATED_SETTINGS
#define INDIRECT_EFFECT_RELATED_SETTINGS
#define AMBIENT_LIGHT_RELATED_SETTINGS
#include "/lib/settings.glsl"
#include "/lib/macro_lod_mod.glsl"
#include "/lib/TAA_jitter.glsl"

#ifndef DH_AMBIENT_OCCLUSION
	#undef DISTANT_HORIZONS
#endif


flat varying vec3 WsunVec;


#include "/lib/res_params.glsl"

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex1;
uniform sampler2D colortex3; // Noise
uniform sampler2D colortex6; // Noise
uniform sampler2D colortex7; // Noise
uniform sampler2D colortex8; // Noise
uniform sampler2D colortex14; // Noise
uniform sampler2D colortex12; // Noise
uniform sampler2D colortex13; // Noise
uniform int isEyeInWater;
uniform sampler2D shadow;

#ifdef TRANSLUCENT_COLORED_SHADOWS
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowtex0;
	uniform sampler2D shadowtex1;
#endif


uniform sampler2D noisetex;
uniform vec3 sunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int frameCounter;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;


uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;


uniform vec3 cameraPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float viewWidth;
uniform float aspectRatio;
uniform float viewHeight;

// uniform float far;
uniform float near;
uniform float dhFarPlane;
uniform float dhNearPlane;


#include "/lib/sky_gradient.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/Shadows.glsl"

#define ffstep(x,y) clamp((y - x) * 1e35,0.0,1.0)
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

#include "/lib/DistantHorizons_projections.glsl"

#include "/lib/PhotonGTAO.glsl"

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
vec2 tapLocation2(int sampleNumber, int nb, float jitter){
    float alpha = (sampleNumber+jitter)/nb;
    float angle = jitter*6.28 + alpha * 84.0 * 6.28;

    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*sqrt(alpha);
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

float IGN(){
	vec2 coord = gl_FragCoord.xy + 5.588238 * float(frameCounter%64) ;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)) ;
	return noise;
}

float interleaved_gradientNoise_temporal(){
	vec2 coord = gl_FragCoord.xy;
	
	#if TAA_MODE > 0
		coord += (frameCounter*9)%40000;
	#endif

	return fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
float R2_dither(){
	vec2 coord = gl_FragCoord.xy ;

	#if TAA_MODE > 0
		coord += (frameCounter*2)%40000;
	#endif
	
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y) ;
}
float blueNoise(){
	#if TAA_MODE > 0
  		return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887);
	#endif
}
vec4 blueNoise(vec2 coord){
  return texelFetch(colortex6, ivec2(coord)%512 , 0) ;
}
vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}

vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}

vec2 SpiralSample(
	int samples, int totalSamples, float rotation, float Xi
){
	Xi = max(Xi,0.0015);
	
    float alpha = float(samples + Xi) * (1.0 / float(totalSamples));
	
    float theta = (2.0 *3.14159265359) * alpha * rotation;

    float r = sqrt(Xi);
	float x = r * sin(theta);
	float y = r * cos(theta);

    return vec2(x, y);
}

vec2 CleanSample(
	int samples, float totalSamples, float noise
){

	// this will be used to make 1 full rotation of the spiral. the mulitplication is so it does nearly a single rotation, instead of going past where it started
	float variance = noise * 0.897;

	// for every sample input, it will have variance applied to it.
	float variedSamples = float(samples) + variance;
	
	// for every sample, the sample position must change its distance from the origin.
	// otherwise, you will just have a circle.
    float spiralShape = variedSamples / (totalSamples + variance);

	float shape = 2.26;
    float theta = variedSamples * (pi * shape);

	float x =  cos(theta) * spiralShape;
	float y =  sin(theta) * spiralShape;

    return vec2(x, y);
}

float DH_ld(float dist) {
    return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
}
float DH_inv_ld (float lindepth){
	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}

void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}

float convertHandDepth_2(in float depth, bool hand) {
    if(!hand) return depth;
	
	float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    return ndcDepth * 0.5 + 0.5;
}

vec3 toScreenSpace_LOD_TEST( in vec2 texcoord, in float depth) {

	vec4 viewPos = vec4(0.0);
	vec3 feetPlayerPos = vec3(0.0);
	vec4 iProjDiag = vec4(0.0);

    if (depth < 1.0) {
		iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    	feetPlayerPos = vec3(texcoord, depth) * 2.0 - 1.0;
    	viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
		viewPos.xyz /= viewPos.w;
	} else {
		depth = texelFetch(LOD_DEPTHTEX1, ivec2(texcoord/texelSize), 0).x;
		iProjDiag = vec4(LOD_PROJECTION_INVERSE[0].x, LOD_PROJECTION_INVERSE[1].y, LOD_PROJECTION_INVERSE[2].zw);
    	feetPlayerPos = vec3(texcoord, depth) * 2.0 - 1.0;
    	viewPos = iProjDiag * feetPlayerPos.xyzz + LOD_PROJECTION_INVERSE[3];
		viewPos.xyz /= viewPos.w;
	}

    return viewPos.xyz;
}

vec2 SSAO(
	vec3 viewPos, vec3 normal, vec3 flatnormal, bool hand, float noise, bool isLOD
){
	int samples = 7;
	
	#if indirect_effect == SSAO_HQ
		samples = 21;
	#endif

	float occlusion = 0.0; 
	float sss = 0.0;

	vec2 jitterOffsets = taaJitter*texelSize*0.5 * RENDER_SCALE - texelSize*0.5;

	// scale the offset radius down as distance increases.
	float linearViewDistance = length(viewPos);
	float distanceScale = hand ? 30.0 : mix(40.0, 10.0, pow(clamp(1.0 - linearViewDistance/50.0,0.0,1.0),2.0));
	float depthCancelation = (linearViewDistance*linearViewDistance) / distanceScale ;

	// distanceScale *= 10;
  	vec2 screenEdges = 2.0/vec2(viewWidth, viewHeight);

	float n = 0.0;
	for (int i = 0; i < samples; i++) {
		
		vec2 offsets = CleanSample(i, samples - 1, noise) / distanceScale;

		ivec2 offsetUV = ivec2(clamp((gl_FragCoord.xy + offsets*vec2(viewWidth, viewHeight*aspectRatio)*RENDER_SCALE)*texelSize,screenEdges,1.0-screenEdges)/texelSize);

		if (offsetUV.x >= 0 && offsetUV.y >= 0 && offsetUV.x < viewWidth*RENDER_SCALE.x && offsetUV.y < viewHeight*RENDER_SCALE.y ) {
			

			#ifdef USING_LOD_MOD
				float sampleDepth = convertHandDepth_2(texelFetch(depthtex1, offsetUV, 0).x, hand);
				vec3 offsetViewPos = toScreenSpace_LOD_TEST((offsetUV*texelSize - jitterOffsets) * (1.0/RENDER_SCALE), sampleDepth);
			#else
				float sampleDepth = convertHandDepth_2(texelFetch(depthtex1, offsetUV, 0).x, hand);
				vec3 offsetViewPos = toScreenSpace(vec3((offsetUV*texelSize - jitterOffsets) * (1.0/RENDER_SCALE), sampleDepth));
			#endif

			vec3 viewPosDiff = offsetViewPos - viewPos;
			float viewPosDiffSquared = dot(viewPosDiff, viewPosDiff);
			
			float threshHold = max(1.0 - viewPosDiffSquared/depthCancelation, 0.0);

			if (viewPosDiffSquared > 1e-5){
				n += 1.0;
				float preAo = 1.0 - clamp(dot(normalize(viewPosDiff), flatnormal)*25.0,0.0,1.0);
				occlusion += max(0.0, dot(normalize(viewPosDiff), normal) - preAo) * threshHold;
				
				#ifdef Ambient_SSS
					sss += clamp(-dot(normalize(viewPosDiff), flatnormal) - occlusion/n,0.0,1.0) * 0.25 + (normalize(mat3(gbufferModelViewInverse) * -viewPosDiff).y - occlusion/n) * threshHold;
				#endif
			}
		}
	}
	float finaalAO = max(1.0 - occlusion*AO_Strength/max(n,1e-5), 0.0);
	float finalSSS = sss/float(samples);

	return vec2(finaalAO, finalSSS);
}

vec4 encode (vec3 n, vec2 lightmaps){
	n.xy = n.xy / dot(abs(n), vec3(1.0));
	n.xy = n.z <= 0.0 ? (1.0 - abs(n.yx)) * sign(n.xy) : n.xy;
    vec2 encn = clamp(n.xy * 0.5 + 0.5,-1.0,1.0);
	
    return vec4(encn,vec2(lightmaps.x,lightmaps.y));
}

//encoding by jodie
float encodeVec2(vec2 a){
    const vec2 constant1 = vec2( 1., 256.) / 65535.;
    vec2 temp = floor( a * 255. );
	return temp.x*constant1.x+temp.y*constant1.y;
}

float encodeVec2(float x,float y){
    return encodeVec2(vec2(x,y));
}

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}



/* RENDERTARGETS:3,14,12*/

void main() {

	gl_FragData[1] = vec4(0.0,0.0,0.0,texelFetch(colortex14,ivec2(gl_FragCoord.xy),0).a);

	vec2 texcoord = gl_FragCoord.xy*texelSize;
	float noise = R2_dither();

	vec4 data = texelFetch(colortex1,ivec2(gl_FragCoord.xy),0);
	vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y));
	vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w));
	vec3 normal = decode(dataUnpacked0.yw);
	
	vec2 lightmap = dataUnpacked1.yz;
	float lightLeakFix = clamp(pow(eyeBrightnessSmooth.y/240. + lightmap.y,2.0) ,0.0,1.0);

	vec4 specdata = texelFetch(colortex8, ivec2(gl_FragCoord.xy), 0);
	
	vec4 specdataUnpacked0 = vec4(decodeVec2(specdata.x),decodeVec2(specdata.y));
	vec4 specdataUnpacked1 = vec4(decodeVec2(specdata.z),decodeVec2(specdata.w));

	vec4 SpecularTex = vec4(specdataUnpacked0.xz, specdataUnpacked1.xz);
	vec3 FlatNormals = normalize(vec3(specdataUnpacked0.yw,specdataUnpacked1.y) * 2.0 - 1.0);
	// float vanilla_AO = min(max(specdataUnpacked1.w-0.005,0.0)/0.995,1.0);
	float LabSSS = clamp((-65.0 + SpecularTex.z * 255.0) / 190.0 ,0.0,1.0);	

	// bool lightningBolt = abs(dataUnpacked1.w-0.5) <0.01;
	// bool isLeaf = abs(dataUnpacked1.w-0.55) < 0.01;
	// bool translucent2 = abs(dataUnpacked1.w-0.6) <0.01;	// Weak translucency
	// bool translucent4 = abs(dataUnpacked1.w-0.65) <0.01;	// Weak translucency
	// bool entities = abs(dataUnpacked1.w-0.45) < 0.01;	
	bool hand = abs(dataUnpacked1.w-0.75) < 0.01;
	// bool opaqueParticles = abs(dataUnpacked1.w-0.8) < 0.01;

	float z = convertHandDepth_2(texelFetch(depthtex1,ivec2(gl_FragCoord.xy),0).x, hand);

	bool isLOD = z >= 1.0;
	
	if(isLOD) normal = viewToWorld(normal);
	
	#ifdef USING_LOD_MOD
		float DH_depth1 = texelFetch(LOD_DEPTHTEX1,ivec2(gl_FragCoord.xy),0).x;
		float swappedDepth =isLOD ? DH_depth1 : z;
	#else
		float DH_depth1 = 1.0;
		float swappedDepth = z;
	#endif

	vec3 viewPos = toScreenSpace_DH(texcoord/RENDER_SCALE - taaJitter*texelSize*0.5, z, DH_depth1);
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos;
	
	float depth = z;

	#ifdef USING_LOD_MOD
	    float _near = near;
	    float _far = far*4.0;
	    if (depth >= 1.0) {
	        depth = DH_depth1;
	        _near = LOD_NEARPLANE;
	        _far = LOD_FARPLANE;
	    }

	    depth = linearizeDepthFast(depth, _near, _far);
	    depth = depth / LOD_FARPLANE;

		if(depth < 1.0){
   			gl_FragData[2] = vec4(vec3(0.0), depth * depth * 65000.0);
		}else{
			gl_FragData[2] = vec4(vec3(0.0), 65000.0);
		}
	#endif


	#if indirect_effect == SSAO_FILTERED || indirect_effect == SSAO_HQ
		if(isLOD) FlatNormals = normal;
		
		vec2 SSAO_SSS = vec2(1.0,0.0);

		if(swappedDepth < 1.0){
			SSAO_SSS = SSAO(viewPos, worldToView(normal), worldToView(FlatNormals), hand, noise, isLOD);
			SSAO_SSS.y = clamp(SSAO_SSS.y + 0.5 * lightmap.y*lightmap.y,0.0,1.0);
		}

		gl_FragData[1].xy = SSAO_SSS;

	#elif indirect_effect == GTAO
		vec2 SSAO_SSS = vec2(1.0,0.0);
		
		if(swappedDepth < 1.0){
			vec2 r2 = fract(R2_samples(frameCounter*8%40000) + blueNoise(gl_FragCoord.xy).rg);
			float getGTAO = !hand ? ambient_occlusion(toClipSpace3_DH(viewPos,  isLOD) , viewPos, worldToView(normal), r2, isLOD) : 1.0;
			SSAO_SSS = vec2(getGTAO, 0.0);
		}

		gl_FragData[1].xy = SSAO_SSS;
	#endif


#ifdef OVERWORLD_SHADER
if (z < 1.0){

	float NdotL = clamp(dot(normal,WsunVec),0.0,1.0);
	float minshadowfilt = Min_Shadow_Filter_Radius;
	float maxshadowfilt = Max_Shadow_Filter_Radius;
	// float newnoise = IGN();

	#ifdef BASIC_SHADOW_FILTER
		if (LabSSS > 0.0 && NdotL < 0.001){  
			minshadowfilt = 50;
		//  maxshadowfilt = 50;
		 }
	#endif

		gl_FragData[0] = vec4(minshadowfilt, 0.0, 0.0, 0.0);

		#ifdef Variable_Penumbra_Shadows
			vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
			
			#if LIGHTLEAKFIX_MODE == 1
				if(!hand) GriAndEminShadowFix(feetPlayerPos, FlatNormals, lightLeakFix);
			#endif

			vec3 projectedShadowPosition = mat3(shadowModelView) * feetPlayerPos  + shadowModelView[3].xyz;
			projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;
			
			// float shadowMapBounds = shadowMapBounds(projectedShadowPosition);
			
			//apply distortion
			#ifdef DISTORT_SHADOWMAP
				float distortFactor = calcDistort(projectedShadowPosition.xy);
				projectedShadowPosition.xy *= distortFactor;
			#else
				float distortFactor = 1.0;
			#endif

			//do shadows only if on shadow map
			if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0 ){
				
				projectedShadowPosition.z += shadowProjection[3].z * 0.0013;
				
				const float threshMul = max(2048.0/shadowMapResolution*shadowDistance/128.0,0.95);
				float distortThresh = (sqrt(1.0-NdotL*NdotL)/NdotL+0.7)/distortFactor;
				float diffthresh = distortThresh/6000.0*threshMul;
				projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);

				float mult = maxshadowfilt;
				float avgBlockerDepth = 0.0;
				vec2 scales = vec2(0.0, Max_Filter_Depth);
				float blockerCount = 0.0;
				float rdMul = distortFactor*(1.0+mult)*d0*k/shadowMapResolution;
				float diffthreshM = diffthresh*mult*d0*k/20.;
				float avgDepth = 0.0;

				for(int i = 0; i < VPS_Search_Samples; i++){

					vec2 offsetS = CleanSample(i, VPS_Search_Samples - 1, noise) * 0.5;
				
					float weight = 3.0 + i * rdMul/SHADOW_FILTER_SAMPLE_COUNT*shadowMapResolution*distortFactor/2.7;
					
					float d = texelFetch(shadow, ivec2((projectedShadowPosition.xy+offsetS*rdMul)*shadowMapResolution),0).x;
					float b = smoothstep(weight*diffthresh/2.0, weight*diffthresh, projectedShadowPosition.z - d);

					blockerCount += b;

					#ifdef DISTANT_HORIZONS_SHADOWMAP
						avgDepth += max(projectedShadowPosition.z - d, 0.0)*10000.0;
					#else
						avgDepth += max(projectedShadowPosition.z - d, 0.0)*1000.0;
					#endif

					avgBlockerDepth += d * b;
				}

				gl_FragData[0].g = avgDepth / VPS_Search_Samples;
				gl_FragData[0].b = blockerCount / VPS_Search_Samples;

				if (blockerCount >= 0.9){
					avgBlockerDepth /= blockerCount;
					float ssample = max(projectedShadowPosition.z - avgBlockerDepth,0.0)*1500.0;
					gl_FragData[0].r = clamp(ssample, scales.x, scales.y)/scales.y*(mult-minshadowfilt)+minshadowfilt;
				}
			}
		#endif
}
#endif
}