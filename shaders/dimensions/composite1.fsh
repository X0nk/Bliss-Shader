#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"


vec3 saturation(inout vec3 color, float saturation){


 float luminance = dot(color, vec3(0.21, 0.72, 0.07));
 
 vec3 difference = color - luminance;
 
 return color = color + difference*saturation;
}

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
	uniform sampler2D colortex4;
	const bool colortex4MipmapEnabled = true;
	uniform vec3 lightningEffect;
	// #define LIGHTSOURCE_REFLECTION
#endif

#ifdef END_SHADER
	uniform float nightVision;
	uniform sampler2D colortex4;
	uniform vec3 lightningEffect;
	
	flat varying float Flashing;
	// #define LIGHTSOURCE_REFLECTION
#endif

uniform int hideGUI;
uniform sampler2D noisetex; //noise
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
// uniform sampler2D depthtex2;

// #ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
// #endif

uniform sampler2D colortex0; //clouds
uniform sampler2D colortex1; //albedo(rgb),material(alpha) RGBA16
uniform sampler2D colortex2; //translucents(rgba)
uniform sampler2D colortex3; //filtered shadowmap(VPS)
// uniform sampler2D colortex4; //LUT(rgb), quarter res depth(alpha)
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
// flat varying vec3 unsigned_WsunVec;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 feetPlayerPos = p * 2. - 1.;
    vec4 viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
    return viewPos.xyz / viewPos.w;
}




#include "/lib/color_transforms.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/sky_gradient.glsl"

#include "/lib/Shadow_Params.glsl"
#include "/lib/Shadows.glsl"
#include "/lib/stars.glsl"

#ifdef OVERWORLD_SHADER
	#include "/lib/volumetricClouds.glsl"
#endif

#include "/lib/diffuse_lighting.glsl"

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
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
#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)
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



float facos(float sx){
    float x = clamp(abs( sx ),0.,1.);
    return sqrt( 1. - x ) * ( -0.16882 * x + 1.56734 );
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
    feetPlayerPos = diagonal3(DH_shadowProjection) * feetPlayerPos + DH_shadowProjection[3].xyz;

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
		vec3 dVWorld = -mat3(gbufferModelViewInverse) * (rayEnd - rayStart) * maxZ;
		rayLength *= maxZ;
		estEndDepth *= maxZ;
		estSunDepth *= maxZ;
		vec3 absorbance = vec3(1.0);
		vec3 vL = vec3(0.0);


		float expFactor = 11.0;
		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;
		for (int i=0;i<spCount;i++) {
			float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
			float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);
			vec3 spPos = start.xyz + dV*d;
			progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

			vec3 ambientMul = exp(-max(estEndDepth * d,0.0) * waterCoefs);

			vec3 light =  (ambientMul*ambient) * scatterCoef;

			vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs *absorbance;
			absorbance *= exp(-dd * rayLength * waterCoefs);
		}
		inColor += vL;
}

#ifdef OVERWORLD_SHADER


float fogPhase(float lightPoint){
	float linear = 1.0 - clamp(lightPoint*0.5+0.5,0.0,1.0);
	float linear2 = 1.0 - clamp(lightPoint,0.0,1.0);

	float exponential = exp2(pow(linear,0.3) * -15.0 ) * 1.5;
	exponential += sqrt(exp2(sqrt(linear) * -12.5));

	return exponential;
}

void waterVolumetrics(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
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

	inColor *= exp(-rayLength * waterCoefs);	// No need to take the integrated value
	float phase = fogPhase(VdotL) * 5.0;
	vec3 absorbance = vec3(1.0);
	vec3 vL = vec3(0.0);

	float expFactor = 11.0;
	for (int i=0;i<spCount;i++) {
		float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);
		vec3 spPos = start.xyz + dV*d;

		vec3 progressW = start.xyz+cameraPosition+dVWorld;

		//project into biased shadowmap space
		#ifdef DISTORT_SHADOWMAP
			float distortFactor = calcDistort(spPos.xy);
		#else
			float distortFactor = 1.0;
		#endif

		vec3 pos = vec3(spPos.xy*distortFactor, spPos.z);
		float sh = 1.0;
		if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
			pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
			sh =  shadow2D( shadow, pos).x;
		}

		#ifdef VL_CLOUDS_SHADOWS
			sh *= GetCloudShadow_VLFOG(progressW,WsunVec);
		#endif

		vec3 sunMul = exp(-estSunDepth * d * waterCoefs * 1.1);
		vec3 ambientMul = exp(-estEndDepth * d * waterCoefs );

		vec3 Directlight = (lightSource * phase * sunMul) * sh;
		vec3 Indirectlight = ambient * ambientMul;

		vec3 light = (Indirectlight + Directlight) * scatterCoef;

		vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs * absorbance;
		absorbance *= exp(-waterCoefs * dd * rayLength);
	}
	inColor += vL;
}

#endif

vec2 SSRT_Shadows(vec3 viewPos, bool depthCheck, vec3 lightDir, float noise, bool isSSS){
    float steps = 16.0;
	
	float Shadow = 1.0; 
	float SSS = 0.0;
	
	float _near = near; float _far = far*4.0;

	if (depthCheck) {
		_near = dhNearPlane;
		_far = dhFarPlane;
	}

    vec3 clipPosition = toClipSpace3_DH(viewPos, depthCheck);

	//prevents the ray from going behind the camera
	float rayLength = ((viewPos.z + lightDir.z * _far*sqrt(3.)) > -_near) ?
      				  (-_near -viewPos.z) / lightDir.z : _far*sqrt(3.);

    vec3 direction = toClipSpace3_DH(viewPos + lightDir*rayLength, depthCheck) - clipPosition;  //convert to clip space
    direction.xyz = direction.xyz / max(abs(direction.x)/texelSize.x, abs(direction.y)/texelSize.y);	//fixed step size
	
	float Stepmult = depthCheck ? (isSSS ? 0.5 : 6.0) : (isSSS ? 1.0 : 3.0);

    vec3 rayDir = direction * Stepmult * vec3(RENDER_SCALE,1.0);
	
	vec3 screenPos = clipPosition * vec3(RENDER_SCALE,1.0) + rayDir*noise;
	if(isSSS) screenPos -= rayDir*0.9;

	for (int i = 0; i < int(steps); i++) {
		
		screenPos += rayDir;
		
		float samplePos = texture2D(depthtex1, screenPos.xy).x;
		
		#ifdef DISTANT_HORIZONS
			if(depthCheck) samplePos = texture2D(dhDepthTex1, screenPos.xy).x;
		#endif

		if(samplePos <= screenPos.z) {
			vec2 linearZ = vec2(linearizeDepthFast(screenPos.z, _near, _far), linearizeDepthFast(samplePos, _near, _far));
			float calcthreshold = abs(linearZ.x - linearZ.y) / linearZ.x;

			bool depthThreshold1 = calcthreshold < 0.015;
			bool depthThreshold2 = calcthreshold < 0.05;

			if (depthThreshold1) Shadow = 0.0;

			if (depthThreshold2) SSS = i/steps;
				
		}
	}

	return vec2(Shadow, SSS);
}

float CustomPhase(float LightPos){

	float PhaseCurve = 1.0 - LightPos;
	float Final = exp2(sqrt(PhaseCurve) * -25.0);
	Final += exp(PhaseCurve * -10.0)*0.5;

	return Final;
}

vec3 SubsurfaceScattering_sun(vec3 albedo, float Scattering, float Density, float lightPos){

	float labcurve = pow(Density, LabSSS_Curve);

	float density = 15.0 - labcurve*10.0;

	vec3 absorbed = max(1.0 - albedo,0.0);

	vec3 scatter = exp(Scattering * absorbed * -5.0) * exp(Scattering * -density);

	scatter *= labcurve;
	
	scatter *= 1.0 + CustomPhase(lightPos)*6.0; // ~10x brighter at the peak

	return scatter;
}

vec3 SubsurfaceScattering_sky(vec3 albedo, float Scattering, float Density){

	vec3 absorbColor = max(1.0 - albedo,0.0);
	
	vec3 scatter = vec3(1)*exp(-3.0 * (Scattering*Scattering));

	scatter *= clamp(1.0 - exp(Density * -10.0),0.0,1.0);

	return scatter;
}

void Emission(
	inout vec3 Lighting,
	vec3 Albedo,
	float Emission
){
	// if( Emission < 235.0/255.0 ) Lighting = mix(Lighting, Albedo * Emissive_Brightness, pow(Emission, Emissive_Curve)); // old method.... idk why
	if( Emission < 255.0/255.0 ) Lighting += (Albedo * Emissive_Brightness) * pow(Emission, Emissive_Curve);
}

#include "/lib/indirect_lighting_effects.glsl"
#include "/lib/PhotonGTAO.glsl"
// vec4 renderInfiniteWaterPlane(
// 	vec3 FragPosition, inout vec3 oceanNormals
// ){	

// 	float planeHeight = 20 + 0.50;
// 	float total_extinction = 1.0;
// 	vec3 color = vec3(0.0);

// 	//project pixel position into projected shadowmap space
// 	vec4 viewPos = normalize(gbufferModelViewInverse * vec4(FragPosition,1.0) );
// 	vec3 dV_view = normalize(viewPos.xyz); dV_view *= 1.0/abs(dV_view.y);
	
// 	float mult = length(dV_view);
	
// 	float startFlip = mix(max(cameraPosition.y - planeHeight,0.0), max(planeHeight - cameraPosition.y,0), clamp(dV_view.y,0,1));
// 	float signFlip = mix(-1.0, 1.0, clamp(cameraPosition.y - planeHeight,0.0,1.0)); 
// 	if(max(signFlip * normalize(dV_view).y,0.0) > 0.0) return vec4(0,0,0,1);
	
// 	vec3 progress_view = vec3(0,cameraPosition.y,0) + dV_view/abs(dV_view.y) * startFlip;

// 	oceanNormals = normalize(getWaveHeight((progress_view+cameraPosition).xz,1));

// 	vec3 Lighting = vec3(1);
// 	float object = 1;

// 	color += max(Lighting - Lighting*exp(-mult*object),0.0) * total_extinction;
// 	total_extinction *= max(exp(-mult*object),0.0);

// 	return vec4(color, total_extinction);
// }


// uniform float viewWidth;
// uniform float viewHeight;

// uniform sampler2D depthtex0;
// uniform sampler2D dhDepthTex;

// uniform mat4 gbufferProjectionInverse;
// uniform mat4 dhProjectionInverse;

// vec3 getViewPos() {
//     ivec2 uv = ivec2(gl_FragCoord.xy);
//     vec2 viewSize = vec2(viewWidth, viewHeight);
//     vec2 texcoord = gl_FragCoord.xy / viewSize;

//     vec4 viewPos = vec4(0.0);
	
//     float depth = texelFetch(depthtex0, uv, 0).r;

//     if (depth < 1.0) {
//         vec4 ndcPos = vec4(texcoord, depth, 1.0) * 2.0 - 1.0;
//         viewPos = gbufferProjectionInverse * ndcPos;
//         viewPos.xyz /= viewPos.w;
//     } else {
//         depth = texelFetch(dhDepthTex, ivec2(gl_FragCoord.xy), 0).r;
    
//         vec4 ndcPos = vec4(texcoord, depth, 1.0) * 2.0 - 1.0;
//         viewPos = dhProjectionInverse * ndcPos;
//         viewPos.xyz /= viewPos.w;
//     }

//     return viewPos.xyz;
// }

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
	// return vec4(1) * SUM;
	return RESULT / SUM;

}

void BilateralUpscale_REUSE_Z(sampler2D tex1, sampler2D tex2, sampler2D depth, vec2 coord, float referenceDepth, inout vec2 ambientEffects, inout vec3 filteredShadow){
	ivec2 scaling = ivec2(1.0);
	ivec2 posDepth  = ivec2(coord) * scaling;
	ivec2 posColor  = ivec2(coord);
  	ivec2 pos = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 getRadius[4] = ivec2[](
   	 	ivec2(-2,-2),
	  	ivec2(-2, 0),
		ivec2( 0, 0),
		ivec2( 0,-2)
  	);

	#ifdef DISTANT_HORIZONS
		float diffThreshold = 0.0005;
	#else
		float diffThreshold = 0.005;
	#endif

	vec3 shadow_RESULT = vec3(0.0);
	vec2 ssao_RESULT = vec2(0.0);
	vec4 fog_RESULT = vec4(0.0);
	float SUM = 0.0;

	for (int i = 0; i < 4; i++) {
		
		ivec2 radius = getRadius[i];

		#ifdef DISTANT_HORIZONS
			float offsetDepth = sqrt(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling,0).a/65000.0);
		#else
			float offsetDepth = ld(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling, 0).r);
		#endif

		float EDGES = abs(offsetDepth - referenceDepth) < diffThreshold ? 1.0 : 1e-5;
		// #ifdef Variable_Penumbra_Shadows
			shadow_RESULT += texelFetch2D(tex1, posColor + radius + pos, 0).rgb * EDGES;
		// #endif

		#if indirect_effect == 1
			ssao_RESULT += texelFetch2D(tex2, posColor + radius + pos, 0).rg * EDGES;
		#endif

		SUM += EDGES;
	}
	// #ifdef Variable_Penumbra_Shadows
		filteredShadow = shadow_RESULT/SUM;
	// #endif
	#if indirect_effect == 1
		ambientEffects = ssao_RESULT/SUM;
	#endif
}
vec3 ColorBoost(vec3 COLOR, float saturation){

  	float luminance = luma(COLOR);

	COLOR = normalize(COLOR+0.0001);

  	vec3 difference = COLOR - luminance;

  	return COLOR + difference*(-luminance + saturation);
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

		#if defined END_SHADER || defined NETHER_SHADER
			lightmap.y = 1.0;
		#endif

		// if(isEyeInWater == 1) lightmap.y = max(lightmap.y, 0.75);

	////// --------------- UNPACK MISC --------------- //////
	
		vec4 SpecularTex = texture2D(colortex8,texcoord);
		float LabSSS = clamp((-65.0 + SpecularTex.z * 255.0) / 190.0 ,0.0,1.0);	

		vec4 normalAndAO = texture2D(colortex15,texcoord);
		vec3 FlatNormals = normalAndAO.rgb * 2.0 - 1.0;
		vec3 slopednormal = normal;

		#ifdef POM
			#ifdef Horrible_slope_normals
    			vec3 ApproximatedFlatNormal = normalize(cross(dFdx(feetPlayerPos), dFdy(feetPlayerPos))); // it uses depth that has POM written to it.
				slopednormal = normalize(clamp(normal, ApproximatedFlatNormal*2.0 - 1.0, ApproximatedFlatNormal*2.0 + 1.0) );
			#endif
		#endif

		float vanilla_AO = z < 1.0 ? clamp(normalAndAO.a,0,1) : 0.0;
		normalAndAO.a = clamp(pow(normalAndAO.a*5,4),0,1);

		if(isDHrange){
			slopednormal = normal;
			FlatNormals = worldToView(normal);
		}


	////// --------------- MASKS/BOOLEANS --------------- //////

		float translucent_alpha = texture2D(colortex7,texcoord).a;
		bool iswater = translucent_alpha > 0.99;
		bool lightningBolt = abs(dataUnpacked1.w-0.5) <0.01;
		bool isLeaf = abs(dataUnpacked1.w-0.55) <0.01;
		bool entities = abs(dataUnpacked1.w-0.45) < 0.01;	
		// bool isBoss = abs(dataUnpacked1.w-0.60) < 0.01;
		bool isGrass = abs(dataUnpacked1.w-0.60) < 0.01;
		bool hand = abs(dataUnpacked1.w-0.75) < 0.01 && z0 < 1.0;
		// bool blocklights = abs(dataUnpacked1.w-0.8) <0.01;


		if(hand) convertHandDepth(z);
		
		#ifdef DISTANT_HORIZONS
			vec3 viewPos = toScreenSpace_DH(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5, z, DH_depth1);
		#else
			vec3 viewPos = toScreenSpace(vec3(texcoord/RENDER_SCALE - TAA_Offset*texelSize*0.5,z));
		#endif
		
		vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos;
		vec3 feetPlayerPos_normalized = normVec(feetPlayerPos);

	////// --------------- COLORS --------------- //////

		float dirtAmount = Dirt_Amount + 0.01;
		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
		vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

		#ifdef BIOME_TINT_WATER
			// yoink the biome tint written in this buffer for water only.
			if(iswater){
				vec2 translucentdata = texture2D(colortex11,texcoord).gb;
				vec3 wateralbedo = vec3(decodeVec2(translucentdata.x),decodeVec2(translucentdata.y).x);
				scatterCoef = dirtAmount * wateralbedo / 3.14;
			}
		#endif
		vec3 Absorbtion = vec3(1.0);
		vec3 AmbientLightColor = vec3(0.0);
		vec3 MinimumLightColor = vec3(1.0);
		vec3 Indirect_lighting = vec3(0.0);
		vec3 Indirect_SSS = vec3(0.0);
		
		vec3 DirectLightColor = vec3(0.0);
		vec3 Direct_lighting = vec3(0.0);
		vec3 Direct_SSS = vec3(0.0);
		float cloudShadow = 1.0;
		vec3 Shadows = vec3(1.0);
		float NdotL = 1.0;



		vec3 shadowMap = vec3(1.0);
		#ifdef DISTANT_HORIZONS_SHADOWMAP
			float shadowMapFalloff = pow(1.0-pow(1.0-min(max(1.0 - length(vec3(feetPlayerPos.x,feetPlayerPos.y/1.5,feetPlayerPos.z)) / min(shadowDistance, dhFarPlane),0.0)*5.0,1.0),2.0),2.0);
		#else
			float shadowMapFalloff = pow(1.0-pow(1.0-min(max(1.0 - length(vec3(feetPlayerPos.x,feetPlayerPos.y/1.5,feetPlayerPos.z)) / shadowDistance,0.0)*5.0,1.0),2.0),2.0);
		#endif
			float shadowMapFalloff2 = pow(1.0-pow(1.0-min(max(1.0 - length(vec3(feetPlayerPos.x,feetPlayerPos.y/1.5,feetPlayerPos.z)) / min(shadowDistance,far),0.0)*5.0,1.0),2.0),2.0);
		// shadowMapFalloff = 0;
		// shadowMapFalloff2 = 0;
		float LM_shadowMapFallback = min(max(lightmap.y-0.8, 0.0) * 25,1.0);

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

	#ifdef CLOUDS_INFRONT_OF_WORLD
		float heightRelativeToClouds = clamp(cameraPosition.y - LAYER0_minHEIGHT,0.0,1.0);
		vec4 Clouds = texture2D_bicubic_offset(colortex0, texcoord*CLOUDS_QUALITY, noise, RENDER_SCALE.x);
	#endif
	
	////////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////	    FILTER STUFF      //////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////
	
	vec3 filteredShadow = vec3(1.412,1.0,0.0);
	vec2 SSAO_SSS = vec2(1.0);
	
	#ifdef DISTANT_HORIZONS
		BilateralUpscale_REUSE_Z(colortex3,	colortex14, colortex12, gl_FragCoord.xy, DH_mixedLinearZ, SSAO_SSS, filteredShadow);
	#else
		BilateralUpscale_REUSE_Z(colortex3,	colortex14, depthtex0, gl_FragCoord.xy, ld(z0), SSAO_SSS, filteredShadow);
	#endif

	float ShadowBlockerDepth = filteredShadow.y;
	Shadows = vec3(clamp(1.0 - filteredShadow.b,0.0,1.0));
	shadowMap = vec3(Shadows);
	
	
	////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////	START DRAW	    ////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////
	if (swappedDepth >= 1.0) {
		#ifdef OVERWORLD_SHADER
			vec3 Background = vec3(0.0);

			
			#if RESOURCEPACK_SKY == 1 || RESOURCEPACK_SKY == 0
				vec3 orbitstar = vec3(feetPlayerPos_normalized.x,abs(feetPlayerPos_normalized.y),feetPlayerPos_normalized.z); orbitstar.x -= WsunVec.x*0.2;
				Background += stars(orbitstar) * 10.0;
			#endif

			#if RESOURCEPACK_SKY == 2
				Background += toLinear(texture2D(colortex10, texcoord).rgb * (255.0 * 2.0));
			#else
				#if RESOURCEPACK_SKY == 1
					Background += toLinear(texture2D(colortex10, texcoord).rgb * (255.0 * 2.0));
				#endif
				#ifndef ambientLight_only
					Background += drawSun(dot(lightCol.a * WsunVec, feetPlayerPos_normalized),0, DirectLightColor,vec3(0.0));
					Background += drawMoon(feetPlayerPos_normalized,  lightCol.a * WsunVec, DirectLightColor*20, Background); 
				#endif
			#endif

			Background *= 1.0 - exp2(-50.0 * pow(clamp(feetPlayerPos_normalized.y+0.025,0.0,1.0),2.0)  ); // darken the ground in the sky.
			
			vec3 Sky = skyFromTex(feetPlayerPos_normalized, colortex4)/30.0;
			Background += Sky;

			#ifdef VOLUMETRIC_CLOUDS
				#ifdef CLOUDS_INFRONT_OF_WORLD
					if(heightRelativeToClouds < 1.0) Background = Background * Clouds.a + Clouds.rgb;
				#else
					vec4 Clouds = texture2D_bicubic_offset(colortex0, texcoord*CLOUDS_QUALITY, noise, RENDER_SCALE.x);
					Background = Background * Clouds.a + Clouds.rgb;
				#endif
			#endif

			gl_FragData[0].rgb = clamp(fp10Dither(Background, triangularize(noise_2)), 0.0, 65000.);
		#endif

		#if defined NETHER_SHADER || defined END_SHADER
			gl_FragData[0].rgb = vec3(0);
		#endif

	} else {

		feetPlayerPos += gbufferModelViewInverse[3].xyz;
	
	////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	MAJOR LIGHTSOURCE STUFF 	////////////////////////
	////////////////////////////////////////////////////////////////////////////////////
	
	#ifdef OVERWORLD_SHADER
		float LightningPhase = 0.0;
		vec3 LightningFlashLighting = Iris_Lightningflash(feetPlayerPos, lightningBoltPosition.xyz, slopednormal, LightningPhase) * pow(lightmap.y,10);
	#endif

	#ifdef OVERWORLD_SHADER

		NdotL = clamp((-15 + dot(slopednormal, WsunVec)*255.0) / 240.0  ,0.0,1.0);

		vec3 shadowPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
		
		// if(!entities) if(!hand) 
		GriAndEminShadowFix(shadowPlayerPos, viewToWorld(FlatNormals), vanilla_AO, lightmap.y);

		vec3 projectedShadowPosition = mat3(shadowModelView) * shadowPlayerPos + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		//apply distortion
		#ifdef DISTORT_SHADOWMAP
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;
		#else
			float distortFactor = 1.0;
		#endif

		if(shadowDistanceRenderMul < 0.0) shadowMapFalloff = abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0 ? 1.0 : 0.0;

		if(shadowMapFalloff > 0.0){
			shadowMap = vec3(0.0);
			vec3 ShadowColor = vec3(0.0);

			projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);

			float biasOffset = 0.0;

			#ifdef BASIC_SHADOW_FILTER
				float rdMul = filteredShadow.x*distortFactor*d0*k/shadowMapResolution;

				for(int i = 0; i < SHADOW_FILTER_SAMPLE_COUNT; i++){
					vec2 offsetS = tapLocation_simple(i, 7, 9, noise_2) * 0.5;

					projectedShadowPosition += vec3(rdMul*offsetS, biasOffset);

					#ifdef TRANSLUCENT_COLORED_SHADOWS
						float opaqueShadow = shadow2D(shadowtex0, projectedShadowPosition).x;
						shadowMap += opaqueShadow / SHADOW_FILTER_SAMPLE_COUNT;

						vec4 translucentShadow = texture2D(shadowcolor0, projectedShadowPosition.xy);
						float shadowAlpha = clamp(1.0 - pow(translucentShadow.a,5.0),0.0,1.0);

						#if SSS_TYPE != 0
							if(LabSSS > 0.0) ShadowColor += (DirectLightColor * clamp(pow(1.0-shadowAlpha,5.0),0.0,1.0) + DirectLightColor *  translucentShadow.rgb * shadowAlpha * (1.0 - opaqueShadow)) / SHADOW_FILTER_SAMPLE_COUNT;
							else ShadowColor = DirectLightColor;
						#endif

						if(shadow2D(shadowtex1, projectedShadowPosition).x > projectedShadowPosition.z) shadowMap += (translucentShadow.rgb * shadowAlpha * (1.0 - opaqueShadow)) / SHADOW_FILTER_SAMPLE_COUNT;

					#else
						shadowMap += vec3(shadow2D(shadow, projectedShadowPosition).x / SHADOW_FILTER_SAMPLE_COUNT);
					#endif
				}
			
			#else

				#ifdef TRANSLUCENT_COLORED_SHADOWS
					float opaqueShadow = shadow2D(shadowtex0, projectedShadowPosition).x;
					shadowMap += opaqueShadow;

					vec4 translucentShadow = texture2D(shadowcolor0, projectedShadowPosition.xy);
					translucentShadow.rgb = normalize(translucentShadow.rgb + 0.0001);
					float shadowAlpha = clamp(1.0 - pow(translucentShadow.a,5.0),0.0,1.0);

					#if SSS_TYPE != 0
						if(LabSSS > 0.0) ShadowColor += DirectLightColor * (1.0 - shadowAlpha) + DirectLightColor *  translucentShadow.rgb * shadowAlpha * (1.0 - opaqueShadow);
						else ShadowColor = DirectLightColor;
					#endif

					if(shadow2D(shadowtex1, projectedShadowPosition).x > projectedShadowPosition.z) shadowMap += translucentShadow.rgb * shadowAlpha * (1.0 - opaqueShadow);

				#else
					shadowMap += shadow2D(shadow, projectedShadowPosition).x;
				#endif
			#endif

			#ifdef TRANSLUCENT_COLORED_SHADOWS
				DirectLightColor = ShadowColor;
			#endif

			Shadows = shadowMap;
		}

		if(!iswater) Shadows = mix(vec3(LM_shadowMapFallback), Shadows, shadowMapFalloff2);

		#ifdef OLD_LIGHTLEAK_FIX
			if (isEyeInWater == 0) Shadows *=  clamp(pow(eyeBrightnessSmooth.y/240. + lightmap.y,2.0) ,0.0,1.0); // light leak fix
		#endif

	
	////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////	UNDER WATER SHADING		////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////
 		if ((isEyeInWater == 0 && iswater) || (isEyeInWater == 1 && !iswater)){
			#ifdef DISTANT_HORIZONS
				vec3 viewPos0 = toScreenSpace_DH(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5, z0, DH_depth0);
			#else
				vec3 viewPos0 = toScreenSpace(vec3(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5,z0));
			#endif

			float Vdiff = distance(viewPos, viewPos0)*2.0;
			float estimatedDepth = Vdiff * abs(feetPlayerPos_normalized.y);	//assuming water plane

			// make it such that the estimated depth flips to be correct when entering water.
			if (isEyeInWater == 1){
				estimatedDepth = 40.0 * pow(max(1.0-lightmap.y,0.0),2.0);
				MinimumLightColor = vec3(10.0);
			}

			float depthfalloff = 1.0 - clamp(exp(-0.1*estimatedDepth),0.0,1.0);
			

			float estimatedSunDepth = Vdiff; //assuming water plane
			Absorbtion = mix(exp(-2.0 * totEpsilon * estimatedDepth), exp(-8.0 * totEpsilon), depthfalloff);

			DirectLightColor *= Absorbtion;
			AmbientLightColor *= Absorbtion;

			// apply caustics to the lighting, and make sure they dont look weird
			DirectLightColor *= mix(1.0, waterCaustics(feetPlayerPos + cameraPosition, WsunVec)*WATER_CAUSTICS_BRIGHTNESS + 0.25, clamp(estimatedDepth,0,1));
		}

	////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////	SUN SSS		////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////

		#if SSS_TYPE != 0


			#ifdef DISTANT_HORIZONS
				shadowMapFalloff = pow(1.0-pow(1.0-min(max(1.0 - length(vec3(feetPlayerPos.x,feetPlayerPos.y/1.5,feetPlayerPos.z)) / min(shadowDistance, max(far-32,0.0)),0.0)*5.0,1.0),2.0),2.0);
			#endif

			#if defined DISTANT_HORIZONS_SHADOWMAP && defined Variable_Penumbra_Shadows
				ShadowBlockerDepth = mix(pow(1.0 - Shadows.x,2.0), ShadowBlockerDepth, shadowMapFalloff);
			#endif

			#if !defined Variable_Penumbra_Shadows
				ShadowBlockerDepth = pow(1.0 - clamp(Shadows.x,0,1),2.0);
			#endif


			float sunSSS_density = LabSSS;
			#ifndef RENDER_ENTITY_SHADOWS
				if(entities) sunSSS_density = 0.0;
			#endif

			if (!hand){
				#ifdef SCREENSPACE_CONTACT_SHADOWS
					
					vec2 SS_directLight = SSRT_Shadows(toScreenSpace_DH(texcoord/RENDER_SCALE, z, DH_depth1), isDHrange, normalize(WsunVec*mat3(gbufferModelViewInverse)), interleaved_gradientNoise(), sunSSS_density > 0.0);
					
					Shadows = min(Shadows, SS_directLight.r);
					ShadowBlockerDepth = mix(SS_directLight.g, ShadowBlockerDepth, shadowMapFalloff);

				#else
					ShadowBlockerDepth = mix(1.0, ShadowBlockerDepth, shadowMapFalloff);
				#endif
					
				Direct_SSS = SubsurfaceScattering_sun(albedo, ShadowBlockerDepth, sunSSS_density, clamp(dot(feetPlayerPos_normalized, WsunVec),0.0,1.0));
				
				Direct_SSS *= mix(LM_shadowMapFallback, 1.0, shadowMapFalloff);
				if (isEyeInWater == 0) Direct_SSS *= clamp(pow(eyeBrightnessSmooth.y/240. + lightmap.y,2.0) ,0.0,1.0); // light leak fix
			}	
		#endif

		#ifdef CLOUDS_SHADOWS
			cloudShadow = GetCloudShadow(feetPlayerPos);
			Shadows *= cloudShadow;
			Direct_SSS *= cloudShadow;
		#endif
	#endif

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
		
		Direct_lighting *= Absorbtion;
	#endif
	
	/////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	INDIRECT LIGHTING 	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////

		#if defined OVERWORLD_SHADER && (indirect_effect == 0 || indirect_effect == 1)

			vec3 ambientcoefs = slopednormal / dot(abs(slopednormal), vec3(1));

			float SkylightDir = ambientcoefs.y*1.5;
			if(isGrass) SkylightDir = 1.25;

			float skylight = max(pow(viewToWorld(FlatNormals).y*0.5+0.5,0.1) + SkylightDir, 0.2 + (1.0-lightmap.y)*0.8) ;
		
			#if indirect_effect == 1
				skylight = min(skylight, (SSAO_SSS.x*SSAO_SSS.x*SSAO_SSS.x) * 2.5);
			#endif

			Indirect_lighting = AmbientLightColor * skylight;
			
		#endif

		#ifdef NETHER_SHADER
			// Indirect_lighting = skyCloudsFromTexLOD2(normal, colortex4, 6).rgb / 15.0;

			// vec3 up 	= skyCloudsFromTexLOD2(vec3( 0, 1, 0), colortex4, 6).rgb/ 30.0;
			// vec3 down 	= skyCloudsFromTexLOD2(vec3( 0,-1, 0), colortex4, 6).rgb/ 30.0;

			// up   *= pow( max( slopednormal.y, 0), 2);
			// down *= pow( max(-slopednormal.y, 0), 2);
			// Indirect_lighting += up + down;

			Indirect_lighting = vec3(0.1);
		
			Indirect_lighting *= Absorbtion;
		#endif
		
		#ifdef END_SHADER
			Indirect_lighting += (vec3(0.5,0.75,1.0) * 0.9 + 0.1) * 0.1;

			Indirect_lighting *= clamp(1.5 + dot(normal, feetPlayerPos_normalized)*0.5,0,2);

			Indirect_lighting *= Absorbtion;
		#endif
	
		Indirect_lighting = DoAmbientLightColor(Indirect_lighting, MinimumLightColor, vec3(TORCH_R,TORCH_G,TORCH_B), lightmap.xy);
		
		#ifdef OVERWORLD_SHADER
			Indirect_lighting += LightningFlashLighting;
		#endif

		#ifdef SSS_view
			Indirect_lighting = vec3(3.0);
		#endif
	/////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	EFFECTS FOR INDIRECT	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////

		float SkySSS = 1.0;
		vec3 AO = vec3(1.0);


		#if indirect_effect == 0
			AO = vec3( exp( (vanilla_AO*vanilla_AO) * -5) )  ;
			Indirect_lighting *= AO;
		#endif

		#if indirect_effect == 1
			AO = vec3( exp( (vanilla_AO*vanilla_AO) * -3) );

			AO *= SSAO_SSS.x*SSAO_SSS.x*SSAO_SSS.x;
			// AO *= exp((1-SSAO_SSS.x) * -5);
			
			SkySSS = SSAO_SSS.y;

			Indirect_lighting *= AO;
		#endif

		// GTAO
		#if indirect_effect == 2
			Indirect_lighting = AmbientLightColor/2.5;

			vec2 r2 = fract(R2_samples((frameCounter%40000) + frameCounter*2) + bnoise);
			if (!hand) AO = ambient_occlusion(vec3(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5,z), viewPos, worldToView(slopednormal), r2) * vec3(1.0);
			
			Indirect_lighting *= AO;
		#endif

		// RTAO and/or SSGI
		#if indirect_effect == 3 || indirect_effect == 4
			Indirect_lighting = AmbientLightColor;
			if (!hand) ApplySSRT(Indirect_lighting, viewPos, normal, vec3(bnoise, noise_2), lightmap.xy, AmbientLightColor*2.5, vec3(TORCH_R,TORCH_G,TORCH_B), isGrass);
		#endif

		#if defined END_SHADER
			Direct_lighting *= AO;
		#endif


	/////////////////////////////	SKY SSS		/////////////////////////////

		#if defined Ambient_SSS && defined OVERWORLD_SHADER && indirect_effect == 1
			if (!hand){
				vec3 ambientColor = AmbientLightColor * 2.5 * ambient_brightness; // x2.5 to match the brightness of upfacing skylight
				float skylightmap = pow(lightmap.y, 3.0);

				Indirect_SSS = SubsurfaceScattering_sky(albedo, SkySSS, LabSSS);
				Indirect_SSS *= ambientColor;
				Indirect_SSS *= skylightmap;
				Indirect_SSS *= AO;

				// apply to ambient light.
				Indirect_lighting = max(Indirect_lighting, Indirect_SSS * ambientsss_brightness );

				#ifdef OVERWORLD_SHADER
					if(LabSSS > 0.0) Indirect_lighting += (1.0-SkySSS) * LightningPhase * lightningEffect *  pow(lightmap.y,10);
				#endif
			}
		#endif
	

	/////////////////////////////////////////////////////////////////////////
	/////////////////////////////	FINALIZE	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////
		#ifdef SSS_view
			albedo = vec3(1);
		#endif

		#ifdef OVERWORLD_SHADER
			// do these here so it gets underwater absorbtion.
			Direct_lighting =  max(DirectLightColor * NdotL * Shadows, DirectLightColor * Direct_SSS);
		#endif

		gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * albedo;

		#ifdef Specular_Reflections	
			vec2 specularNoises = vec2(noise, R2_dither());
			DoSpecularReflections(gl_FragData[0].rgb, viewPos, feetPlayerPos_normalized, WsunVec, specularNoises, normal, SpecularTex.r, SpecularTex.g, albedo, DirectLightColor*Shadows*NdotL, lightmap.y, hand);
		#endif

		Emission(gl_FragData[0].rgb, albedo, SpecularTex.a);
		
		if(lightningBolt) gl_FragData[0].rgb = vec3(77.0, 153.0, 255.0);

	}

	if(translucent_alpha > 0.0 ){
		#ifdef DISTANT_HORIZONS
    	  vec4 vlBehingTranslucents = BilateralUpscale_DH(colortex13, colortex12, gl_FragCoord.xy, sqrt(texture2D(colortex12,texcoord).a/65000.0));
    	#else
    	  vec4 vlBehingTranslucents = BilateralUpscale(colortex13, depthtex1, gl_FragCoord.xy, ld(z));
    	#endif

    	gl_FragData[0].rgb = gl_FragData[0].rgb * vlBehingTranslucents.a + vlBehingTranslucents.rgb;
	}

	////// DEBUG VIEW STUFF
	#if DEBUG_VIEW == debug_SHADOWMAP
		vec3 OutsideShadowMap_and_DH_shadow = (shadowMapFalloff > 0.0 && z >= 1.0) ? vec3(0.25,1.0,0.25) : vec3(1.0,0.25,0.25);
		vec3 Normal_Shadowmap =  z < 1.0 ? vec3(1.0,1.0,1.0) : OutsideShadowMap_and_DH_shadow;
		gl_FragData[0].rgb = mix(vec3(0.1) * (normal.y * 0.1 +0.9), Normal_Shadowmap,  shadowMap) * 30.0;
	#endif
	#if DEBUG_VIEW == debug_NORMALS
		gl_FragData[0].rgb = FlatNormals;
	#endif
	#if DEBUG_VIEW == debug_SPECULAR
		gl_FragData[0].rgb = SpecularTex.rgb;
	#endif
	#if DEBUG_VIEW == debug_INDIRECT
		gl_FragData[0].rgb = Indirect_lighting;
	#endif
	#if DEBUG_VIEW == debug_DIRECT
		gl_FragData[0].rgb = Direct_lighting;
	#endif
	#if DEBUG_VIEW == debug_VIEW_POSITION
		gl_FragData[0].rgb = viewPos * 0.001;
	#endif
	#if DEBUG_VIEW == debug_FILTERED_STUFF
		vec3 FilteredDebug = vec3(15.0) * exp(-7.0 * vec3(1.0,0.5,1.0) * filteredShadow.y);
		// FilteredDebug += vec3(15.0) * exp(-7.0 * vec3(1.0,1.0,0.5) * pow(SSAO_SSS.x,2));
		// FilteredDebug += vec3(15.0) * exp(-7.0 * vec3(0.5,1.0,1.0) * pow(SSAO_SSS.y,2));
  		gl_FragData[0].rgb =  FilteredDebug;
	#endif

	#ifdef CLOUDS_INFRONT_OF_WORLD
		gl_FragData[1] = texture2D(colortex2, texcoord);
		if(heightRelativeToClouds > 0.0 && !hand){
			gl_FragData[0].rgb = gl_FragData[0].rgb * Clouds.a + Clouds.rgb;
			gl_FragData[1].a = gl_FragData[1].a*Clouds.a*Clouds.a*Clouds.a;
		}

/* DRAWBUFFERS:32 */

	#else

/* DRAWBUFFERS:3 */

	#endif
}