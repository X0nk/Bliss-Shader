#include "/lib/settings.glsl"

// #if defined END_SHADER || defined NETHER_SHADER
// 	#undef IS_LPV_ENABLED
// #endifs

#ifdef IS_LPV_ENABLED
	#extension GL_ARB_shader_image_load_store: enable
	#extension GL_ARB_shading_language_packing: enable
#endif

#include "/lib/util.glsl"
#include "/lib/res_params.glsl"


#define diagonal3_old(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD_old(m, v) (diagonal3_old(m) * (v) + (m)[3].xyz)

const bool colortex5MipmapEnabled = true;

#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif

	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;

	#if Sun_specular_Strength != 0
		#define LIGHTSOURCE_REFLECTION
	#endif
	
	#include "/lib/lightning_stuff.glsl"
#endif

#ifdef NETHER_SHADER
	uniform float nightVision;
	const bool colortex4MipmapEnabled = true;
	uniform vec3 lightningEffect;
	// #define LIGHTSOURCE_REFLECTION
#endif

#ifdef END_SHADER
	uniform float nightVision;
	uniform vec3 lightningEffect;
	
	flat varying float Flashing;
	// #define LIGHTSOURCE_REFLECTION
#endif

uniform int hideGUI;
uniform sampler2D noisetex; //noise
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
#endif

uniform sampler2D colortex0; //clouds
uniform sampler2D colortex1; //albedo(rgb),material(alpha) RGBA16
uniform sampler2D colortex2; //translucents(rgba)
uniform sampler2D colortex3; //filtered shadowmap(VPS)
uniform sampler2D colortex4; //LUT(rgb), quarter res depth(alpha)
uniform sampler2D colortex5; //TAA buffer/previous frame
uniform sampler2D colortex6; //Noise
uniform sampler2D colortex7; //water?
uniform sampler2D colortex8; //Specular
// uniform sampler2D colortex9; //Specular
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex14;
uniform sampler2D colortex15; // flat normals(rgb), vanillaAO(alpha)

#ifdef IS_LPV_ENABLED
	uniform usampler1D texBlockData;
	uniform sampler3D texLpv1;
	uniform sampler3D texLpv2;
#endif


uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

// uniform float far;
uniform float near;
uniform float farPlane;
uniform float dhFarPlane;
uniform float dhNearPlane;

flat varying vec3 zMults;

uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

uniform float eyeAltitude;
flat varying vec2 TAA_Offset;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform float rainStrength;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

uniform vec3 sunVec;
flat varying vec3 WsunVec;
flat varying vec3 unsigned_WsunVec;
flat varying float exposure;

#ifdef IS_LPV_ENABLED
	uniform int heldItemId;
	uniform int heldItemId2;
#endif


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

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 feetPlayerPos = p * 2. - 1.;
    vec4 viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
    return viewPos.xyz / viewPos.w;
}



#define TESTTHINGYG

#include "/lib/color_transforms.glsl"
#include "/lib/waterBump.glsl"

#include "/lib/Shadow_Params.glsl"
#include "/lib/Shadows.glsl"
#include "/lib/stars.glsl"

#ifdef OVERWORLD_SHADER
	
	#define CLOUDSHADOWSONLY
	#include "/lib/volumetricClouds.glsl"
	#define CLOUDS_INTERSECT_TERRAIN
#endif


#ifdef IS_LPV_ENABLED
	#include "/lib/hsv.glsl"
	#include "/lib/lpv_common.glsl"
	#include "/lib/lpv_render.glsl"
#endif

#include "/lib/diffuse_lighting.glsl"

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

#include "/lib/sky_gradient.glsl"
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


#include "/lib/end_fog.glsl"
#include "/lib/specular.glsl"



#include "/lib/DistantHorizons_projections.glsl"

float DH_ld(float dist) {
    return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
}
float DH_inv_ld (float lindepth){
	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
	// return (2.0 * near) / (far + near - depth * (far - near));
}
float invertlinearDepthFast(const in float depth, const in float near, const in float far) {
	return ((2.0*near/depth)-far-near)/(far-near);
}


vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}
float lengthVec (vec3 vec){
	return sqrt(dot(vec,vec));
}

// #define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)

float triangularize(float dither)
{
    float center = dither*2.0-1.0;
    dither = center*inversesqrt(abs(center));
    return clamp(dither-fsign(center),0.0,1.0);
}

vec3 fp10Dither(vec3 color,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}



// float facos(float sx){
//     float x = clamp(abs( sx ),0.,1.);
//     return sqrt( 1. - x ) * ( -0.16882 * x + 1.56734 );
// }

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


vec3 BilateralFiltering(sampler2D tex, sampler2D depth,vec2 coord,float frDepth,float maxZ){
  vec4 sampled = vec4(texelFetch2D(tex,ivec2(coord),0).rgb,1.0);

  return vec3(sampled.x,sampled.yz/sampled.w);
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715) ) );
	return noise ;
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
  return texelFetch2D(colortex6, ivec2(coord)%512 , 0) ;
}

vec3 toShadowSpaceProjected(vec3 feetPlayerPos){
	
	mat4 DH_shadowProjection = DH_shadowProjectionTweak(shadowProjection);

    feetPlayerPos = mat3(gbufferModelViewInverse) * feetPlayerPos + gbufferModelViewInverse[3].xyz;
    feetPlayerPos = mat3(shadowModelView) * feetPlayerPos + shadowModelView[3].xyz;
    feetPlayerPos = diagonal3_old(DH_shadowProjection) * feetPlayerPos + DH_shadowProjection[3].xyz;

    return feetPlayerPos;
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
vec2 tapLocation_simple(
	int samples, int totalSamples, float rotation, float rng
){
	const float PI = 3.141592653589793238462643383279502884197169;
    float alpha = float(samples + rng) * (1.0 / float(totalSamples));
    float angle = alpha * (rotation * PI);

	float sin_v = sin(angle);
	float cos_v = cos(angle);

    return vec2(cos_v, sin_v) * sqrt(alpha);
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
    float spiralShape = pow(variedSamples / (totalSamples + variance),0.5);

	float shape = 2.26; // this is very important. 2.26 is very specific
    float theta = variedSamples * (PI * shape);

	float x =  cos(theta) * spiralShape;
	float y =  sin(theta) * spiralShape;

    return vec2(x, y);
}
vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}
vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}
float swapperlinZ(float depth, float _near, float _far) {
    return (2.0 * _near) / (_far + _near - depth * (_far - _near));
	// l = (2*n)/(f+n-d(f-n))
	// f+n-d(f-n) = 2n/l
	// -d(f-n) = ((2n/l)-f-n)
	// d = -((2n/l)-f-n)/(f-n)

}

vec2 SSRT_Shadows(vec3 viewPos, bool depthCheck, vec3 lightDir, float noise, bool isSSS, bool hand){
	

	float handSwitch = hand ? 1.0 : 0.0;

    float steps = 16.0;
	float Shadow = 1.0; 
	float SSS = 0.0;
	
	float _near = near; float _far = far*4.0;

	if (depthCheck) {
		_near = dhNearPlane;
		_far = dhFarPlane;
	}
    
	vec3 worldpos = mat3(gbufferModelViewInverse) * viewPos;
	float dist = 1.0 + length(worldpos)/(_far/2.0); // step length as distance increases
	vec3 clipPosition = toClipSpace3_DH(viewPos, depthCheck);

	//prevents the ray from going behind the camera
	float rayLength = ((viewPos.z + lightDir.z * _far*sqrt(3.)) > -_near) ?
      				  (-_near -viewPos.z) / lightDir.z : _far*sqrt(3.);

    vec3 direction = toClipSpace3_DH(viewPos + lightDir*rayLength, depthCheck) - clipPosition;  //convert to clip space
    direction.xyz = direction.xyz / max(abs(direction.x)/texelSize.x, abs(direction.y)/texelSize.y);	//fixed step size
	
	float Stepmult = depthCheck ? (isSSS ? 1.0 : 6.0) : (isSSS ? 1.0 : 3.0);

    vec3 rayDir = direction * Stepmult * vec3(RENDER_SCALE,1.0) ;
	
	vec3 screenPos = clipPosition * vec3(RENDER_SCALE,1.0) + rayDir * noise;

	float minZ = screenPos.z;
	float maxZ = screenPos.z;

	for (int i = 0; i < int(steps); i++) {
		
		float samplePos = convertHandDepth_2(texture2D(depthtex1, screenPos.xy).x, hand);
		
		#ifdef DISTANT_HORIZONS
			if(depthCheck) samplePos = texture2D(dhDepthTex1, screenPos.xy).x;
		#endif

		if(samplePos < screenPos.z && (samplePos <= max(minZ,maxZ) && samplePos >= min(minZ,maxZ))){

			vec2 linearZ = vec2(swapperlinZ(screenPos.z, _near, _far), swapperlinZ(samplePos, _near, _far));
			float calcthreshold = abs(linearZ.x - linearZ.y) / linearZ.x;

			if (calcthreshold < 0.035) Shadow = 0.0;
			
			SSS += 1.0/steps;
		} 
		
		minZ = maxZ - (isSSS ? 1.0 : 0.0001) / swapperlinZ(samplePos, _near, _far);
		maxZ += rayDir.z;

		screenPos += rayDir;
	}
	return vec2(Shadow, SSS);
}


void Emission(
	inout vec3 Lighting,
	vec3 Albedo,
	float Emission,
	float exposure
){
	float autoBrightnessAdjust = mix(5.0, 100.0, clamp(exp(-10.0*exposure),0.0,1.0));
	if( Emission < 254.5/255.0) Lighting = mix(Lighting, Albedo * Emissive_Brightness * autoBrightnessAdjust, pow(Emission, Emissive_Curve)); // old method.... idk why
	// if( Emission < 254.5/255.0 ) Lighting += (Albedo * Emissive_Brightness) * pow(Emission, Emissive_Curve);
}

#include "/lib/indirect_lighting_effects.glsl"
#include "/lib/PhotonGTAO.glsl"

vec4 BilateralUpscale(sampler2D tex, sampler2D depth, vec2 coord, float referenceDepth){
  
	const ivec2 scaling = ivec2(1.0/VL_RENDER_RESOLUTION);
	ivec2 posDepth  = ivec2(coord*VL_RENDER_RESOLUTION) * scaling;
	ivec2 posColor  = ivec2(coord*VL_RENDER_RESOLUTION);

  	ivec2 pos = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 getRadius[4] = ivec2[](
   	 	ivec2(-2,-2),
	  	ivec2(-2, 0),
		ivec2( 0, 0),
		ivec2( 0,-2)
  	);
	
	float diffThreshold = zMults.x;

	vec4 RESULT = vec4(0.0);
	float SUM = 0.0;

	for (int i = 0; i < 4; i++) {
		
		ivec2 radius = getRadius[i];
		
		float offsetDepth = ld(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling, 0).r);
		
		float EDGES = abs(offsetDepth - referenceDepth) < diffThreshold ? 1.0 : 1e-5;
		
		RESULT += texelFetch2D(tex, posColor + radius + pos, 0) * EDGES;
		
		SUM += EDGES;
	}
	// return vec4(0,0,0,1) * SUM;
	return RESULT / SUM;
}

vec4 BilateralUpscale_DH(sampler2D tex, sampler2D depth, vec2 coord, float referenceDepth){
	ivec2 scaling = ivec2(1.0/VL_RENDER_RESOLUTION);
	ivec2 posDepth  = ivec2(coord*VL_RENDER_RESOLUTION) * scaling;
	ivec2 posColor  = ivec2(coord*VL_RENDER_RESOLUTION);
 	ivec2 pos = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 getRadius[4] = ivec2[](
   		ivec2(-2,-2),
	 	ivec2(-2, 0),
		ivec2( 0, 0),
		ivec2( 0,-2)
		// ivec2(-1,-1),
	 	// ivec2( 1, 1),
		// ivec2(-1, 1),
		// ivec2( 1,-1)
  	);

	#ifdef DISTANT_HORIZONS
		float diffThreshold = 0.01;
	#else
		float diffThreshold = zMults.x;
	#endif

	vec4 RESULT = vec4(0.0);
	float SUM = 0.0;

	RESULT += texelFetch2D(tex, posColor + pos, 0);

	for (int i = 0; i < 4; i++) {
		
		ivec2 radius = getRadius[i] ;

		#ifdef DISTANT_HORIZONS
			float offsetDepth = sqrt(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling,0).a/65000.0);
		#else
			float offsetDepth = ld(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling, 0).r);
		#endif

		float EDGES = abs(offsetDepth - referenceDepth) < diffThreshold ? 1.0 : 1e-5;
		
		RESULT += texelFetch2D(tex, posColor + radius + pos, 0) * EDGES;

		SUM += EDGES;
	}
	// return vec4(1) * SUM;
	return RESULT / SUM;

}

void BilateralUpscale_REUSE_Z(sampler2D tex1, sampler2D tex2, sampler2D depth, vec2 coord, float referenceDepth, inout vec2 ambientEffects, inout vec3 filteredShadow, bool hand){
	ivec2 scaling = ivec2(1.0);
	ivec2 posDepth  = ivec2(coord) * scaling;
	ivec2 posColor  = ivec2(coord);
  	ivec2 pos = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 getRadius[4] = ivec2[](
		ivec2(-1,-1),
	 	ivec2( 1,-1),
		ivec2( 1, 1),
		ivec2(-1, 1)
  	);

	#ifdef DISTANT_HORIZONS
		float diffThreshold = 0.0005;
	#else
		float diffThreshold = 0.005;
	#endif

	vec3 shadow_RESULT = vec3(0.0);
	vec2 ssao_RESULT = vec2(0.0);
	float SUM = 1.0;

	#ifdef LIGHTING_EFFECTS_BLUR_FILTER
		for (int i = 0; i < 4; i++) {

			ivec2 radius = getRadius[i];

			#ifdef DISTANT_HORIZONS
				float offsetDepth = sqrt(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling,0).a/65000.0);
			#else
				float offsetDepth = ld(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling, 0).r);
			#endif

			float EDGES = abs(offsetDepth - referenceDepth) < diffThreshold ? 1.0 : 1e-5;

			#ifdef Variable_Penumbra_Shadows
				shadow_RESULT += texelFetch2D(tex1, posColor + radius + pos, 0).rgb * EDGES;
			#endif

			#if indirect_effect == 1
				ssao_RESULT += texelFetch2D(tex2, posColor + radius + pos, 0).rg * EDGES;
			#endif

			SUM += EDGES;
		}
	#endif

	#ifdef Variable_Penumbra_Shadows
		shadow_RESULT += texture2D(tex1, gl_FragCoord.xy*texelSize).rgb;
		filteredShadow = shadow_RESULT/SUM;
	#endif
	
	#if indirect_effect == 1
		ssao_RESULT += texture2D(tex2, gl_FragCoord.xy*texelSize).rg;
		ambientEffects = ssao_RESULT/SUM;
	#endif
}

vec4 BilateralUpscale_VLFOG(sampler2D tex, sampler2D depth, vec2 coord, float referenceDepth){
	ivec2 scaling = ivec2(1.0/VL_RENDER_RESOLUTION);
	ivec2 posDepth  = ivec2(coord*VL_RENDER_RESOLUTION) * scaling;
	ivec2 posColor  = ivec2(coord*VL_RENDER_RESOLUTION);
 	ivec2 pos = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 getRadius[5] = ivec2[](
    	ivec2(-1,-1),
	 	ivec2( 1, 1),
		ivec2(-1, 1),
		ivec2( 1,-1),
		ivec2( 0, 0)
  );

	#ifdef DISTANT_HORIZONS
		float diffThreshold = 0.01;
	#else
		float diffThreshold = zMults.x;
	#endif

	vec4 RESULT = vec4(0.0);
	float SUM = 0.0;

	for (int i = 0; i < 4; i++) {
		
		ivec2 radius = getRadius[i];

		#ifdef DISTANT_HORIZONS
			float offsetDepth = sqrt(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling,0).a/65000.0);
		#else
			float offsetDepth = ld(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling, 0).r);
		#endif

		float EDGES = abs(offsetDepth - referenceDepth) < diffThreshold ? 1.0 : 1e-5;
		
		RESULT += texelFetch2D(tex, posColor + radius + pos, 0) * EDGES;
		
   		SUM += EDGES;
	}

	return RESULT / SUM;
}

#ifdef OVERWORLD_SHADER
float ComputeShadowMap(in vec3 projectedShadowPosition, float distortFactor, float noise, float shadowBlockerDepth, float NdotL, float maxDistFade, inout vec3 directLightColor, inout float FUNNYSHADOW, bool isSSS){

	if(maxDistFade <= 0.0) return 1.0;
	float backface = NdotL <= 0.0 ? 1.0 : 0.0;

	float shadowmap = 0.0;
	vec3 translucentTint = vec3(0.0);

	#ifdef BASIC_SHADOW_FILTER
		int samples = SHADOW_FILTER_SAMPLE_COUNT;
		float rdMul = shadowBlockerDepth*distortFactor*d0*k/shadowMapResolution;
		
		for(int i = 0; i < samples; i++){
			// vec2 offsetS = tapLocation_simple(i, 7, 9, noise) * 0.5;
			vec2 offsetS = CleanSample(i, samples - 1, noise) * 0.3;
			projectedShadowPosition.xy += rdMul*offsetS;
	#else
		int samples = 1;
	#endif
		#ifdef TRANSLUCENT_COLORED_SHADOWS
			// determine when opaque shadows are overlapping translucent shadows by getting the difference of opaque depth and translucent depth
			float shadowDepthDiff = pow(clamp((shadow2D(shadowtex1, projectedShadowPosition).x - projectedShadowPosition.z*0.6)*2.0,0.0,1.0),2.0);

			// get opaque shadow data to get opaque data from translucent shadows.
			float opaqueShadow = shadow2D(shadowtex0, projectedShadowPosition).x;
			shadowmap += max(opaqueShadow, shadowDepthDiff);

			// get translucent shadow data
			vec4 translucentShadow = texture2D(shadowcolor0, projectedShadowPosition.xy);

			// this curve simply looked the nicest. it has no other meaning.
			float shadowAlpha = pow(1.0 - pow(translucentShadow.a,5.0),0.2);

			FUNNYSHADOW = shadowAlpha;

			// normalize the color to remove luminance, and keep the hue. remove all opaque color.
			// mulitply shadow alpha to shadow color, but only on surfaces facing the lightsource. this is a tradeoff to protect subsurface scattering's colored shadow tint from shadow bias on the back of the caster.
			translucentShadow.rgb = max(normalize(translucentShadow.rgb + 0.0001), max(opaqueShadow, 1.0-shadowAlpha)) * max(shadowAlpha,  backface * (1.0 - shadowDepthDiff));

			float translucentMask = 1 - max(shadowDepthDiff-opaqueShadow, 0);
			// make it such that full alpha areas that arent in a shadow have a value of 1.0 instead of 0.0
			translucentTint += mix(translucentShadow.rgb, vec3(1.0),  opaqueShadow*shadowDepthDiff);
		#else
			shadowmap += shadow2D(shadow, projectedShadowPosition).x;
		#endif
	#ifdef BASIC_SHADOW_FILTER
		}
	#endif

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		// tint the lightsource color with the translucent shadow color
		directLightColor *= mix(vec3(1.0), translucentTint.rgb / samples, maxDistFade);
	#endif

	// return maxDistFade;
	return shadowmap / samples;
	// return mix(1.0, shadowmap / samples, maxDistFade);

}
#endif

float CustomPhase(float LightPos){

	float PhaseCurve = 1.0 - LightPos;
	float Final = exp2(sqrt(PhaseCurve) * -25.0);
	Final += exp(PhaseCurve * -10.0)*0.5;

	return Final;
}

vec3 SubsurfaceScattering_sun(vec3 albedo, float Scattering, float Density, float lightPos, float shadows, float distantSSS){
	
	Scattering *= sss_density_multiplier;

	float density = 0.0001 + Density*2.0;
	
	float scatterDepth = max(1.0 - Scattering/density,0.0);
	scatterDepth = exp((1.0-scatterDepth) * -7.0);

	scatterDepth = mix(exp(Scattering * -10.0), scatterDepth,  distantSSS);

	// this is for SSS when there is no shadow blocker depth
	#if defined BASIC_SHADOW_FILTER && defined Variable_Penumbra_Shadows
		scatterDepth = max(scatterDepth, pow(shadows, 0.5 + (1.0-Density) * 2.0)  );
	#else
		scatterDepth = exp(-7.0 * pow(1.0-shadows,3.0))*min(2.0-sss_density_multiplier,1.0);
	#endif

	// PBR at its finest :clueless:
	vec3 absorbColor = exp(max(luma(albedo) - albedo*vec3(1.0,1.1,1.2), 0.0) * -(20.0 - 19*scatterDepth) * sss_absorbance_multiplier);
	
	vec3 scatter = scatterDepth * absorbColor * pow(Density, LabSSS_Curve);

	scatter *= 1.0 + CustomPhase(lightPos)*6.0; // ~10x brighter at the peak

	return scatter;
}

vec3 SubsurfaceScattering_sky(vec3 albedo, float Scattering, float Density){
	
	Scattering *= sss_density_multiplier;
	
	float scatterDepth = 1.0 - pow(Scattering, 0.5 + Density * 2.5);

	// PBR at its finest :clueless:
	vec3 absorbColor = exp(max(luma(albedo) - albedo*vec3(1.0,1.1,1.2), 0.0)  * -(15.0 - 10.0*scatterDepth)  * sss_absorbance_multiplier * 0.01);
	
	vec3 scatter = scatterDepth * absorbColor * pow(Density, LabSSS_Curve);

	return scatter;
}

void main() {

		vec3 DEBUG = vec3(1.0);

	////// --------------- SETUP STUFF --------------- //////
		vec2 texcoord = gl_FragCoord.xy*texelSize;
	
		vec2 bnoise = blueNoise(gl_FragCoord.xy).rg;
		int seed = (frameCounter%40000) + frameCounter*2;
		float noise = fract(R2_samples(seed).y + bnoise.y);
		float noise_2 = R2_dither();

		float z0 = texture2D(depthtex0,texcoord).x;
		float z = texture2D(depthtex1,texcoord).x;
		float swappedDepth = z;

		bool isDHrange = z >= 1.0;

		#ifdef DISTANT_HORIZONS
			float DH_mixedLinearZ = sqrt(texture2D(colortex12,texcoord).a/65000.0);
			float DH_depth0 = texture2D(dhDepthTex,texcoord).x;
			float DH_depth1 = texture2D(dhDepthTex1,texcoord).x;

			float depthOpaque = z;
			float depthOpaqueL = linearizeDepthFast(depthOpaque, near, farPlane);
			
			#ifdef DISTANT_HORIZONS
			    float dhDepthOpaque = DH_depth1;
			    float dhDepthOpaqueL = linearizeDepthFast(dhDepthOpaque, dhNearPlane, dhFarPlane);

				if (depthOpaque >= 1.0 || (dhDepthOpaqueL < depthOpaqueL && dhDepthOpaque > 0.0)){
			        depthOpaque = dhDepthOpaque;
			        depthOpaqueL = dhDepthOpaqueL;
			    }
			#endif

			swappedDepth = depthOpaque;
		#else
			float DH_depth0 = 0.0;
			float DH_depth1 = 0.0;
		#endif

	


	////// --------------- UNPACK OPAQUE GBUFFERS --------------- //////
	
		vec4 data = texture2D(colortex1,texcoord);

		vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y)); // albedo, masks
		vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w)); // normals, lightmaps
		// vec4 dataUnpacked2 = vec4(decodeVec2(data.z),decodeVec2(data.w));

		vec3 albedo = toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));
		vec3 normal = decode(dataUnpacked0.yw);
		vec2 lightmap = dataUnpacked1.yz;
		
		lightmap.xy = min(max(lightmap.xy - 0.05,0.0)*1.06,1.0); // small offset to hide flickering from precision error in the encoding/decoding on values close to 1.0 or 0.0
		
		#if !defined OVERWORLD_SHADER
			lightmap.y = 1.0;
		#endif
		
		// lightmap.y = 0.0;
		// if(isDHrange) lightmap.y = pow(lightmap.y,25);
		// if(isEyeInWater == 1) lightmap.y = max(lightmap.y, 0.75);

	////// --------------- UNPACK MISC --------------- //////
	
		vec4 SpecularTex = texture2D(colortex8,texcoord);
		float LabSSS = clamp((-65.0 + SpecularTex.z * 255.0) / 190.0 ,0.0,1.0);	

		vec4 normalAndAO = texture2D(colortex15,texcoord);
		vec3 FlatNormals = normalAndAO.rgb * 2.0 - 1.0;
		vec3 slopednormal = normal;

		float vanilla_AO = z < 1.0 ? clamp(normalAndAO.a,0,1) : 0.0;
		normalAndAO.a = clamp(pow(normalAndAO.a*5,4),0,1);

		if(isDHrange){
			FlatNormals = normal;
			normal = viewToWorld(normal);
			slopednormal = normal;
		}


	////// --------------- MASKS/BOOLEANS --------------- //////
		// 1.0-0.8 ???
		// 0.75 = hand mask
		// 0.60 = grass mask
		// 0.55 = leaf mask (for ssao-sss)
		// 0.50 = lightning bolt mask
		// 0.45 = entity mask
		float opaqueMasks = dataUnpacked1.w;
		// 1.0 = water mask
		// 0.9 = entity mask
		// 0.8 = reflective entities
		// 0.7 = reflective blocks
  		float translucentMasks = texture2D(colortex7, texcoord).a;

		bool isWater = translucentMasks > 0.99;
		// bool isReflectiveEntity = abs(translucentMasks - 0.8) < 0.01;
		// bool isReflective = abs(translucentMasks - 0.7) < 0.01 || isWater || isReflectiveEntity;
		// bool isEntity = abs(translucentMasks - 0.9) < 0.01 || isReflectiveEntity;

		bool lightningBolt = abs(opaqueMasks-0.5) <0.01;
		bool isLeaf = abs(opaqueMasks-0.55) <0.01;
		bool entities = abs(opaqueMasks-0.45) < 0.01;	
		bool isGrass = abs(opaqueMasks-0.60) < 0.01;
		bool hand = abs(opaqueMasks-0.75) < 0.01 && z < 1.0;
		// bool blocklights = abs(opaqueMasks-0.8) <0.01;


		if(hand){
			convertHandDepth(z);
			convertHandDepth(z0);
		}

		#ifdef DISTANT_HORIZONS
			vec3 viewPos = toScreenSpace_DH(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5, z, DH_depth1);
		#else
			vec3 viewPos = toScreenSpace(vec3(texcoord/RENDER_SCALE - TAA_Offset*texelSize*0.5,z));
		#endif
		
		vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos;
		vec3 feetPlayerPos_normalized = normVec(feetPlayerPos);

		#ifdef POM
			#ifdef Horrible_slope_normals
    			vec3 ApproximatedFlatNormal = normalize(cross(dFdx(feetPlayerPos), dFdy(feetPlayerPos))); // it uses depth that has POM written to it.
				slopednormal = normalize(clamp(normal, ApproximatedFlatNormal*2.0 - 1.0, ApproximatedFlatNormal*2.0 + 1.0) );
			#endif
		#endif
	////// --------------- COLORS --------------- //////

		float dirtAmount = Dirt_Amount + 0.01;
		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;

		vec3 Absorbtion = vec3(1.0);
		vec3 AmbientLightColor = vec3(0.0);
		vec3 MinimumLightColor = vec3(1.0);
		vec3 Indirect_lighting = vec3(0.0);
		vec3 Indirect_SSS = vec3(0.0);
		
		vec3 DirectLightColor = vec3(0.0);
		vec3 Direct_lighting = vec3(0.0);
		vec3 Direct_SSS = vec3(0.0);
		float cloudShadow = 1.0;
		float Shadows = 1.0;
		float NdotL = 1.0;
		float lightLeakFix = clamp(pow(eyeBrightnessSmooth.y/240. + lightmap.y,2.0) ,0.0,1.0);

		#ifdef OVERWORLD_SHADER
			DirectLightColor = lightCol.rgb / 80.0;
			AmbientLightColor = averageSkyCol_Clouds / 30.0;
			
			#ifdef PER_BIOME_ENVIRONMENT
				// BiomeSunlightColor(DirectLightColor);
				vec3 biomeDirect = DirectLightColor; 
				vec3 biomeIndirect = AmbientLightColor;
				float inBiome = BiomeVLFogColors(biomeDirect, biomeIndirect);

				float maxDistance = inBiome * min(max(1.0 -  length(feetPlayerPos)/(32*8),0.0)*2.0,1.0);
				DirectLightColor = mix(DirectLightColor, biomeDirect, maxDistance);
			#endif

			bool inShadowmapBounds = false;
		#endif

		MinimumLightColor = MinimumLightColor + 0.7 * MinimumLightColor * dot(slopednormal, feetPlayerPos_normalized);

	////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////	START DRAW	    ////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////
	if (swappedDepth >= 1.0) {
		vec3 Background = vec3(0.0);

		#ifdef OVERWORLD_SHADER

			float atmosphereGround = 1.0 - exp2(-50.0 * pow(clamp(feetPlayerPos_normalized.y+0.025,0.0,1.0),2.0)  ); // darken the ground in the sky.
			
			#if RESOURCEPACK_SKY == 1 || RESOURCEPACK_SKY == 0 || RESOURCEPACK_SKY == 3
				// vec3 orbitstar = vec3(feetPlayerPos_normalized.x,abs(feetPlayerPos_normalized.y),feetPlayerPos_normalized.z); orbitstar.x -= WsunVec.x*0.2;
				vec3 orbitstar = normalize(mat3(gbufferModelViewInverse) * toScreenSpace(vec3(texcoord/RENDER_SCALE,1.0)));
				float radiance = 2.39996 - (worldTime + worldDay*24000.0) / 24000.0;
				// float radiance = 2.39996 + frameTimeCounter;
				mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));
				
				orbitstar.xy *= rotationMatrix;

				Background += stars(orbitstar) * 10.0 * clamp(-unsigned_WsunVec.y*2.0,0.0,1.0);

				#if !defined ambientLight_only && (RESOURCEPACK_SKY == 1 || RESOURCEPACK_SKY == 0)
					Background += drawSun(dot(lightCol.a * WsunVec, feetPlayerPos_normalized),0, DirectLightColor,vec3(0.0));
					Background += drawMoon(feetPlayerPos_normalized,  lightCol.a * WsunVec, DirectLightColor*20, Background); 
				#endif

				Background *= atmosphereGround;
			#endif

			vec3 Sky = skyFromTex(feetPlayerPos_normalized, colortex4)/30.0 * Sky_Brightness;
			Background += Sky;
			
		#endif

		#if RESOURCEPACK_SKY == 1 || RESOURCEPACK_SKY == 2 || RESOURCEPACK_SKY == 3
			vec3 resourcePackskyBox = toLinear(texture2D(colortex10, texcoord).rgb * 5.0) * 15.0 * clamp(unsigned_WsunVec.y*2.0,0.1,1.0);

			#ifdef SKY_GROUND
				resourcePackskyBox *= atmosphereGround;
			#endif

			Background += resourcePackskyBox;
		#endif

		#if defined OVERWORLD_SHADER && defined VOLUMETRIC_CLOUDS && !defined CLOUDS_INTERSECT_TERRAIN
			vec4 Clouds = texture2D_bicubic_offset(colortex0, texcoord*CLOUDS_QUALITY, noise, RENDER_SCALE.x);
			Background = Background * Clouds.a + Clouds.rgb;
		#endif

		gl_FragData[0].rgb = clamp(fp10Dither(Background, triangularize(noise_2)), 0.0, 65000.);

	} else {

		feetPlayerPos += gbufferModelViewInverse[3].xyz;

	////////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////	    FILTER STUFF      //////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////
		
		vec3 filteredShadow = vec3(1.412,1.0,0.0);
		vec2 SSAO_SSS = vec2(1.0);
		
		#if defined DISTANT_HORIZONS && defined DH_AMBIENT_OCCLUSION
			BilateralUpscale_REUSE_Z(colortex3,	colortex14, colortex12, gl_FragCoord.xy-1.5, DH_mixedLinearZ, SSAO_SSS, filteredShadow, hand);
		#else
			BilateralUpscale_REUSE_Z(colortex3,	colortex14, depthtex0, gl_FragCoord.xy-1.5, ld(z0), SSAO_SSS, filteredShadow, hand);
		#endif
	
		float ShadowBlockerDepth = filteredShadow.y;

	
	////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	MAJOR LIGHTSOURCE STUFF 	////////////////////////
	////////////////////////////////////////////////////////////////////////////////////
	
	#ifdef OVERWORLD_SHADER
		float LM_shadowMapFallback = min(max(lightmap.y-0.8, 0.0) * 25,1.0);

		float LightningPhase = 0.0;
		vec3 LightningFlashLighting = Iris_Lightningflash(feetPlayerPos, lightningBoltPosition.xyz, slopednormal, LightningPhase) * pow(lightmap.y,10);

		NdotL = clamp((-15 + dot(slopednormal, WsunVec)*255.0) / 240.0  ,0.0,1.0);
		// NdotL = 1;
		float flatNormNdotL = clamp((-15 + dot(viewToWorld(FlatNormals), WsunVec)*255.0) / 240.0  ,0.0,1.0);
		
		// setup shadow projection
		vec3 shadowPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
		if(!hand) GriAndEminShadowFix(shadowPlayerPos, viewToWorld(FlatNormals), vanilla_AO, lightmap.y);
		
		vec3 projectedShadowPosition = mat3(shadowModelView) * shadowPlayerPos + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3_old(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		#if OPTIMIZED_SHADOW_DISTANCE > 0

			float shadowMapFalloff = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / (shadowDistance+16.0),0.0)*5.0,1.0));
			float shadowMapFalloff2 = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / shadowDistance,0.0)*5.0,1.0));

		#else
			vec3 shadowEdgePos = projectedShadowPosition * vec3(0.4,0.4,0.5/6.0) + vec3(0.5,0.5,0.12);
      		float fadeLength = max((shadowDistance/256)*30,10.0); 

      		vec3 cubicRadius = clamp(   min((1.0-shadowEdgePos)*fadeLength, shadowEdgePos*fadeLength),0.0,1.0);
      		float shadowmapFade = cubicRadius.x*cubicRadius.y*cubicRadius.z;

        	shadowmapFade = 1.0 - pow(1.0-pow(shadowmapFade,1.5),3.0);

			float shadowMapFalloff = shadowmapFade;
			float shadowMapFalloff2 = shadowmapFade;
		#endif

		// un-distort
		#ifdef DISTORT_SHADOWMAP
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;
		#else
			float distortFactor = 1.0;
		#endif

		projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5) ;

		float ShadowAlpha = 0.0; // this is for subsurface scattering later.
		Shadows = ComputeShadowMap(projectedShadowPosition, distortFactor, noise_2, filteredShadow.x, flatNormNdotL, shadowMapFalloff, DirectLightColor, ShadowAlpha, LabSSS > 0.0);

		// transition to fallback lightmap shadow mask.
		Shadows = mix(isWater ? lightLeakFix : LM_shadowMapFallback, Shadows, shadowMapFalloff);

		#ifdef OLD_LIGHTLEAK_FIX
			if (isEyeInWater == 0) Shadows *= lightLeakFix; // light leak fix
		#endif
	#endif
	
	////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////	UNDER WATER SHADING		////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////

 	if ((isEyeInWater == 0 && isWater) || (isEyeInWater == 1 && !isWater)){
		#ifdef DISTANT_HORIZONS
			vec3 viewPos0 = toScreenSpace_DH(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5, z0, DH_depth0);
		#else
			vec3 viewPos0 = toScreenSpace(vec3(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5,z0));
		#endif

		float Vdiff = distance(viewPos, viewPos0)*mix(5.0,2.0,clamp(pow(eyeBrightnessSmooth.y/240. + lightmap.y,2.0) ,0.0,1.0));
		float estimatedDepth = Vdiff * abs(feetPlayerPos_normalized.y);	//assuming water plane

		// make it such that the estimated depth flips to be correct when entering water.
		if (isEyeInWater == 1){
			estimatedDepth = 40.0 * pow(max(1.0-lightmap.y,0.0),2.0);
			MinimumLightColor = vec3(10.0);
		}

		float depthfalloff = 1.0 - clamp(exp(-0.1*estimatedDepth),0.0,1.0);
		
		float estimatedSunDepth = Vdiff; //assuming water plane
		Absorbtion = mix(exp(-2.0 * totEpsilon * estimatedDepth), exp(-8.0 * totEpsilon), depthfalloff);

		// apply caustics to the lighting, and make sure they dont look weird
		DirectLightColor *= mix(1.0, waterCaustics(feetPlayerPos + cameraPosition, WsunVec)*WATER_CAUSTICS_BRIGHTNESS + 0.25, clamp(estimatedDepth,0,1));
	}

	#ifdef END_SHADER
		float vortexBounds = clamp(vortexBoundRange - length(feetPlayerPos+cameraPosition), 0.0,1.0);
        vec3 lightPos = LightSourcePosition(feetPlayerPos+cameraPosition, cameraPosition,vortexBounds);

		float lightningflash = texelFetch2D(colortex4,ivec2(1,1),0).x/150.0;
		vec3 lightColors = LightSourceColors(vortexBounds, lightningflash);
		
		float end_NdotL = clamp(dot(slopednormal, normalize(-lightPos))*0.5+0.5,0.0,1.0);
		end_NdotL *= end_NdotL;

		float fogShadow = GetCloudShadow(feetPlayerPos+cameraPosition, lightPos);
		float endPhase = endFogPhase(lightPos);

		Direct_lighting += lightColors * endPhase * end_NdotL * fogShadow;
		AmbientLightColor += lightColors * (endPhase*endPhase) * (1.0-exp(vec3(0.6,2.0,2) * -(endPhase*0.1))) ;
	#endif
	

	/////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	INDIRECT LIGHTING 	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////

		#if defined OVERWORLD_SHADER
			float skylight = 1.0;
		
			#if indirect_effect == 0 || indirect_effect == 1 || indirect_effect == 2
				float SkylightDir = (slopednormal / dot(abs(slopednormal),vec3(1.0))).y*1.5;
				if(isGrass) SkylightDir = 1.5;

				skylight = max(pow(viewToWorld(FlatNormals).y*0.5+0.5,0.1) + SkylightDir, 0.2 + (1-lightmap.y)*0.8);

				#if indirect_effect == 1
					skylight =  min(skylight, mix(0.95, 2.5, pow(1-pow(1-SSAO_SSS.x, 0.5),2.0)	));
				#endif
			#endif

			#if indirect_effect == 3 || indirect_effect == 4
				skylight = 2.5;
			#endif
			
			Indirect_lighting += doIndirectLighting(AmbientLightColor * skylight, MinimumLightColor, lightmap.y);

		#endif

		#ifdef NETHER_SHADER
			Indirect_lighting = skyCloudsFromTexLOD2(normal, colortex4, 6).rgb / 30.0;
			vec3 up = skyCloudsFromTexLOD2(vec3(0.0,1.0,0.0), colortex4, 6).rgb / 30.0;
			
			#if indirect_effect == 1
				Indirect_lighting = mix(up, Indirect_lighting,  clamp(pow(1.0-pow(1.0-SSAO_SSS.x, 0.5),2.0),0.0,1.0));
			#endif
			
			AmbientLightColor = Indirect_lighting / 5.0;
		#endif
		
		#ifdef END_SHADER
			Indirect_lighting = vec3(0.3,0.6,1.0) * 0.5;
			
			Indirect_lighting = Indirect_lighting + 0.7*mix(-Indirect_lighting, Indirect_lighting * dot(slopednormal, feetPlayerPos_normalized), clamp(pow(1.0-pow(1.0-SSAO_SSS.x, 0.5),2.0),0.0,1.0));
		#endif
		
		#ifdef IS_LPV_ENABLED
			vec3 normalOffset = vec3(0.0);

			if (any(greaterThan(abs(FlatNormals), vec3(1.0e-6))))
				normalOffset = 0.5*viewToWorld(FlatNormals);

			#if LPV_NORMAL_STRENGTH > 0
				vec3 texNormalOffset = -normalOffset + slopednormal;
				normalOffset = mix(normalOffset, texNormalOffset, (LPV_NORMAL_STRENGTH*0.01));
			#endif

			vec3 lpvPos = GetLpvPosition(feetPlayerPos) + normalOffset;
		#else
			const vec3 lpvPos = vec3(0.0);
		#endif

		vec3 blockLightColor = doBlockLightLighting( vec3(TORCH_R,TORCH_G,TORCH_B), lightmap.x, exposure, feetPlayerPos, lpvPos);
		Indirect_lighting += blockLightColor;

	/////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	EFFECTS FOR INDIRECT	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////

		float SkySSS = 1.0;
		vec3 AO = vec3(1.0);

		#if indirect_effect == 0
			AO = vec3(pow(1.0 - vanilla_AO*vanilla_AO,5.0));
			Indirect_lighting *= AO;
		#endif

		#if indirect_effect == 1
			SkySSS = SSAO_SSS.y;

			float vanillaAO_curve = pow(1.0 - vanilla_AO*vanilla_AO,5.0);
			float SSAO_curve = pow(SSAO_SSS.x,6.0);

			// use the min of vanilla ao so they dont overdarken eachother
			AO = vec3( min(vanillaAO_curve, SSAO_curve) );
			Indirect_lighting *= AO;
		#endif

		// // GTAO... this is so dumb but whatevverrr
		#if indirect_effect == 2
			float vanillaAO_curve = pow(1.0 - vanilla_AO*vanilla_AO,5.0);

			vec2 r2 = fract(R2_samples((frameCounter%40000) + frameCounter*2) + bnoise);
			float GTAO =  !hand ? ambient_occlusion(vec3(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5, z), viewPos, worldToView(slopednormal), r2) : 1.0;
			
			AO = vec3(min(vanillaAO_curve,GTAO));
			
			Indirect_lighting *= AO;
		#endif

		// RTAO and/or SSGI
		#if indirect_effect == 3 || indirect_effect == 4
			if(!hand) Indirect_lighting = ApplySSRT(Indirect_lighting, blockLightColor, MinimumLightColor, viewPos, normal, vec3(bnoise, noise_2), lightmap.y, isGrass, isDHrange);
		#endif

		#if defined END_SHADER
			Direct_lighting *= AO;
		#endif

	////////////////////////////////////////////////////////////////////////////////
	/////////////////////////	SUB SURFACE SCATTERING	////////////////////////////
	////////////////////////////////////////////////////////////////////////////////
	
	/////////////////////////////	SKY SSS		/////////////////////////////
		#if defined Ambient_SSS && defined OVERWORLD_SHADER && indirect_effect == 1
			if (!hand){
				vec3 ambientColor = (AmbientLightColor*2.5) * ambient_brightness; // x2.5 to match the brightness of upfacing skylight

				Indirect_SSS = SubsurfaceScattering_sky(albedo, SkySSS, LabSSS);
				Indirect_SSS *= lightmap.y*lightmap.y*lightmap.y;
				Indirect_SSS *= AO;

				// apply to ambient light.
				Indirect_lighting = max(Indirect_lighting, Indirect_SSS * ambientColor * ambientsss_brightness);

				// #ifdef OVERWORLD_SHADER
				// 	if(LabSSS > 0.0) Indirect_lighting += (1.0-SkySSS) * LightningPhase * lightningEffect *  pow(lightmap.y,10);
				// #endif
			}
		#endif
	
	////////////////////////////////	SUN SSS		////////////////////////////////
		#if SSS_TYPE != 0 && defined OVERWORLD_SHADER

			float sunSSS_density = LabSSS;
			float SSS_shadow = ShadowAlpha * Shadows;
			
			#ifdef DISTANT_HORIZONS
				shadowMapFalloff2 = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / min(shadowDistance, max(far-32.0,32.0)),0.0)*5.0,1.0));
			#endif

			#ifndef RENDER_ENTITY_SHADOWS
				if(entities) sunSSS_density = 0.0;
			#endif
			
			#ifdef SCREENSPACE_CONTACT_SHADOWS
				vec2 SS_directLight = SSRT_Shadows(toScreenSpace_DH(texcoord/RENDER_SCALE, z, DH_depth1), isDHrange, normalize(WsunVec*mat3(gbufferModelViewInverse)), interleaved_gradientNoise(), sunSSS_density > 0.0 && shadowMapFalloff2 < 1.0, hand);
				
				// combine shadowmap with a minumum shadow determined by the screenspace shadows.
				Shadows = min(Shadows, SS_directLight.r);
				// Shadows = SS_directLight.r;
				
				// combine shadowmap blocker depth with a minumum determined by the screenspace shadows, starting after the shadowmap ends
				ShadowBlockerDepth = mix(SS_directLight.g, ShadowBlockerDepth, shadowMapFalloff2);
				// ShadowBlockerDepth = max( SS_directLight.g,0.0);
			#endif

			
			Direct_SSS = SubsurfaceScattering_sun(albedo, ShadowBlockerDepth, sunSSS_density, clamp(dot(feetPlayerPos_normalized, WsunVec),0.0,1.0), SSS_shadow, shadowMapFalloff2);

			Direct_SSS *= lightLeakFix;

			#ifndef SCREENSPACE_CONTACT_SHADOWS
				Direct_SSS = mix(vec3(0.0), Direct_SSS, shadowMapFalloff2);
			#endif

			#ifdef CLOUDS_SHADOWS
				cloudShadow = GetCloudShadow(feetPlayerPos);
				Shadows *= cloudShadow;
				Direct_SSS *= cloudShadow;
			#endif

		#endif

	/////////////////////////////////////////////////////////////////////////
	/////////////////////////////	FINALIZE	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////


		#ifdef SSS_view
			albedo = vec3(1);
			NdotL = 0;
		#endif

		#ifdef OVERWORLD_SHADER
			Direct_lighting =  max(DirectLightColor * NdotL * Shadows, DirectLightColor * Direct_SSS);
		#endif

		gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * albedo;

		#ifdef Specular_Reflections	
			vec2 specularNoises = vec2(noise, R2_dither());
			DoSpecularReflections(gl_FragData[0].rgb, viewPos, feetPlayerPos_normalized, WsunVec, specularNoises, normal, SpecularTex.r, SpecularTex.g, albedo, DirectLightColor*Shadows*NdotL, lightmap.y, hand);
		#endif
		
		Emission(gl_FragData[0].rgb, albedo, SpecularTex.a, exposure);
		
		if(lightningBolt) gl_FragData[0].rgb = vec3(77.0, 153.0, 255.0);

		gl_FragData[0].rgb *= Absorbtion;
	}

	if(translucentMasks > 0.0){
		#ifdef DISTANT_HORIZONS
			vec4 vlBehingTranslucents = BilateralUpscale_VLFOG(colortex13, colortex12, gl_FragCoord.xy - 1.5, sqrt(texture2D(colortex12,texcoord).a/65000.0));
    	#else
    		vec4 vlBehingTranslucents = BilateralUpscale_VLFOG(colortex13, depthtex1, gl_FragCoord.xy - 1.5, ld(z));
    	#endif

    	gl_FragData[0].rgb = gl_FragData[0].rgb * vlBehingTranslucents.a + vlBehingTranslucents.rgb;
	}

	////// DEBUG VIEW STUFF
	#if DEBUG_VIEW == debug_SHADOWMAP	
		gl_FragData[0].rgb = vec3(0.5) + vec3(1.0) * Shadows * 30.0;
	#endif
	#if DEBUG_VIEW == debug_NORMALS
		if(swappedDepth >= 1.0) Direct_lighting = vec3(1.0);
		gl_FragData[0].rgb = normal ;
	#endif
	#if DEBUG_VIEW == debug_SPECULAR
		if(swappedDepth >= 1.0) Direct_lighting = vec3(1.0);
		gl_FragData[0].rgb = SpecularTex.rgb;
	#endif
	#if DEBUG_VIEW == debug_INDIRECT
		if(swappedDepth >= 1.0) Direct_lighting = vec3(5.0);
		gl_FragData[0].rgb = Indirect_lighting;
	#endif
	#if DEBUG_VIEW == debug_DIRECT
		if(swappedDepth >= 1.0) Direct_lighting = vec3(15.0);
		gl_FragData[0].rgb = Direct_lighting + 0.5;
	#endif
	#if DEBUG_VIEW == debug_VIEW_POSITION
		gl_FragData[0].rgb = viewPos * 0.001;
	#endif
	#if DEBUG_VIEW == debug_FILTERED_STUFF
	 	// if(hideGUI == 1)  gl_FragData[0].rgb = vec3(1)	* (1.0 - SSAO_SSS.y);
	 	// if(hideGUI == 0)  gl_FragData[0].rgb = vec3(1)	* (1.0 - SSAO_SSS.x);
	 	if(hideGUI == 0)  gl_FragData[0].rgb = vec3(1)	* exp(-10*filteredShadow.y);//exp(-7*(1-clamp(1.0 - filteredShadow.x,0.0,1.0)));
	#endif
	// gl_FragData[0].rgb = albedo*30;
	// gl_FragData[0].rgb = vec3(1) * Shadows;
	// if(swappedDepth >= 1.0) gl_FragData[0].rgb = vec3(0.1);
	// gl_FragData[0].rgb = vec3(1) * ld(texture2D(depthtex1, texcoord).r);
	// if(texcoord.x > 0.5 )gl_FragData[0].rgb = vec3(1) * ld(texture2D(depthtex0, texcoord).r);



	/* DRAWBUFFERS:3 */
}