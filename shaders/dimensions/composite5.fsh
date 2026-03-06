#define GAMEPLAY_EFFECTS_RELATED_SETTINGS
#define ANTIALIASING_RELATED_SETTINGS
#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/buffer_formatting.glsl"

varying vec2 texcoord;
flat varying float tempOffsets;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float viewHeight;
uniform float viewWidth;

uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousModelViewInverse;

uniform int hideGUI;

#if CRITICAL_DAMAGE_TAKEN_EFFECT_START > 0
	uniform float CriticalDamageTaken;
#endif

#include "/lib/util.glsl"
#include "/lib/projections.glsl"
#include "/lib/TAA_jitter.glsl"
#include "/lib/macro_lod_mod.glsl"

uniform float near;
uniform float far;

#include "/lib/DistantHorizons_projections.glsl"

vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}

float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
float interleaved_gradientNoise(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+tempOffsets);
}
float triangularize(float dither)
{
    float center = dither*2.0-1.0;
    dither = center*inversesqrt(abs(center));
    return clamp(dither-fsign(center),0.0,1.0);
}
vec4 fp10Dither(vec4 color ,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color.rgb));
	return vec4(color.rgb + dither*exp2(-mantissaBits)*exp2(exponent), color.a);
}

vec3 toClipSpace3Prev(vec3 viewSpacePosition) {
    return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}
vec3 tonemap(vec3 col){
	return col/(1+luma(col));
}
vec3 invTonemap(vec3 col){
	return col/(1-luma(col));
}
void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}
float convertHandDepth2( float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    return ndcDepth * 0.5 + 0.5;
}



float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}
float DH_ld(float dist) {
    return (2.0 * LOD_NEARPLANE) / (LOD_FARPLANE + LOD_NEARPLANE - dist * (LOD_FARPLANE - LOD_NEARPLANE));
}
float DH_inv_ld (float lindepth){
	return -((2.0*LOD_NEARPLANE/lindepth)-LOD_FARPLANE-LOD_NEARPLANE)/(LOD_FARPLANE-LOD_NEARPLANE);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}
float invertlinearDepthFast(const in float depth, const in float near, const in float far) {
	return ((2.0*near/depth)-far-near)/(far-near);
}

vec3 toClipSpace3Prev_DH( vec3 viewSpacePosition, bool depthCheck ) {

	#ifdef USING_LOD_MOD
		mat4 projectionMatrix = depthCheck ? LOD_PROJECTION_PREV : gbufferPreviousProjection;
   		return projMAD(projectionMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#else
    	return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#endif
}

vec3 toScreenSpace_DH_special(vec3 POS, bool depthCheck ) {

	vec4 viewPos = vec4(0.0);
	vec3 feetPlayerPos = vec3(0.0);
	vec4 iProjDiag = vec4(0.0);
	#ifdef USING_LOD_MOD
    	if (depthCheck) {
			iProjDiag = vec4(LOD_PROJECTION_INVERSE[0].x, LOD_PROJECTION_INVERSE[1].y, LOD_PROJECTION_INVERSE[2].zw);

    		feetPlayerPos = POS * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + LOD_PROJECTION_INVERSE[3];
			viewPos.xyz /= viewPos.w;

		} else {
	#endif
			iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);

    		feetPlayerPos = POS * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
			viewPos.xyz /= viewPos.w;
			
	#ifdef USING_LOD_MOD
		}
	#endif

    return viewPos.xyz;
}

//Modified texture interpolation from inigo quilez
vec4 smoothfilter(in sampler2D tex, in vec2 uv)
{
	vec2 textureResolution = vec2(viewWidth,viewHeight);
	uv = uv*textureResolution + 0.5;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );

	#ifndef SMOOTHESTSTEP_INTERPOLATION
		uv = iuv + (fuv*fuv)*(3.0-2.0*fuv);
	#endif
	#ifdef SMOOTHESTSTEP_INTERPOLATION
		uv = iuv + fuv*fuv*fuv*(fuv*(fuv*6.0-15.0)+10.0);
	#endif

	uv = (uv - 0.5)/textureResolution;
	
	return texture(tex, uv);
}
vec2 smoothfilterUV(in vec2 uv)
{
	vec2 textureResolution = vec2(viewWidth,viewHeight);
	uv = uv*textureResolution + 0.5;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );

	#ifndef SMOOTHESTSTEP_INTERPOLATION
		uv = iuv + (fuv*fuv)*(3.0-2.0*fuv);
	#endif
	#ifdef SMOOTHESTSTEP_INTERPOLATION
		uv = iuv + fuv*fuv*fuv*(fuv*(fuv*6.0-15.0)+10.0);
	#endif

	uv = (uv - 0.5)/textureResolution;
	
	return uv;
}
//approximation from SMAA presentation from siggraph 2016
vec3 FastCatmulRom(sampler2D colorTex, vec2 texcoord, vec4 rtMetrics, float sharpenAmount)
{
    vec2 position = rtMetrics.zw * texcoord;
    vec2 centerPosition = floor(position - 0.5) + 0.5;
    vec2 f = position - centerPosition;
    vec2 f2 = f * f;
    vec2 f3 = f * f2;

    float c = sharpenAmount;
    vec2 w0 =        -c  * f3 +  2.0 * c         * f2 - c * f;
    vec2 w1 =  (2.0 - c) * f3 - (3.0 - c)        * f2         + 1.0;
    vec2 w2 = -(2.0 - c) * f3 + (3.0 -  2.0 * c) * f2 + c * f;
    vec2 w3 =         c  * f3 -                c * f2;

    vec2 w12 = w1 + w2;
    vec2 tc12 = rtMetrics.xy * (centerPosition + w2 / w12);
    vec3 centerColor = texture(colorTex, vec2(tc12.x, tc12.y)).rgb;
    vec2 tc0 = rtMetrics.xy * (centerPosition - 1.0);
    vec2 tc3 = rtMetrics.xy * (centerPosition + 2.0);
    vec4 color =   vec4(texture(colorTex, vec2(tc12.x, tc0.y )).rgb, 1.0) * (w12.x * w0.y ) +
                   vec4(texture(colorTex, vec2(tc0.x,  tc12.y)).rgb, 1.0) * (w0.x  * w12.y) +
                   vec4(centerColor,                                      1.0) * (w12.x * w12.y) +
                   vec4(texture(colorTex, vec2(tc3.x,  tc12.y)).rgb, 1.0) * (w3.x  * w12.y) +
                   vec4(texture(colorTex, vec2(tc12.x, tc3.y )).rgb, 1.0) * (w12.x * w3.y );

	return color.rgb/color.a;

}

vec3 closestToCamera5taps(vec2 texcoord, sampler2D depth)
{
	vec2 du = vec2(texelSize.x*2., 0.0);
	vec2 dv = vec2(0.0, texelSize.y*2.);

	vec3 dtl = vec3(texcoord,0.) + vec3(-texelSize, 				texture(depth, texcoord - dv - du).x);
	vec3 dtr = vec3(texcoord,0.) + vec3( texelSize.x, -texelSize.y, texture(depth, texcoord - dv + du).x);
	vec3 dmc = vec3(texcoord,0.) + vec3( 0.0, 0.0, 					texture(depth, texcoord).x);
	vec3 dbl = vec3(texcoord,0.) + vec3(-texelSize.x, texelSize.y, 	texture(depth, texcoord + dv - du).x);
	vec3 dbr = vec3(texcoord,0.) + vec3( texelSize.x, texelSize.y, 	texture(depth, texcoord + dv + du).x);

	vec3 dmin = dmc;
	dmin = dmin.z > dtr.z ? dtr : dmin;
	dmin = dmin.z > dtl.z ? dtl : dmin;
	dmin = dmin.z > dbl.z ? dbl : dmin;
	dmin = dmin.z > dbr.z ? dbr : dmin;
	
	#if TAA_MODE == 3
		dmin.xy = dmin.xy/RENDER_SCALE;
	#endif

	return dmin;
}

vec3 closestToCamera5taps_DH(vec2 texcoord, sampler2D depth, sampler2D dhDepth, bool depthCheck)
{
	vec2 du = vec2(texelSize.x*2., 0.0);
	vec2 dv = vec2(0.0, texelSize.y*2.);

	vec3 dtl = vec3(texcoord,0.);
	vec3 dtr = vec3(texcoord,0.);
	vec3 dmc = vec3(texcoord,0.);
	vec3 dbl = vec3(texcoord,0.);
	vec3 dbr = vec3(texcoord,0.);

	dtl += vec3(-texelSize, 					depthCheck ? texture(dhDepth, texcoord - dv - du).x	:	texture(depth, texcoord - dv - du).x);
	dtr += vec3( texelSize.x, -texelSize.y, 	depthCheck ? texture(dhDepth, texcoord - dv + du).x	:	texture(depth, texcoord - dv + du).x);
	dmc += vec3( 0.0, 0.0, 				   		depthCheck ? texture(dhDepth, texcoord).x				:	texture(depth, texcoord).x);
	dbl += vec3(-texelSize.x, texelSize.y, 		depthCheck ? texture(dhDepth, texcoord + dv - du).x	:	texture(depth, texcoord + dv - du).x);
	dbr += vec3( texelSize.x, texelSize.y, 		depthCheck ? texture(dhDepth, texcoord + dv + du).x	:	texture(depth, texcoord + dv + du).x);
	
	vec3 dmin = dmc;
	dmin = dmin.z > dtr.z ? dtr : dmin;
	dmin = dmin.z > dtl.z ? dtl : dmin;
	dmin = dmin.z > dbl.z ? dbl : dmin;
	dmin = dmin.z > dbr.z ? dbr : dmin;
	
	#if TAA_MODE == 3
		dmin.xy = dmin.xy/RENDER_SCALE;
	#endif

	return dmin;
}

vec4 computeTAA(vec2 texcoord, bool hand){

	vec2 jitter = taaJitter*texelSize*0.5;
	vec2 adjTC = clamp(texcoord*RENDER_SCALE - texelSize*0.5, vec2(0.0), RENDER_SCALE- texelSize*1.5);
	vec2 adjTC_noJitter = adjTC + jitter;

	// get previous frames position stuff for UV	
	//use velocity from the nearest texel from camera in a 3x3 box in order to improve edge quality in motion	
	#ifdef USING_LOD_MOD
		bool depthCheck = texture(depthtex0,adjTC).x >= 1.0;
		vec3 closestToCamera = closestToCamera5taps_DH(adjTC, depthtex0, LOD_DEPTHTEX0, depthCheck);
		vec3 viewPos = toScreenSpace_DH_special(closestToCamera, depthCheck);
	#else
		vec3 closestToCamera = closestToCamera5taps(adjTC, depthtex0);
		vec3 viewPos = toScreenSpace(closestToCamera);
	#endif
	
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * playerPos + gbufferPreviousModelView[3].xyz;
	
	#ifdef USING_LOD_MOD
		previousPosition = toClipSpace3Prev_DH(previousPosition, depthCheck);
	#else
		previousPosition = toClipSpace3Prev(previousPosition);
	#endif

	vec2 velocity = previousPosition.xy - closestToCamera.xy;
	
	previousPosition.xy = texcoord + (hand ? vec2(0.0) : velocity);

	// adjust clamping radius when motion is detected to reduce ghosting further without needing to change blend factor
	#if NEIGHBORHOOD_CLAMP_RADIUS_MULT_DURING_MOVEMENT < 100
		float clampRadius = mix(1.0, float(NEIGHBORHOOD_CLAMP_RADIUS_MULT_DURING_MOVEMENT)/100.0f, clamp(length(velocity/texelSize),0.0,1.0)	);
	#else
		float clampRadius = 1.0;
	#endif

	// sample current frame, and make sure it is de-jittered
	#if TAA_MODE == 3
		vec3 currentFrame = smoothfilter(colortex3, adjTC_noJitter).rgb;
	#else
		vec3 currentFrame = texelFetch(colortex3, ivec2(adjTC_noJitter/texelSize), 0).rgb;
	#endif

	#if CRITICAL_DAMAGE_TAKEN_EFFECT_START > 0
		if (CriticalDamageTaken < 0.001 && (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0)) return vec4(currentFrame, 1.0);
	#else
		//reject history if off-screen and early exit
		if (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0) return vec4(currentFrame, 1.0);
	#endif
	
	#if TAA_MODE == 3
		// Interpolating neighboorhood clampling boundaries between pixels
		vec3 colMax = texture(colortex0, adjTC).rgb;
		vec3 colMin = texture(colortex6, adjTC).rgb;
	#else
		//Assuming the history color is a blend of the 3x3 neighborhood, we clamp the history to the min and max of each channel in the 3x3 neighborhood
		vec3 col0 = currentFrame; // can use this because its the center sample.
		vec3 col1 = texture(colortex3, adjTC_noJitter + vec2( texelSize.x,	 texelSize.y)*clampRadius).rgb;
		vec3 col2 = texture(colortex3, adjTC_noJitter + vec2( texelSize.x,	-texelSize.y)*clampRadius).rgb;
		vec3 col3 = texture(colortex3, adjTC_noJitter + vec2(-texelSize.x,	-texelSize.y)*clampRadius).rgb;
		vec3 col4 = texture(colortex3, adjTC_noJitter + vec2(-texelSize.x,	 texelSize.y)*clampRadius).rgb;
		vec3 col5 = texture(colortex3, adjTC_noJitter + vec2( 0.0,			 texelSize.y)*clampRadius).rgb;
		vec3 col6 = texture(colortex3, adjTC_noJitter + vec2( 0.0,			-texelSize.y)*clampRadius).rgb;
		vec3 col7 = texture(colortex3, adjTC_noJitter + vec2(-texelSize.x,	 		 0.0)*clampRadius).rgb;
		vec3 col8 = texture(colortex3, adjTC_noJitter + vec2( texelSize.x,	 		 0.0)*clampRadius).rgb;

		vec3 colMax = max(col0,max(col1,max(col2,max(col3, max(col4, max(col5, max(col6, max(col7, col8))))))));
		vec3 colMin = min(col0,min(col1,min(col2,min(col3, min(col4, min(col5, min(col6, min(col7, col8))))))));
		
		colMin = 0.5 * (colMin + min(col0,min(col5,min(col6,min(col7,col8)))));
		colMax = 0.5 * (colMax + max(col0,max(col5,max(col6,max(col7,col8)))));
	#endif
	
	#if CRITICAL_DAMAGE_TAKEN_EFFECT_START > 0
		////// when this triggers, use current frame UV to sample history, for a funny trailing effect.
		if(CriticalDamageTaken > 0.001) previousPosition.xy = mix(previousPosition.xy, texcoord, pow(CriticalDamageTaken,0.3));
	#endif

	vec3 frameHistory = max(FastCatmulRom(colortex5, previousPosition.xy, vec4(texelSize, 1.0/texelSize), 0.75).xyz,1e-7);
	vec3 clampedframeHistory = clamp(frameHistory, colMin, colMax);
	

	float blendingFactor = BLEND_FACTOR;
	// reduce history usage if the camera moves to reduce artifacts in motion.
	float cameraMovement = length(velocity/texelSize);
	blendingFactor = clamp(cameraMovement, blendingFactor, BLEND_FACTOR_DURING_MOVEMENT);
	
	#if NEIGHBORHOOD_CLAMP_RADIUS_MULT_DURING_MOVEMENT > 99
		if(hand) blendingFactor = clamp(cameraMovement, blendingFactor, 1.0);
	#endif
	
	#if CRITICAL_DAMAGE_TAKEN_EFFECT_START > 0
		if(CriticalDamageTaken > 0.001){
			clampedframeHistory = mix(clampedframeHistory, frameHistory, pow(CriticalDamageTaken,0.3));
			blendingFactor *= 0.5;
		}
	#endif
	////// Increases blending factor when far from AABB, reduces ghosting
	blendingFactor = clamp(blendingFactor + luma(abs(clampedframeHistory - frameHistory)/clampedframeHistory),0.0,1.0);

	////// Blend current pixel with clamped history, apply fast tonemap beforehand to reduce flickering
	vec3 finalResult = invTonemap(mix(tonemap(clampedframeHistory), tonemap(currentFrame), blendingFactor));

	#ifdef SCREENSHOT_MODE
		// when this is on, do "infinite frame accumulation	"
		if (hideGUI == 0) return vec4(finalResult, 1.0);

		vec4 superSampledHistory = texture(colortex5, previousPosition.xy);
		vec3 superSampledResult = superSampledHistory.rgb * superSampledHistory.a + currentFrame;

		return vec4(superSampledResult/(superSampledHistory.a+1.0), superSampledHistory.a+1.0);
	#endif

	return vec4(finalResult, 1.0);
}



void main() {
/* RENDERTARGETS:5 */
	#if TAA_MODE > 0
		vec2 taauTC = clamp(texcoord*RENDER_SCALE, vec2(0.0), RENDER_SCALE - texelSize*2.0);
		
		float dataUnpacked = decodeVec2(texelFetch(colortex1,ivec2(gl_FragCoord.xy*RENDER_SCALE),0).w).y; 
		
		bool hand = abs(dataUnpacked-0.75) < 0.01 && texture(depthtex1,taauTC).x < 1.0;
		
		vec4 color = computeTAA(texcoord, hand);

		#ifdef SCREENSHOT_MODE
			gl_FragData[0] = clamp(color, 0.0, 65000.0);
		#else
			gl_FragData[0] = clamp(fp10Dither(color, triangularize(interleaved_gradientNoise())), 0.0, 65000.0);
		#endif
	#else
		vec3 color = clamp(fp10Dither(vec4(texture(colortex3,texcoord).rgb,1.0), triangularize(interleaved_gradientNoise())).rgb,0.0,65000.);
		gl_FragData[0].rgb = color;
	#endif
}