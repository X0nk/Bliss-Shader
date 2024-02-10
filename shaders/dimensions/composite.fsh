#include "/lib/settings.glsl"


flat varying vec3 WsunVec;
flat varying vec2 TAA_Offset;

#include "/lib/res_params.glsl"

uniform sampler2D depthtex1;
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;

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

// uniform float far;
uniform float near;
uniform float dhFarPlane;
uniform float dhNearPlane;

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
vec2 tapLocation2(int sampleNumber, int nb, float jitter){
    float alpha = (sampleNumber+jitter)/nb;
    float angle = jitter*6.28 + alpha * 84.0 * 6.28;

    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*sqrt(alpha);
}
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
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
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
vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}

#include "/lib/Shadow_Params.glsl"


const float PI = 3.141592653589793238462643383279502884197169;
vec2 tapLocation_simple(
	int samples, int totalSamples, float rotation, float rng
){
    float alpha = float(samples + rng) * (1.0 / float(totalSamples));
    float angle = alpha * (rotation * PI);

	float sin_v = sin(angle);
	float cos_v = cos(angle);

    return vec2(cos_v, sin_v) * sqrt(alpha);
}
vec2 SpiralSample(
	int samples, int totalSamples, float rotation, float Xi
){
    float alpha = float(samples + Xi) * (1.0 / float(totalSamples));
	
    float theta = 3.14159265359 * alpha * rotation ;

    float r = sqrt(Xi);
	float x = r * sin(theta);
	float y = r * cos(theta);

    return vec2(x, y);
}



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



/* DRAWBUFFERS:3 */
void main() {
	vec2 texcoord = gl_FragCoord.xy*texelSize;
	
	float z = texture2D(depthtex1,texcoord).x;
	float DH_depth1 = texture2D(depthtex1,texcoord).x;

	vec2 tempOffset=TAA_Offset;

	vec4 data = texture2D(colortex1,texcoord);
	vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y));
	vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w));
	vec3 normal = mat3(gbufferModelViewInverse) * clamp(worldToView( decode(dataUnpacked0.yw) ),-1.,1.);
	vec2 lightmap = dataUnpacked1.yz;


	// bool lightningBolt = abs(dataUnpacked1.w-0.5) <0.01;
	// bool isLeaf = abs(dataUnpacked1.w-0.55) <0.01;
	// bool translucent2 = abs(dataUnpacked1.w-0.6) <0.01;	// Weak translucency
	// bool translucent4 = abs(dataUnpacked1.w-0.65) <0.01;	// Weak translucency
	bool entities = abs(dataUnpacked1.w-0.45) < 0.01;	
	bool hand = abs(dataUnpacked1.w-0.75) < 0.01;
	// bool blocklights = abs(dataUnpacked1.w-0.8) <0.01;


	float minshadowfilt = Min_Shadow_Filter_Radius;
	float maxshadowfilt = Max_Shadow_Filter_Radius;

	float NdotL = clamp(dot(normal,WsunVec),0.0,1.0);

	// vec4 normalAndAO = texture2D(colortex15,texcoord);
	// vec3 FlatNormals = normalAndAO.rgb * 2.0 - 1.0;
	// float vanillAO = clamp(normalAndAO.a,0.0,1.0)  ;

	float vanillAO = clamp(texture2D(colortex15,texcoord).a,0.0,1.0)  ;

	if(lightmap.y < 0.1 && !entities){
		// minshadowfilt *= vanillAO;
		maxshadowfilt = mix(minshadowfilt, maxshadowfilt, 	vanillAO);
	}


	float SpecularTex = texture2D(colortex8,texcoord).z;
	float LabSSS = clamp((-64.0 + SpecularTex * 255.0) / 191.0 ,0.0,1.0);

	#ifndef Variable_Penumbra_Shadows
		if (LabSSS > 0.0 && !hand && NdotL < 0.001)  minshadowfilt += 50;
	#endif

	if (z < 1.0 && !hand){

		gl_FragData[0] = vec4(minshadowfilt, 0.1, 0.0, 0.0);
		gl_FragData[0].y = 0;

		// vec3 viewPos = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z));
		
		vec3 viewPos = toScreenSpace_DH(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5, z, DH_depth1);

		#ifdef Variable_Penumbra_Shadows

			if (LabSSS > 0.0) {

				
				vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;


				vec3 projectedShadowPosition = mat3(shadowModelView) * feetPlayerPos  + shadowModelView[3].xyz;
				projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;
				
				//apply distortion
				#ifdef DISTORT_SHADOWMAP
					float distortFactor = calcDistort(projectedShadowPosition.xy);
					projectedShadowPosition.xy *= distortFactor;
				#else
					float distortFactor = 1.0;
				#endif
				//do shadows only if on shadow map
				if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0 || length(feetPlayerPos) < far){
					const float threshMul = max(2048.0/shadowMapResolution*shadowDistance/128.0,0.95);
					float distortThresh = (sqrt(1.0-NdotL*NdotL)/NdotL+0.7)/distortFactor;
					float diffthresh = distortThresh/6000.0*threshMul;
					projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);

					float mult = maxshadowfilt;
					float avgBlockerDepth = 0.0;
					vec2 scales = vec2(0.0, 120.0 - Max_Filter_Depth);
					float blockerCount = 0.0;
					float rdMul = distortFactor*(1.0+mult)*d0*k/shadowMapResolution;
					float diffthreshM = diffthresh*mult*d0*k/20.;
					float avgDepth = 0.0;

					// int seed = (frameCounter%40000) + frameCounter*2;
					// float noise = fract(R2_samples(seed).y + blueNoise(gl_FragCoord.xy).y);
					float noise = R2_dither();

					for(int i = 0; i < VPS_Search_Samples; i++){

						vec2 offsetS = SpiralSample(i, 7, 8, noise);
		

						float weight = 3.0 + (i+noise) *rdMul/SHADOW_FILTER_SAMPLE_COUNT*shadowMapResolution*distortFactor/2.7;
						// float d = texelFetch2D( shadow, ivec2((projectedShadowPosition.xy+offsetS*rdMul)*shadowMapResolution),0).x;
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