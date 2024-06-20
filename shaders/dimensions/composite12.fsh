#include "/lib/settings.glsl"

varying vec2 texcoord;
uniform vec2 texelSize;

uniform sampler2D colortex7;
uniform sampler2D colortex14;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform float viewHeight;
uniform float viewWidth;
uniform float aspectRatio;

uniform float frameTimeCounter;

uniform int hideGUI;

#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/res_params.glsl"

/*
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
*/

float lowerCurve(float x) {
	float y = 16 * x * (0.5 - x) * 0.1;
	return clamp(y, 0.0, 1.0);
}

float upperCurve(float x) {
	float y = 16 * (0.5 - x) * (x - 1.0) * 0.1;
	return clamp(y, 0.0, 1.0);
}

vec3 luminanceCurve(vec3 color){
	color.r += LOWER_CURVE * lowerCurve(color.r) + UPPER_CURVE * upperCurve(color.r);
	color.g += LOWER_CURVE * lowerCurve(color.g) + UPPER_CURVE * upperCurve(color.g);
	color.b += LOWER_CURVE * lowerCurve(color.b) + UPPER_CURVE * upperCurve(color.b);
	return color;
}

vec3 colorGrading(vec3 color) {
	float grade_luma = dot(color, vec3(1.0 / 3.0));
  float shadows_amount = saturate(-6.0 * grade_luma + 2.75);
	float mids_amount = saturate(-abs(6.0 * grade_luma - 3.0) + 1.25);
	float highlights_amount = saturate(6.0 * grade_luma - 3.25);

	vec3 graded_shadows = color * SHADOWS_TARGET * SHADOWS_GRADE_MUL * 1.7320508076;
	vec3 graded_mids = color * MIDS_TARGET * MIDS_GRADE_MUL * 1.7320508076;
	vec3 graded_highlights = color * HIGHLIGHTS_TARGET * HIGHLIGHTS_GRADE_MUL * 1.7320508076;

	return saturate(graded_shadows * shadows_amount + graded_mids * mids_amount + graded_highlights * highlights_amount);
}

vec3 contrastAdaptiveSharpening(vec3 color, vec2 texcoord){

  //Weights : 1 in the center, 0.5 middle, 0.25 corners
  vec3 albedoCurrent1 = texture2D(colortex7, texcoord + vec2(texelSize.x,texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;
  vec3 albedoCurrent2 = texture2D(colortex7, texcoord + vec2(texelSize.x,-texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;
  vec3 albedoCurrent3 = texture2D(colortex7, texcoord + vec2(-texelSize.x,-texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;
  vec3 albedoCurrent4 = texture2D(colortex7, texcoord + vec2(-texelSize.x,texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;
 
  vec3 m1 = -0.5/3.5*color + albedoCurrent1/3.5 + albedoCurrent2/3.5 + albedoCurrent3/3.5 + albedoCurrent4/3.5;
  
  vec3 std = abs(color - m1) + abs(albedoCurrent1 - m1) + abs(albedoCurrent2 - m1) +
  abs(albedoCurrent3 - m1) + abs(albedoCurrent3 - m1) + abs(albedoCurrent4 - m1);

  float contrast = 1.0 - luma(std)/5.0;

  color = color*(1.0+(SHARPENING+UPSCALING_SHARPNENING)*contrast) -
  (SHARPENING+UPSCALING_SHARPNENING)/(1.0-0.5/3.5)*contrast*(m1 - 0.5/3.5*color); 

  return color;
}

vec3 saturationAndCrosstalk(vec3 color){

	float luminance = luma(color);

	vec3 lumaColDiff = color - luminance;

	color = color + lumaColDiff*(-luminance*CROSSTALK + SATURATION);
  
  return color;
}

void main() {

  /* DRAWBUFFERS:7 */

	vec3 color = texture2D(colortex7,texcoord).rgb;

	#ifdef CONTRAST_ADAPTATIVE_SHARPENING
    color = contrastAdaptiveSharpening(color, texcoord);
	#endif
  
  color = saturationAndCrosstalk(color);
  
  #ifdef LUMINANCE_CURVE
	  color = luminanceCurve(color);
  #endif

  #ifdef COLOR_GRADING_ENABLED
	  color = colorGrading(color);
  #endif

	gl_FragData[0].rgb = clamp(int8Dither(color, texcoord),0.0,1.0);
}
