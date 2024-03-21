#include "/lib/settings.glsl"

varying vec2 texcoord;

uniform sampler2D colortex7;
uniform vec2 texelSize;
uniform float frameTimeCounter;

uniform sampler2D shadow;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

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
vec3 toneCurve(vec3 color){
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

#ifdef HURT_AND_DEATH_EFFECT
  uniform float hurt;
  uniform float dying;
  uniform float dead;
  
  void PlayerDamagedEffect(inout vec3 outColor){
  
    if(dying > 0){
    
    	float vignette2 = clamp(1.0 - exp(-(sin(frameTimeCounter*7)*15+50) * dot(texcoord-0.5,texcoord-0.5)),0.0,1.0);
  
      outColor = mix(outColor, vec3(0.0), min(dying,1.0)*vignette2);
      outColor = mix(outColor, vec3(0.0), dead);
  
    }else{
    
    	float vignette = clamp(1.0 - exp(-5 * dot(texcoord-0.5,texcoord-0.5)),0.0,1.0);
  
      outColor = mix(outColor, vec3(0.3,0.0,0.0), vignette*sqrt(hurt));
  
    }
  }
#endif

uniform int hideGUI;
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

  #ifdef HURT_AND_DEATH_EFFECT
    PlayerDamagedEffect(col);
  #endif
  
	vec3 FINAL_COLOR = clamp(int8Dither(col,texcoord),0.0,1.0);

  #ifdef TONE_CURVE
	  FINAL_COLOR = toneCurve(FINAL_COLOR);
  #endif

  #ifdef COLOR_GRADING_ENABLED
	  FINAL_COLOR = colorGrading(FINAL_COLOR);
  #endif

	applyContrast(FINAL_COLOR, CONTRAST); // for fun

  gl_FragColor.rgb = FINAL_COLOR;

  #if DEBUG_VIEW == debug_SHADOWMAP 
    if(texcoord.x < 0.25 && texcoord.y < 0.5) gl_FragColor.rgb = texture2D(shadowcolor0, (texcoord * vec2(2.0, 1.0) * 2 - vec2(0.0, 0.0)) ).rgb * vec3(1.0);
  #endif
}
