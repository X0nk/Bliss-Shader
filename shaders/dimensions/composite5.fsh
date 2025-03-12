#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

/*
const int colortex0Format = RGBA16F;				// low res clouds (deferred->composite2) + low res VL (composite5->composite15)
const int colortex1Format = RGBA16;					// terrain gbuffer (gbuffer->composite2)
const int colortex2Format = RGBA16F;				// forward + transparencies (gbuffer->composite4)
const int colortex3Format = R11F_G11F_B10F;			// frame buffer + bloom (deferred6->final)
const int colortex4Format = RGBA16F;				// light values and skyboxes (everything)
const int colortex6Format = R11F_G11F_B10F;			// additionnal buffer for bloom (composite3->final)
const int colortex7Format = RGBA8;					// Final output, transparencies id (gbuffer->composite4)
const int colortex8Format = RGBA8;					// Specular Texture
const int colortex9Format = RGBA8;					// rain in alpha
const int colortex10Format = RGBA16;				// resourcepack Skies
const int colortex11Format = RGBA16; 				// unchanged translucents albedo, alpha and tangent normals
const int colortex12Format = RGBA16F;				// DISTANT HORIZONS + VANILLA MIXED DEPTHs

const int colortex13Format = RGBA16F;				// low res VL (composite5->composite15)
const int colortex14Format = RGBA16;					// rg = SSAO and SS-SSS. a = skylightmap for translucents.
const int colortex15Format = RGBA8;					// flat normals and vanilla AO
*/

//no need to clear the buffers, saves a few fps
const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex2Clear = true;
const bool colortex3Clear = false;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const bool colortex6Clear = false;
const bool colortex7Clear = false;
const bool colortex8Clear = false;
const bool colortex9Clear = true;
const bool colortex10Clear = true;
const bool colortex11Clear = true;
const bool colortex12Clear = false;
const bool colortex13Clear = false;
const bool colortex14Clear = true;
const bool colortex15Clear = false;


#ifdef SCREENSHOT_MODE
	/*
	const int colortex5Format = RGBA32F;// TAA buffer (everything)
	*/
#else
	/*
	const int colortex5Format = R11F_G11F_B10F;	// TAA buffer (everything)
	*/
#endif


varying vec2 texcoord;
flat varying float tempOffsets;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex10;
uniform sampler2D colortex12;
uniform sampler2D colortex14;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float viewHeight;
uniform float viewWidth;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;

uniform int hideGUI;

#ifdef DAMAGE_TAKEN_EFFECT
	uniform float CriticalDamageTaken;
#endif

#include "/lib/util.glsl"
#include "/lib/projections.glsl"


uniform int framemod8;
#include "/lib/TAA_jitter.glsl"

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


#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
#endif
uniform float near;
uniform float far;
uniform float dhFarPlane;
uniform float dhNearPlane;

#include "/lib/DistantHorizons_projections.glsl"


float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
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
float invertlinearDepthFast(const in float depth, const in float near, const in float far) {
	return ((2.0*near/depth)-far-near)/(far-near);
}

vec3 toClipSpace3Prev_DH( vec3 viewSpacePosition, bool depthCheck ) {

	#ifdef DISTANT_HORIZONS
		mat4 projectionMatrix = depthCheck ? dhPreviousProjection : gbufferPreviousProjection;
   		return projMAD(projectionMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#else
    	return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#endif
}

vec3 toScreenSpace_DH_special(vec3 POS, bool depthCheck ) {

	vec4 viewPos = vec4(0.0);
	vec3 feetPlayerPos = vec3(0.0);
	vec4 iProjDiag = vec4(0.0);
	#ifdef DISTANT_HORIZONS
    	if (depthCheck) {
			iProjDiag = vec4(dhProjectionInverse[0].x, dhProjectionInverse[1].y, dhProjectionInverse[2].zw);

    		feetPlayerPos = POS * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + dhProjectionInverse[3];
			viewPos.xyz /= viewPos.w;

		} else {
	#endif
			iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);

    		feetPlayerPos = POS * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
			viewPos.xyz /= viewPos.w;
			
	#ifdef DISTANT_HORIZONS
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
	
	return texture2D(tex, uv);
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
    vec3 centerColor = texture2D(colorTex, vec2(tc12.x, tc12.y)).rgb;

    vec2 tc0 = rtMetrics.xy * (centerPosition - 1.0);
    vec2 tc3 = rtMetrics.xy * (centerPosition + 2.0);
    vec4 color = vec4(texture2D(colorTex, vec2(tc12.x, tc0.y )).rgb, 1.0) * (w12.x * w0.y ) +
                   vec4(texture2D(colorTex, vec2(tc0.x,  tc12.y)).rgb, 1.0) * (w0.x  * w12.y) +
                   vec4(centerColor,                                      1.0) * (w12.x * w12.y) +
                   vec4(texture2D(colorTex, vec2(tc3.x,  tc12.y)).rgb, 1.0) * (w3.x  * w12.y) +
                   vec4(texture2D(colorTex, vec2(tc12.x, tc3.y )).rgb, 1.0) * (w12.x * w3.y );
	
	return color.rgb/color.a;

}

vec3 closestToCamera5taps(vec2 texcoord, sampler2D depth, bool hand)
{
	vec2 du = vec2(texelSize.x*2., 0.0);
	vec2 dv = vec2(0.0, texelSize.y*2.);

	vec3 dtl = vec3(texcoord,0.) + vec3(-texelSize, 				texture2D(depth, texcoord - dv - du).x);
	vec3 dtr = vec3(texcoord,0.) + vec3( texelSize.x, -texelSize.y, texture2D(depth, texcoord - dv + du).x);
	vec3 dmc = vec3(texcoord,0.) + vec3( 0.0, 0.0, 					texture2D(depth, texcoord).x);
	vec3 dbl = vec3(texcoord,0.) + vec3(-texelSize.x, texelSize.y, 	texture2D(depth, texcoord + dv - du).x);
	vec3 dbr = vec3(texcoord,0.) + vec3( texelSize.x, texelSize.y, 	texture2D(depth, texcoord + dv + du).x);
	
	if(hand){
		convertHandDepth(dtl.z);
		convertHandDepth(dtr.z);
		convertHandDepth(dmc.z);
		convertHandDepth(dbl.z);
		convertHandDepth(dbr.z);
	}

	vec3 dmin = dmc;
	dmin = dmin.z > dtr.z ? dtr : dmin;
	dmin = dmin.z > dtl.z ? dtl : dmin;
	dmin = dmin.z > dbl.z ? dbl : dmin;
	dmin = dmin.z > dbr.z ? dbr : dmin;
	
	#ifdef TAA_UPSCALING
		dmin.xy = dmin.xy/RENDER_SCALE;
	#endif

	return dmin;
}

vec3 closestToCamera5taps_DH(vec2 texcoord, sampler2D depth, sampler2D dhDepth, bool depthCheck, bool hand)
{
	vec2 du = vec2(texelSize.x*2., 0.0);
	vec2 dv = vec2(0.0, texelSize.y*2.);

	vec3 dtl = vec3(texcoord,0.);
	vec3 dtr = vec3(texcoord,0.);
	vec3 dmc = vec3(texcoord,0.);
	vec3 dbl = vec3(texcoord,0.);
	vec3 dbr = vec3(texcoord,0.);

	dtl += vec3(-texelSize, 					depthCheck ? texture2D(dhDepth, texcoord - dv - du).x	:	texture2D(depth, texcoord - dv - du).x);
	dtr += vec3( texelSize.x, -texelSize.y, 	depthCheck ? texture2D(dhDepth, texcoord - dv + du).x	:	texture2D(depth, texcoord - dv + du).x);
	dmc += vec3( 0.0, 0.0, 				   		depthCheck ? texture2D(dhDepth, texcoord).x				:	texture2D(depth, texcoord).x);
	dbl += vec3(-texelSize.x, texelSize.y, 		depthCheck ? texture2D(dhDepth, texcoord + dv - du).x	:	texture2D(depth, texcoord + dv - du).x);
	dbr += vec3( texelSize.x, texelSize.y, 		depthCheck ? texture2D(dhDepth, texcoord + dv + du).x	:	texture2D(depth, texcoord + dv + du).x);

	if(hand){
		convertHandDepth(dtl.z);
		convertHandDepth(dtr.z);
		convertHandDepth(dmc.z);
		convertHandDepth(dbl.z);
		convertHandDepth(dbr.z);
	}
	
	vec3 dmin = dmc;
	dmin = dmin.z > dtr.z ? dtr : dmin;
	dmin = dmin.z > dtl.z ? dtl : dmin;
	dmin = dmin.z > dbl.z ? dbl : dmin;
	dmin = dmin.z > dbr.z ? dbr : dmin;
	
	#ifdef TAA_UPSCALING
		dmin.xy = dmin.xy/RENDER_SCALE;
	#endif

	return dmin;
}

vec4 computeTAA(vec2 texcoord, bool hand){

	vec2 jitter = offsets[framemod8]*texelSize*0.5;
	vec2 adjTC = clamp(texcoord*RENDER_SCALE, vec2(0.0), RENDER_SCALE - texelSize*2.0);

	// get previous frames position stuff for UV	
	//use velocity from the nearest texel from camera in a 3x3 box in order to improve edge quality in motion	
	#ifdef DISTANT_HORIZONS
		bool depthCheck = texture2D(depthtex0,adjTC).x >= 1.0;
		vec3 closestToCamera = closestToCamera5taps_DH(adjTC, depthtex0, dhDepthTex, depthCheck, hand);
		vec3 viewPos = toScreenSpace_DH_special(closestToCamera, depthCheck);
	#else
		vec3 closestToCamera = closestToCamera5taps(adjTC, depthtex0, hand);
		vec3 viewPos = toScreenSpace(closestToCamera);
	#endif
	
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * playerPos + gbufferPreviousModelView[3].xyz;
	#ifdef DISTANT_HORIZONS
		previousPosition = toClipSpace3Prev_DH(previousPosition, depthCheck);
	#else
		previousPosition = toClipSpace3Prev(previousPosition);
	#endif

	vec2 velocity = previousPosition.xy - closestToCamera.xy;
	previousPosition.xy = texcoord + velocity;

	// sample current frame, and make sure it is de-jittered
	vec3 currentFrame = smoothfilter(colortex3, adjTC + jitter).rgb;

	//reject history if off-screen and early exit
	if (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0) return vec4(currentFrame, 1.0);

	#ifdef TAA_UPSCALING
		// Interpolating neighboorhood clampling boundaries between pixels
		vec3 colMax = texture2D(colortex0, adjTC).rgb;
		vec3 colMin = texture2D(colortex6, adjTC).rgb;
	#else
		//Assuming the history color is a blend of the 3x3 neighborhood, we clamp the history to the min and max of each channel in the 3x3 neighborhood
		vec3 col0 = currentFrame; // can use this because its the center sample.
		vec3 col1 = texture2D(colortex3, adjTC + vec2( texelSize.x,	 texelSize.y)).rgb;
		vec3 col2 = texture2D(colortex3, adjTC + vec2( texelSize.x,	-texelSize.y)).rgb;
		vec3 col3 = texture2D(colortex3, adjTC + vec2(-texelSize.x,	-texelSize.y)).rgb;
		vec3 col4 = texture2D(colortex3, adjTC + vec2(-texelSize.x,	 texelSize.y)).rgb;
		vec3 col5 = texture2D(colortex3, adjTC + vec2( 0.0,			 texelSize.y)).rgb;
		vec3 col6 = texture2D(colortex3, adjTC + vec2( 0.0,			-texelSize.y)).rgb;
		vec3 col7 = texture2D(colortex3, adjTC + vec2(-texelSize.x,	 		 0.0)).rgb;
		vec3 col8 = texture2D(colortex3, adjTC + vec2( texelSize.x,	 		 0.0)).rgb;

		vec3 colMax = max(col0,max(col1,max(col2,max(col3, max(col4, max(col5, max(col6, max(col7, col8))))))));
		vec3 colMin = min(col0,min(col1,min(col2,min(col3, min(col4, min(col5, min(col6, min(col7, col8))))))));
		
		vec3 colMax5 = max(col0,max(col5,max(col6,max(col7,col8))));
		vec3 colMin5 = min(col0,min(col5,min(col6,min(col7,col8))));

		colMin = 0.5 * (colMin + colMin5);
		colMax = 0.5 * (colMax + colMax5);
	#endif
    #ifdef DAMAGE_TAKEN_EFFECT
		// when this triggers, use current frame UV to sample history, for a funny trailing effect.
		if(CriticalDamageTaken > 0.01) previousPosition.xy = texcoord;
	#endif

	vec3 frameHistory = max(FastCatmulRom(colortex5, previousPosition.xy, vec4(texelSize, 1.0/texelSize), 0.75).xyz,0.0);
	vec3 clampedframeHistory = clamp(frameHistory, colMin, colMax);

	float blendingFactor = BLEND_FACTOR;
	if(hand) blendingFactor = clamp(length(velocity/texelSize),blendingFactor,1.0);
	
	//Increases blending factor when far from AABB, reduces ghosting
	blendingFactor = min(blendingFactor + luma(min(max(clampedframeHistory - frameHistory,0.0) / frameHistory, 1.0)),1.0);
	
	// Blend current pixel with clamped history, apply fast tonemap beforehand to reduce flickering
	vec3 finalResult = invTonemap(mix(tonemap(clampedframeHistory), tonemap(currentFrame), blendingFactor));
   
    #ifdef DAMAGE_TAKEN_EFFECT
		// when this triggers, do a funny trailing effect.
		if(CriticalDamageTaken > 0.01) finalResult = mix(finalResult, frameHistory, sqrt(CriticalDamageTaken)*0.8);
	#endif
	#ifdef SCREENSHOT_MODE
		// when this is on, do "infinite frame accumulation	"
		if (hideGUI == 0) return vec4(finalResult, 1.0);

		vec4 superSampledHistory = texture2D(colortex5, previousPosition.xy);
		vec3 superSampledResult = superSampledHistory.rgb * superSampledHistory.a + currentFrame;

		return vec4(superSampledResult/(superSampledHistory.a+1.0), superSampledHistory.a+1.0);
	#endif

	return vec4(finalResult, 1.0);
}



void main() {
/* DRAWBUFFERS:5 */
	#ifdef TAA
		vec2 taauTC = clamp(texcoord*RENDER_SCALE, vec2(0.0), RENDER_SCALE - texelSize*2.0);
		
		float dataUnpacked = decodeVec2(texelFetch2D(colortex1,ivec2(gl_FragCoord.xy*RENDER_SCALE),0).w).y; 
		bool hand = abs(dataUnpacked-0.75) < 0.01 && texture2D(depthtex1,taauTC).x < 1.0;
		
		// vec4 color = TAA_hq(hand);
		
		vec4 color = computeTAA(texcoord, hand);

		// gl_FragData[0] = clamp(color, 0.0, 65000.0);

		#if DEBUG_VIEW == debug_TEMPORAL_REPROJECTION
			color.rgb = texture2D(colortex3, taauTC).rgb;
		#endif

		#ifdef SCREENSHOT_MODE
			gl_FragData[0] = clamp(color, 0.0, 65000.0);
		#else
			gl_FragData[0] = clamp(fp10Dither(color, triangularize(interleaved_gradientNoise())), 0.0, 65000.0);
		#endif
	#else
		vec3 color = clamp(fp10Dither(vec4(texture2D(colortex3,texcoord).rgb,1.0), triangularize(interleaved_gradientNoise())).rgb,0.0,65000.);
		gl_FragData[0].rgb = color;
	#endif
}