#version 120
//Temporal Anti-Aliasing + Dynamic exposure calculations (vertex shader)
#extension GL_EXT_gpu_shader4 : disable

#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

const int noiseTextureResolution = 32;


/*
const int colortex0Format = RGBA16F;				// low res clouds (deferred->composite2) + low res VL (composite5->composite15)
const int colortex1Format = RGBA16;					//terrain gbuffer (gbuffer->composite2)
const int colortex2Format = RGBA16F;				//forward + transparencies (gbuffer->composite4)
const int colortex3Format = R11F_G11F_B10F;			//frame buffer + bloom (deferred6->final)
const int colortex4Format = RGBA16F;				//light values and skyboxes (everything)
const int colortex5Format = R11F_G11F_B10F;			//TAA buffer (everything)
const int colortex6Format = R11F_G11F_B10F;			//additionnal buffer for bloom (composite3->final)
const int colortex7Format = RGBA8;			//Final output, transparencies id (gbuffer->composite4)
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

varying vec2 texcoord;
flat varying float exposureA;
flat varying float tempOffsets;
uniform sampler2D colortex3;
uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform int framemod8;
uniform float viewHeight;
uniform float viewWidth;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;




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
vec3 fp10Dither(vec3 color,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}


//returns the projected coordinates of the closest point to the camera in the 3x3 neighborhood
vec3 closestToCamera3x3()
{
	vec2 du = vec2(texelSize.x, 0.0);
	vec2 dv = vec2(0.0, texelSize.y);

	vec3 dtl = vec3(texcoord,0.) + vec3(-texelSize, texture2D(depthtex0, texcoord - dv - du).x);
	vec3 dtc = vec3(texcoord,0.) + vec3( 0.0, -texelSize.y, texture2D(depthtex0, texcoord - dv).x);
	vec3 dtr = vec3(texcoord,0.) +  vec3( texelSize.x, -texelSize.y, texture2D(depthtex0, texcoord - dv + du).x);

	vec3 dml = vec3(texcoord,0.) +  vec3(-texelSize.x, 0.0, texture2D(depthtex0, texcoord - du).x);
	vec3 dmc = vec3(texcoord,0.) + vec3( 0.0, 0.0, texture2D(depthtex0, texcoord).x);
	vec3 dmr = vec3(texcoord,0.) + vec3( texelSize.x, 0.0, texture2D(depthtex0, texcoord + du).x);

	vec3 dbl = vec3(texcoord,0.) + vec3(-texelSize.x, texelSize.y, texture2D(depthtex0, texcoord + dv - du).x);
	vec3 dbc = vec3(texcoord,0.) + vec3( 0.0, texelSize.y, texture2D(depthtex0, texcoord + dv).x);
	vec3 dbr = vec3(texcoord,0.) + vec3( texelSize.x, texelSize.y, texture2D(depthtex0, texcoord + dv + du).x);

	vec3 dmin = dmc;

	dmin = dmin.z > dtc.z? dtc : dmin;
	dmin = dmin.z > dtr.z? dtr : dmin;

	dmin = dmin.z > dml.z? dml : dmin;
	dmin = dmin.z > dtl.z? dtl : dmin;
	dmin = dmin.z > dmr.z? dmr : dmin;

	dmin = dmin.z > dbl.z? dbl : dmin;
	dmin = dmin.z > dbc.z? dbc : dmin;
	dmin = dmin.z > dbr.z? dbr : dmin;

	return dmin;
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
//Due to low sample count we "tonemap" the inputs to preserve colors and smoother edges
vec3 weightedSample(sampler2D colorTex, vec2 texcoord){
	vec3 wsample = texture2D(colorTex,texcoord).rgb*exposureA;
	return wsample/(1.0+luma(wsample));

}


//from : https://gist.github.com/TheRealMJP/c83b8c0f46b63f3a88a5986f4fa982b1
vec4 SampleTextureCatmullRom(sampler2D tex, vec2 uv, vec2 texSize )
{
    // We're going to sample a a 4x4 grid of texels surrounding the target UV coordinate. We'll do this by rounding
    // down the sample location to get the exact center of our "starting" texel. The starting texel will be at
    // location [1, 1] in the grid, where [0, 0] is the top left corner.
    vec2 samplePos = uv * texSize;
    vec2 texPos1 = floor(samplePos - 0.5) + 0.5;

    // Compute the fractional offset from our starting texel to our original sample location, which we'll
    // feed into the Catmull-Rom spline function to get our filter weights.
    vec2 f = samplePos - texPos1;

    // Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
    // These equations are pre-expanded based on our knowledge of where the texels will be located,
    // which lets us avoid having to evaluate a piece-wise function.
    vec2 w0 = f * ( -0.5 + f * (1.0 - 0.5*f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5*f);
    vec2 w2 = f * ( 0.5 + f * (2.0 - 1.5*f) );
    vec2 w3 = f * f * (-0.5 + 0.5 * f);

    // Work out weighting factors and sampling offsets that will let us use bilinear filtering to
    // simultaneously evaluate the middle 2 samples from the 4x4 grid.
    vec2 w12 = w1 + w2;
    vec2 offset12 = w2 / (w1 + w2);

    // Compute the final UV coordinates we'll use for sampling the texture
    vec2 texPos0 = texPos1 - vec2(1.0);
    vec2 texPos3 = texPos1 + vec2(2.0);
    vec2 texPos12 = texPos1 + offset12;

    texPos0 *= texelSize;
    texPos3 *= texelSize;
    texPos12 *= texelSize;

    vec4 result = vec4(0.0);
    result += texture2D(tex, vec2(texPos0.x,  texPos0.y)) * w0.x * w0.y;
    result += texture2D(tex, vec2(texPos12.x, texPos0.y)) * w12.x * w0.y;
    result += texture2D(tex, vec2(texPos3.x,  texPos0.y)) * w3.x * w0.y;

    result += texture2D(tex, vec2(texPos0.x,  texPos12.y)) * w0.x * w12.y;
    result += texture2D(tex, vec2(texPos12.x, texPos12.y)) * w12.x * w12.y;
    result += texture2D(tex, vec2(texPos3.x,  texPos12.y)) * w3.x * w12.y;

    result += texture2D(tex, vec2(texPos0.x,  texPos3.y)) * w0.x * w3.y;
    result += texture2D(tex, vec2(texPos12.x, texPos3.y)) * w12.x * w3.y;
    result += texture2D(tex, vec2(texPos3.x,  texPos3.y)) * w3.x * w3.y;

    return result;
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

vec3 clip_aabb(vec3 q,vec3 aabb_min, vec3 aabb_max)
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

	return dmin;
}
const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);

vec3 TAA_hq(){

	vec2 adjTC = texcoord;


	//use velocity from the nearest texel from camera in a 3x3 box in order to improve edge quality in motion
	#ifdef CLOSEST_VELOCITY
		vec3 closestToCamera = closestToCamera5taps(adjTC,	depthtex0);
	#endif

	#ifndef CLOSEST_VELOCITY
		vec3 closestToCamera = vec3(texcoord,texture2D(depthtex1,adjTC).x);
	#endif

	//reproject previous frame
	vec3 fragposition = toScreenSpace(closestToCamera);
	fragposition = mat3(gbufferModelViewInverse) * fragposition + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * fragposition + gbufferPreviousModelView[3].xyz;
	previousPosition = toClipSpace3Prev(previousPosition);
	vec2 velocity = previousPosition.xy - closestToCamera.xy;
	previousPosition.xy = texcoord + velocity;

	//reject history if off-screen and early exit
	if (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0)
		return smoothfilter(colortex3, adjTC + offsets[framemod8]*texelSize*0.5).xyz;


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


	#ifndef NO_CLIP
	vec3 albedoPrev = max(FastCatmulRom(colortex5, previousPosition.xy,vec4(texelSize, 1.0/texelSize), 0.75).xyz, 0.0);
	vec3 finalcAcc = clamp(albedoPrev,cMin,cMax);

	//Increases blending factor when far from AABB and in motion, reduces ghosting
	float isclamped = distance(albedoPrev,finalcAcc)/luma(albedoPrev) * 0.5;
	float movementRejection = (0.12+isclamped)*clamp(length(velocity/texelSize),0.0,1.0);
	
	float test = 0.05;
	// if(hand) movementRejection *= 5;
	// if(istranslucent) test = 0.1;

	//Blend current pixel with clamped history, apply fast tonemap beforehand to reduce flickering
	// vec3 supersampled = invTonemap(mix(tonemap(finalcAcc),tonemap(albedoCurrent0),clamp(BLEND_FACTOR + movementRejection, min(luma(motionVector) *255,1.0),1.)));
	
	vec3 supersampled = invTonemap(mix(tonemap(finalcAcc),tonemap(albedoCurrent0),clamp(BLEND_FACTOR + movementRejection, test,1.)));
	#endif


	#ifdef NO_CLIP
		vec3 albedoPrev = texture2D(colortex5, previousPosition.xy).xyz;
		vec3 supersampled =  mix(albedoPrev,albedoCurrent0,clamp(0.05,0.,1.));
	#endif

	//De-tonemap
	return supersampled;
}

void main() {

/* DRAWBUFFERS:5 */
	gl_FragData[0].a = 1.0;

	#ifdef TAA
		vec3 color = TAA_hq();
		gl_FragData[0].rgb = clamp(fp10Dither(color,triangularize(interleaved_gradientNoise())),6.11*1e-5,65000.0);
	#endif

	#ifndef TAA
		vec3 color = clamp(fp10Dither(texture2D(colortex3,texcoord).rgb,triangularize(interleaved_gradientNoise())),0.,65000.);
		gl_FragData[0].rgb = color;
	#endif





}
