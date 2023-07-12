#version 120
//Vignetting, applies bloom, applies exposure and tonemaps the final image
//#extension GL_EXT_gpu_shader4 : disable

#include "/lib/settings.glsl"

varying vec2 texcoord;

uniform sampler2D colortex7;
// uniform sampler2D noisetex;
uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform int isEyeInWater;


#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/res_params.glsl"
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

/// thanks stackoverflow https://stackoverflow.com/questions/944713/help-with-pixel-shader-effect-for-brightness-and-contrast#3027595
void applyContrast(inout vec3 color, float contrast){
  color = (color - 0.5) * contrast + 0.5;
}

float lowerCurve(float x) {
	float y = 16 * x * (0.5 - x) * 0.1;
	return clamp(y, 0.0, 1.0);
}
float upperCurve(float x) {
	float y = 16 * (0.5 - x) * (x - 1.0) * 0.1;
	return clamp(y, 0.0, 1.0);
}
void applyLuminanceCurve(inout vec3 color, float darks, float brights){

  	// color.r = color.r < 0.5 ? pow(2.0 * color.r, darks) / 2.0 : 1.0 - (pow(2.0 - 2.0 * color.r, brights) / 2.0);
	// color.g = color.g < 0.5 ? pow(2.0 * color.g, darks) / 2.0 : 1.0 - (pow(2.0 - 2.0 * color.g, brights) / 2.0);
	// color.b = color.b < 0.5 ? pow(2.0 * color.b, darks) / 2.0 : 1.0 - (pow(2.0 - 2.0 * color.b, brights) / 2.0);
	color.r += darks * lowerCurve(color.r) + brights * upperCurve(color.r);
	color.g += darks * lowerCurve(color.g) + brights * upperCurve(color.g);
	color.b += darks * lowerCurve(color.b) + brights * upperCurve(color.b);
}

void main() {
  #ifdef BICUBIC_UPSCALING
    vec3 col = SampleTextureCatmullRom(colortex7,texcoord,1.0/texelSize).rgb;
  #else
    vec3 col = texture2D(colortex7,texcoord).rgb;
  #endif


  #ifdef CONTRAST_ADAPTATIVE_SHARPENING
    //Weights : 1 in the center, 0.5 middle, 0.25 corners
    vec3 albedoCurrent1 = texture2D(colortex7, texcoord + vec2(texelSize.x,texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;
    vec3 albedoCurrent2 = texture2D(colortex7, texcoord + vec2(texelSize.x,-texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;
    vec3 albedoCurrent3 = texture2D(colortex7, texcoord + vec2(-texelSize.x,-texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;
    vec3 albedoCurrent4 = texture2D(colortex7, texcoord + vec2(-texelSize.x,texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;


    vec3 m1 = -0.5/3.5*col + albedoCurrent1/3.5 + albedoCurrent2/3.5 + albedoCurrent3/3.5 + albedoCurrent4/3.5;
    vec3 std = abs(col - m1) + abs(albedoCurrent1 - m1) + abs(albedoCurrent2 - m1) +
     abs(albedoCurrent3 - m1) + abs(albedoCurrent3 - m1) + abs(albedoCurrent4 - m1);
    float contrast = 1.0 - luma(std)/5.0;
    col = col*(1.0+(SHARPENING+UPSCALING_SHARPNENING)*contrast)
          - (SHARPENING+UPSCALING_SHARPNENING)/(1.0-0.5/3.5)*contrast*(m1 - 0.5/3.5*col);
  #endif

  float lum = luma(col);
  vec3 diff = col-lum;
  col = col + diff*(-lum*CROSSTALK + SATURATION);
  
	vec3 FINAL_COLOR = clamp(int8Dither(col,texcoord),0.0,1.0);

  #ifdef LUMINANCE_CURVE
    applyLuminanceCurve(FINAL_COLOR, LOWER_CURVE, UPPER_CURVE);
  #endif

	applyContrast(FINAL_COLOR, CONTRAST); // for fun

  gl_FragColor.rgb = FINAL_COLOR ;
}
