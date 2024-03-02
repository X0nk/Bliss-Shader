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
const int colortex14Format = RGBA8;					// rg = SSAO and SS-SSS. a = skylightmap for translucents.
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
	const int colortex5Format = RGBA32F;			//TAA buffer (everything)
	*/
#else
	/*
	const int colortex5Format = R11F_G11F_B10F;			//TAA buffer (everything)
	*/
#endif


varying vec2 texcoord;
flat varying float tempOffsets;
uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex10;
uniform sampler2D colortex12;
uniform sampler2D depthtex0;

uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform int framemod8;
uniform float viewHeight;
uniform float viewWidth;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;

uniform int hideGUI;




#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)

#include "/lib/projections.glsl"


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
	
	return texture2D( tex, uv);
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

vec3 clip_aabb(vec3 q, vec3 aabb_min, vec3 aabb_max)
{
		vec3 p_clip = 0.5 * (aabb_max + aabb_min);
		vec3 e_clip = 0.5 * (aabb_max - aabb_min) + 0.00000001;

		vec3 v_clip = q - vec3(p_clip);
		vec3 v_unit = v_clip.xyz / e_clip;
		vec3 a_unit = abs(v_unit);
		float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

		if (ma_unit > 1.0)
			return vec3(p_clip) + v_clip / ma_unit;
		else
			return q;
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

vec3 closestToCamera5taps(vec2 texcoord, sampler2D depth)
{
	vec2 du = vec2(texelSize.x*2., 0.0);
	vec2 dv = vec2(0.0, texelSize.y*2.);

	vec3 dtl = vec3(texcoord,0.) + vec3(-texelSize, texture2D(depth, texcoord - dv - du).x);
	vec3 dtr = vec3(texcoord,0.) +  vec3( texelSize.x, -texelSize.y, texture2D(depth, texcoord - dv + du).x);
	vec3 dmc = vec3(texcoord,0.) + vec3( 0.0, 0.0, texture2D(depth, texcoord).x);
	vec3 dbl = vec3(texcoord,0.) + vec3(-texelSize.x, texelSize.y, texture2D(depth, texcoord + dv - du).x);
	vec3 dbr = vec3(texcoord,0.) + vec3( texelSize.x, texelSize.y, texture2D(depth, texcoord + dv + du).x);

	vec3 dmin = dmc;
	dmin = dmin.z > dtr.z? dtr : dmin;
	dmin = dmin.z > dtl.z? dtl : dmin;
	dmin = dmin.z > dbl.z? dbl : dmin;
	dmin = dmin.z > dbr.z? dbr : dmin;
	
	#ifdef TAA_UPSCALING
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

	dtl += vec3(-texelSize, 					depthCheck ? texture2D(dhDepth, texcoord - dv - du).x	:	texture2D(depth, texcoord - dv - du).x);
	dtr += vec3( texelSize.x, -texelSize.y, 	depthCheck ? texture2D(dhDepth, texcoord - dv + du).x	:	texture2D(depth, texcoord - dv + du).x);
	dmc += vec3( 0.0, 0.0, 				   		depthCheck ? texture2D(dhDepth, texcoord).x				:	texture2D(depth, texcoord).x);
	dbl += vec3(-texelSize.x, texelSize.y, 		depthCheck ? texture2D(dhDepth, texcoord + dv - du).x	:	texture2D(depth, texcoord + dv - du).x);
	dbr += vec3( texelSize.x, texelSize.y, 		depthCheck ? texture2D(dhDepth, texcoord + dv + du).x	:	texture2D(depth, texcoord + dv + du).x);

	vec3 dmin = dmc;
	dmin = dmin.z > dtr.z? dtr : dmin;
	dmin = dmin.z > dtl.z? dtl : dmin;
	dmin = dmin.z > dbl.z? dbl : dmin;
	dmin = dmin.z > dbr.z? dbr : dmin;
	
	#ifdef TAA_UPSCALING
		dmin.xy = dmin.xy/RENDER_SCALE;
	#endif

	return dmin;
}


uniform sampler2D dhDepthTex;
uniform float far;
uniform float dhFarPlane;
uniform float dhNearPlane;

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

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);



vec4 TAA_hq(){

	#ifdef TAA_UPSCALING
		vec2 adjTC = clamp(texcoord*RENDER_SCALE, vec2(0.0), RENDER_SCALE - texelSize*2.0);
	#else
		vec2 adjTC = texcoord;
	#endif
	
	bool depthCheck = texture2D(depthtex0,adjTC).x >= 1.0;

	//use velocity from the nearest texel from camera in a 3x3 box in order to improve edge quality in motion
	#ifdef CLOSEST_VELOCITY
		#ifdef DISTANT_HORIZONS
			vec3 closestToCamera = closestToCamera5taps_DH(adjTC,	depthtex0, dhDepthTex, depthCheck);
		#else
			vec3 closestToCamera = closestToCamera5taps(adjTC,depthtex0);
		#endif
	#endif

	#ifndef CLOSEST_VELOCITY
		vec3 closestToCamera = vec3(texcoord, texture2D(depthtex1,adjTC).x);
	#endif

	//reproject previous frame
	#ifdef DISTANT_HORIZONS
		vec3 viewPos = toScreenSpace_DH_special(closestToCamera, depthCheck);
	#else
		vec3 viewPos = toScreenSpace(closestToCamera);
	#endif
	
	viewPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);
	
	vec3 previousPosition = mat3(gbufferPreviousModelView) * viewPos + gbufferPreviousModelView[3].xyz;
	previousPosition = toClipSpace3Prev_DH(previousPosition, depthCheck);
	
	vec2 velocity = previousPosition.xy - closestToCamera.xy;
	previousPosition.xy = texcoord + velocity;

	//reject history if off-screen and early exit
	if (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0)
		return vec4(smoothfilter(colortex3, adjTC + offsets[framemod8]*texelSize*0.5).xyz,1.0);


	#ifdef TAA_UPSCALING
		vec3 albedoCurrent0 = smoothfilter(colortex3, adjTC + offsets[framemod8]*texelSize*0.5).xyz;
		// Interpolating neighboorhood clampling boundaries between pixels
		vec3 cMax = texture2D(colortex0, adjTC).rgb;
		vec3 cMin = texture2D(colortex6, adjTC).rgb;
	#else
		vec3 albedoCurrent0 = texture2D(colortex3, adjTC).rgb;
		vec3 albedoCurrent1 = texture2D(colortex3, adjTC + vec2(texelSize.x,texelSize.y)).rgb;
		vec3 albedoCurrent2 = texture2D(colortex3, adjTC + vec2(texelSize.x,-texelSize.y)).rgb;
		vec3 albedoCurrent3 = texture2D(colortex3, adjTC + vec2(-texelSize.x,-texelSize.y)).rgb;
		vec3 albedoCurrent4 = texture2D(colortex3, adjTC + vec2(-texelSize.x,texelSize.y)).rgb;
		vec3 albedoCurrent5 = texture2D(colortex3, adjTC + vec2(0.0,texelSize.y)).rgb;
		vec3 albedoCurrent6 = texture2D(colortex3, adjTC + vec2(0.0,-texelSize.y)).rgb;
		vec3 albedoCurrent7 = texture2D(colortex3, adjTC + vec2(-texelSize.x,0.0)).rgb;
		vec3 albedoCurrent8 = texture2D(colortex3, adjTC + vec2(texelSize.x,0.0)).rgb;
		//Assuming the history color is a blend of the 3x3 neighborhood, we clamp the history to the min and max of each channel in the 3x3 neighborhood
		vec3 cMax = max(max(max(albedoCurrent0,albedoCurrent1),albedoCurrent2),max(albedoCurrent3,max(albedoCurrent4,max(albedoCurrent5,max(albedoCurrent6,max(albedoCurrent7,albedoCurrent8))))));
		vec3 cMin = min(min(min(albedoCurrent0,albedoCurrent1),albedoCurrent2),min(albedoCurrent3,min(albedoCurrent4,min(albedoCurrent5,min(albedoCurrent6,min(albedoCurrent7,albedoCurrent8))))));
		albedoCurrent0 = smoothfilter(colortex3, adjTC + offsets[framemod8]*texelSize*0.5).rgb;
	#endif

	#ifndef SCREENSHOT_MODE
		vec3 albedoPrev = max(FastCatmulRom(colortex5, previousPosition.xy,vec4(texelSize, 1.0/texelSize), 0.75).xyz, 0.0);
		vec3 finalcAcc = clamp(albedoPrev, cMin, cMax);

		//Increases blending factor when far from AABB and in motion, reduces ghosting
		float isclamped = distance(albedoPrev,finalcAcc)/luma(albedoPrev) * 0.5;
		float movementRejection = (0.12+isclamped)*clamp(length(velocity/texelSize),0.0,1.0);

		//Blend current pixel with clamped history, apply fast tonemap beforehand to reduce flickering
		vec4 supersampled = vec4(invTonemap(mix(tonemap(finalcAcc), tonemap(albedoCurrent0), clamp(BLEND_FACTOR + movementRejection, 0.0,1.0))), 1.0);

		//De-tonemap
		return supersampled;
	#endif

	#ifdef SCREENSHOT_MODE
		vec4 albedoPrev = texture2D(colortex5, previousPosition.xy);
		vec3 supersampled =  albedoPrev.rgb * albedoPrev.a + albedoCurrent0;

		if ( hideGUI < 1) return vec4(albedoCurrent0,1.0);
		return vec4(supersampled/(albedoPrev.a+1.0), albedoPrev.a+1.0);
	#endif
}

void main() {
/* DRAWBUFFERS:5 */

	gl_FragData[0].a = 1.0;

	#ifdef TAA
		vec4 color = TAA_hq();

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