#define GAMEPLAY_EFFECTS_RELATED_SETTINGS
#define ANTIALIASING_RELATED_SETTINGS
#define POST_PROCESSING_RELATED_SETTINGS
#define SHADOWMAP_CONSTANT_RELATED_SETTINGS
#include "/lib/settings.glsl"

uniform sampler2D colortex7;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex4;
uniform sampler2D colortex14;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;
uniform sampler2D shadowcolor1;

uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform float frameTime;
uniform float viewHeight;
uniform float viewWidth;
uniform float aspectRatio;

uniform int hideGUI;

uniform vec3 previousCameraPosition;
// uniform vec3 cameraPosition;
uniform mat4 gbufferPreviousModelView;
// uniform mat4 gbufferModelViewInverse;
// uniform mat4 gbufferModelView;

#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/res_params.glsl"
#include "/lib/Shadow_Params.glsl"

uniform float near;
// uniform float far;
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

// float calcDistort(vec2 worldpos){
//   return 1.0/(log(length(worldpos)*b+a)*k);
// }
/*
from https://blog.demofox.org/2022/01/01/interleaved-gradient-noise-a-different-kind-of-low-discrepancy-sequence/
Copyright 2019 Alan Wolfe

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)) ;
	return noise;
}

float blueNoise(){
  return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}

float convertHandDepth_2(in float depth, bool hand) {
	  if(!hand) return depth;

    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    return ndcDepth * 0.5 + 0.5;
}

#include "/lib/util.glsl"
#include "/lib/projections.glsl"
#include "/lib/macro_lod_mod.glsl"
#include "/lib/DistantHorizons_projections.glsl"

#include "/lib/gameplay_effects.glsl"

vec3 doMotionBlur(inout vec2 texcoord, float depth, float noise, bool hand){
  
  float samples = 4.0;
  vec3 color = vec3(0.0);

  float blurMult = 1.0;
  if(hand) blurMult = 0.0;

	vec3 viewPos = toScreenSpace(vec3(texcoord, depth));
	viewPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);

	vec3 previousPosition = mat3(gbufferPreviousModelView) * viewPos + gbufferPreviousModelView[3].xyz;
  previousPosition = toClipSpace3(previousPosition);

	vec2 velocity = texcoord - previousPosition.xy;
  
  // thank you Capt Tatsu for letting me use these
  velocity /= (1.0 + length(velocity)); // ensure the blurring stays sane where UV is beyond 1.0 or -1.0
  velocity /= (1.0 + frameTime*1000.0 * samples * 0.25); // ensure the blur radius stays roughly the same no matter the framerate or sample count
  velocity *= blurMult * (float(MOTION_BLUR_AMOUNT)/20.0); // remove hand blur and add user control

  texcoord = texcoord - velocity*(samples*0.5 + noise);

  vec2 screenEdges = 2.0/vec2(viewWidth, viewHeight);

	for (int i = 0; i < int(samples); i++) {

    texcoord += velocity;
    color += texture(colortex7, clamp(texcoord,screenEdges,1.0-screenEdges)).rgb;

  }
  return color / samples;
}

float doVignette( in vec2 texcoord, in float noise){

  float vignette = 1.0-clamp(1.0-length(texcoord-0.5),0.0,1.0);
  
  // vignette = pow(1.0-pow(1.0-vignette,3),5);
  vignette *= vignette*vignette;
  vignette = 1.0-vignette;
  vignette *= vignette*vignette*vignette*vignette;
  
  // stop banding
  vignette = vignette + vignette*(noise-0.5)*0.01;
  
  return mix(1.0, vignette, float(VIGNETTE_AMOUNT)/100.0);
}

void doCinematicBorders( inout vec3 color, in vec2 texcoord){
  // center + absolute value so you can check both directions at once.
  vec2 uv = abs(texcoord - 0.5) * 2.0;
  // lol
  #if CINEMATIC_BORDER_COVERAGE_VERTICAL > 0 || CINEMATIC_BORDER_COVERAGE_HORIZONTAL > 0
    if(
      #if CINEMATIC_BORDER_COVERAGE_VERTICAL > 0
        uv.y > 1.0 - float(CINEMATIC_BORDER_COVERAGE_VERTICAL)/100.0
      #endif
      #if CINEMATIC_BORDER_COVERAGE_VERTICAL > 0 && CINEMATIC_BORDER_COVERAGE_HORIZONTAL > 0
        ||
      #endif
      #if CINEMATIC_BORDER_COVERAGE_HORIZONTAL > 0
        uv.x > 1.0 - float(CINEMATIC_BORDER_COVERAGE_HORIZONTAL)/100.0
      #endif
    ) color = vec3(0.0);
  #endif
}

void doCameraGridLines(inout vec3 color, in vec2 texcoord){

  float lineThicknessY = 0.001;
  float lineThicknessX = lineThicknessY/aspectRatio;
  
  float horizontalLines = abs(texcoord.x-0.33);
  horizontalLines = min(abs(texcoord.x-0.66), horizontalLines);

  float verticalLines = abs(texcoord.y-0.33);
  verticalLines = min(abs(texcoord.y-0.66), verticalLines);

  float gridLines = horizontalLines < lineThicknessX || verticalLines < lineThicknessY ? 1.0 : 0.0;

  if(hideGUI > 0.0) gridLines = 0.0;
  color = mix(color, vec3(1.0),  gridLines);
}

#ifdef COLOR_KEYING
  void doColorKeying(inout vec3 color){
    // get distance from the camera in meters
    
  #if COLOR_KEY_RANGE > -1
  	#ifdef USING_LOD_MOD
  		float linearDistance = length(mat3(gbufferModelViewInverse)*toScreenSpace_DH(gl_FragCoord.xy*texelSize, texelFetch(depthtex0,ivec2(gl_FragCoord.xy),0).r, texelFetch(LOD_DEPTHTEX0,ivec2(gl_FragCoord.xy),0).r));
    #else
      float linearDistance = length(mat3(gbufferModelViewInverse)*toScreenSpace(vec3(gl_FragCoord.xy*texelSize, texelFetch(depthtex0,ivec2(gl_FragCoord.xy),0).r)));
  	#endif

    // set range(s)
    linearDistance = linearDistance - COLOR_KEY_RANGE;

    // configure width n shiz
    #if COLOR_KEY_WIDTH > 0
      linearDistance /= COLOR_KEY_WIDTH*0.5;
      #ifdef COLOR_KEY_INVERT
        linearDistance = -1.0 + abs(linearDistance);
      #else
        linearDistance = 1.0 - abs(linearDistance);
      #endif
      linearDistance *= COLOR_KEY_WIDTH*0.5;
    #else
      #ifdef COLOR_KEY_INVERT
        linearDistance = 1.0 - linearDistance;
      #else
        linearDistance = -1.0 + linearDistance;
      #endif
    #endif

    // composite
    if(linearDistance > 0.0) color = vec3(COLOR_KEY_R,COLOR_KEY_G,COLOR_KEY_B);

  #else
      #ifdef COLOR_KEY_INVERT
  	    #ifdef USING_LOD_MOD
  	    	if(min(texelFetch(LOD_DEPTHTEX0,ivec2(gl_FragCoord.xy),0).r,texelFetch(depthtex0,ivec2(gl_FragCoord.xy),0).r) < 1.0) color = vec3(COLOR_KEY_R,COLOR_KEY_G,COLOR_KEY_B);
        #else
          if(texelFetch(depthtex0,ivec2(gl_FragCoord.xy),0).r < 1.0) color = vec3(COLOR_KEY_R,COLOR_KEY_G,COLOR_KEY_B);
  	    #endif
      #else
  	    #ifdef USING_LOD_MOD
  	    	if(min(texelFetch(LOD_DEPTHTEX0,ivec2(gl_FragCoord.xy),0).r,texelFetch(depthtex0,ivec2(gl_FragCoord.xy),0).r) >= 1.0) color = vec3(COLOR_KEY_R,COLOR_KEY_G,COLOR_KEY_B);
        #else
          if(texelFetch(depthtex0,ivec2(gl_FragCoord.xy),0).r >= 1.0) color = vec3(COLOR_KEY_R,COLOR_KEY_G,COLOR_KEY_B);
  	    #endif
      #endif
  #endif
  }
#endif

void main() {
  
  float noise = interleaved_gradientNoise();
 
  // pass texcoords through various functions modifying it, so that they are able to stack together
  vec2 texcoord = gl_FragCoord.xy*texelSize;
  vec2 texcoord_offset = texcoord;

  #if PIXEL_ZOOM > 0
	  texcoord_offset = 0.5 + (texcoord_offset-0.5) - (texcoord_offset-0.5) * (float(PIXEL_ZOOM)/100.0f);
	#endif

  #if WATER_ON_CAMERA_EFFECT_AMOUNT > 0
    if(waterInteract > 0.0001 ) getWaterDistortionEffects(texcoord_offset);
  #endif

  #if ON_FIRE_DISTORT_EFFECT_AMOUNT > 0
    if(fireLavaInteract > 0.0) getFireDistortionEffects(texcoord_offset);
  #endif

  // for motion blur and distortion effects to exist, use the distorted texcoord
  #if MOTION_BLUR_AMOUNT > 0
    float depth = texture(depthtex0, texcoord_offset*RENDER_SCALE).r;
    bool hand = depth < 0.56;
    float depth2 = convertHandDepth_2(depth, hand);

    vec3 COLOR = doMotionBlur(texcoord_offset, depth2, noise, hand);
  #else
    vec3 COLOR = texture(colortex7, texcoord_offset).rgb;
  #endif
  
  #if (LOW_HEALTH_EFFECT_START > 0 || CRITICALLY_LOW_HEALTH_EFFECT_START > 0 || MINOR_DAMAGE_TAKEN_EFFECT_START > 0 || CRITICAL_DAMAGE_TAKEN_EFFECT_START > 0)
    // this has red vignette effects so it needs to be done at the end. nothing can happen
    COLOR = getHealthStatusColorEffects(COLOR, texcoord_offset, noise);
  #endif
  
  #if VIGNETTE_AMOUNT > 0
    COLOR *= doVignette(texcoord, noise);
  #endif
  
  #ifdef COLOR_KEYING
    doColorKeying(COLOR);
  #endif

  #if CINEMATIC_BORDER_COVERAGE_VERTICAL > 0 || CINEMATIC_BORDER_COVERAGE_HORIZONTAL > 0
    doCinematicBorders(COLOR, texcoord);
  #endif

  #ifdef CAMERA_GRIDLINES
    doCameraGridLines(COLOR, texcoord);
  #endif

  #if DEBUG_VIEW == debug_SHADOWMAP
    vec2 shadowUV = gl_FragCoord.xy*texelSize;
	  #if PIXEL_ZOOM > 0
	  	shadowUV = 0.5 + (shadowUV-0.5) - (shadowUV-0.5) * (float(PIXEL_ZOOM)/100.0f);
	  #endif
    shadowUV.xy -= vec2(0.5,0.5);
    shadowUV.xy *= vec2(2.0, 1.0);
    shadowUV.xy *= 5.0;
		float distortFactor = calcDistort(shadowUV.xy);
    shadowUV.xy *= distortFactor;
    shadowUV.xy = shadowUV.xy * 0.5 + 0.5;
      
    if(shadowUV.x < 1.0 && shadowUV.y < 1.0 && shadowUV.x > 0.0 && shadowUV.y > 0.0 && hideGUI == 0) COLOR = texture(shadowcolor1,shadowUV).rgb;
  #endif
  #if DEBUG_VIEW == debug_DEPTHTEX0
    COLOR = vec3(ld(texture(depthtex0, texcoord*RENDER_SCALE).r));
  #endif
  #if DEBUG_VIEW == debug_DEPTHTEX1
    COLOR = vec3(ld(texture(depthtex1, texcoord*RENDER_SCALE).r));
  #endif

  gl_FragColor.rgb = COLOR;
}