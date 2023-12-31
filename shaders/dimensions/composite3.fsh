#include "/lib/settings.glsl"

flat varying vec3 zMults;
flat varying vec2 TAA_Offset;

flat varying vec3 skyGroundColor;

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
// uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex15;
uniform vec2 texelSize;

#if defined NETHER_SHADER || defined END_SHADER
  uniform sampler2D colortex4;
#endif

flat varying vec4 lightCol; //main light source color (rgb),used light source(1=sun,-1=moon)
flat varying vec3 WsunVec;

uniform vec3 sunVec;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform float far;
uniform float near;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform float rainStrength;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;


#include "/lib/waterBump.glsl"
#include "/lib/res_params.glsl"

#ifdef OVERWORLD_SHADER
  #include "/lib/sky_gradient.glsl"
  #include "/lib/lightning_stuff.glsl"
  #include "/lib/volumetricClouds.glsl"
#endif
#ifndef OVERWORLD_SHADER
  #include "/lib/climate_settings.glsl"
#endif


#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

float ld(float depth) {
    return 1.0 / (zMults.y - depth * zMults.z);		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}
float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}
vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}


// #include "/lib/specular.glsl"




vec4 BilateralUpscale(sampler2D tex, sampler2D depth,vec2 coord,float frDepth){
  coord = coord;
  vec4 vl = vec4(0.0);
  float sum = 0.0;
  mat3x3 weights;
  const ivec2 scaling = ivec2(1.0/VL_RENDER_RESOLUTION);
  ivec2 posD = ivec2(coord*VL_RENDER_RESOLUTION)*scaling;
  ivec2 posVl = ivec2(coord*VL_RENDER_RESOLUTION);
  float dz = zMults.x;
  ivec2 pos = (ivec2(gl_FragCoord.xy) % 2 )*2;
	//pos = ivec2(1,-1);

  ivec2 tcDepth =  posD + ivec2(-2,-2) * scaling + pos * scaling;
  float dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  float w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(-2)+pos,0)*w;
  sum += w;

	tcDepth =  posD + ivec2(-2,0) * scaling + pos * scaling;
  dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(-2,0)+pos,0)*w;
  sum += w;

	tcDepth =  posD + ivec2(0) + pos * scaling;
  dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(0)+pos,0)*w;
  sum += w;

	tcDepth =  posD + ivec2(0,-2) * scaling + pos * scaling;
  dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(0,-2)+pos,0)*w;
  sum += w;

  return vl/sum;
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

vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord )%512  , 0);
}
vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
vec3 viewToWorld(vec3 viewPosition) {
    vec4 pos;
    pos.xyz = viewPosition;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}

/// thanks stackoverflow https://stackoverflow.com/questions/944713/help-with-pixel-shader-effect-for-brightness-and-contrast#3027595
void applyContrast(inout vec3 color, float contrast){
  color = ((color - 0.5) * max(contrast, 0.0)) + 0.5;
}

void ApplyDistortion(inout vec2 Texcoord, vec2 TangentNormals, vec2 depths){

  vec2 UnalteredTexcoord = Texcoord;

  Texcoord = abs(Texcoord + (TangentNormals * clamp((ld(depths.x) - ld(depths.y)) * 0.5,0.0,0.15)) * RENDER_SCALE );

  float DistortedAlpha = decodeVec2(texture2D(colortex11,Texcoord).b).g;
  
  if(DistortedAlpha <= 0.001) Texcoord = UnalteredTexcoord; // remove distortion on non-translucents
}

uniform float eyeAltitude;

void main() {
  /* DRAWBUFFERS:73 */

	////// --------------- SETUP STUFF --------------- //////
  vec2 texcoord = gl_FragCoord.xy*texelSize;

  float z = texture2D(depthtex0,texcoord).x;
  float z2 = texture2D(depthtex1,texcoord).x;
  float frDepth = ld(z2);

	vec2 tempOffset = TAA_Offset;
	vec3 fragpos = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z));
	vec3 fragpos2 = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z2));
  
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);

  float linearDistance = length(p3);

	float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2) ,0.0,1.0);
	float lightleakfixfast = clamp(eyeBrightness.y/240.,0.0,1.0);

	////// --------------- UNPACK TRANSLUCENT GBUFFERS --------------- //////
	vec3 data = texture2D(colortex11,texcoord).rgb;
	vec4 unpack0 =  vec4(decodeVec2(data.r),decodeVec2(data.g)) ;
	vec4 unpack1 = vec4(decodeVec2(data.b),0,0) ;
	
	vec4 albedo = vec4(unpack0.ba,unpack1.rg);
	vec2 tangentNormals = unpack0.xy*2.0-1.0;
  if(albedo.a <= 0.0) tangentNormals = vec2(0.0);
  vec4 TranslucentShader = texture2D(colortex2,texcoord);

	////// --------------- UNPACK MISC --------------- //////
  float trpData = texture2D(colortex7,texcoord).a;

	////// --------------- MASKS/BOOLEANS --------------- //////
  bool iswater = trpData > 0.99;
  float translucentAlpha = trpData;

  ////// --------------- get volumetrics
  vec4 vl = BilateralUpscale(colortex0, depthtex1, gl_FragCoord.xy, frDepth);
  float bloomyFogMult = 1.0;

  ////// --------------- distort texcoords as a refraction effect
  vec2 refractedCoord = texcoord;
  #ifdef Refraction
    ApplyDistortion(refractedCoord, tangentNormals, vec2(z2,z));
  #endif
  
  ////// --------------- MAIN COLOR BUFFER
  vec3 color = texture2D(colortex3, refractedCoord).rgb;


  ////// --------------- BLEND TRANSLUCENT GBUFFERS 
  //////////// and do border fog on opaque and translucents

  #if defined BorderFog
  	float fog =  exp(-50.0 * pow(clamp(1.0-linearDistance/far,0.0,1.0),2.0));
  	fog *= exp(-10.0 * pow(clamp(np3.y,0.0,1.0)*4.0,2.0));
    if(z >= 1.0 || isEyeInWater != 0) fog = 0.0;
    
    if(lightleakfixfast < 1.0) fog *= lightleakfix;

    color.rgb = mix(color.rgb, skyGroundColor, fog);
  #endif

  if (TranslucentShader.a > 0.0){
		#ifdef Glass_Tint
      if(albedo.a > 0.2) color = color*albedo.rgb + color * clamp(pow(1.0-luma(albedo.rgb),20.),0.0,1.0);
    #endif

    color = color*(1.0-TranslucentShader.a) + TranslucentShader.rgb; 

    #ifdef BorderFog
      color.rgb = mix(color.rgb, skyGroundColor, fog);
    #endif
  } 

////// --------------- VARIOUS FOG EFFECTS (behind volumetric fog)
//////////// blindness, nightvision, liquid fogs and misc fogs

#if defined OVERWORLD_SHADER && defined CAVE_FOG
    if (isEyeInWater == 0 && eyeAltitude < 1500 && lightleakfix < 1.0){

      float cavefog = clamp( pow(linearDistance / far, CaveFogFallOff) ,0.0,1.0);
      cavefog = cavefog*0.95 + clamp( pow(1.0 - exp((linearDistance / far) * -5), 2.0) ,0.0,1.0)*0.05;

  	  cavefog *= exp(-30.0*(pow(clamp(np3.y-0.5,0.0,1.0),2.0))); // create a hole in the fog above, so the sky is a little visible.

      vec3 cavefogCol = vec3(CaveFogColor_R, CaveFogColor_G, CaveFogColor_B);
      cavefogCol *= clamp( exp(clamp(np3.y * 0.5 + 0.5,0,1) * -3.0)  ,0.0,1.0); // apply a vertical gradient to the fog color

      #ifdef PER_BIOME_ENVIRONMENT
        BiomeFogColor(cavefogCol);
      #endif

      color.rgb = mix(color.rgb,  cavefogCol,  cavefog * (1-lightleakfix));
    }
#endif

////// --------------- Distance fog for the end shader
#ifdef END_SHADER
    if (isEyeInWater == 0){
      vec3 hazeColor = vec3(0.3,0.75,1.0) * 0.3;

      float hazeDensity = clamp(1.0 - linearDistance / max(far, 32.0 * 24.0),0.0,1.0);
      color.rgb = mix(hazeColor,  color.rgb,  hazeDensity) ; 
    }
#endif

////// --------------- underwater fog
  if (isEyeInWater == 1){
    float dirtAmount = Dirt_Amount;
    vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
    vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
    vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;

    vec3 fogfade =  clamp( exp( (linearDistance / -4) * totEpsilon  ) ,0.0,1.0);
    fogfade *= 1.0 - clamp( linearDistance / far,0.0,1.0);

    color.rgb *= fogfade;
    bloomyFogMult *= 0.3;
  }

////// --------------- BLEND FOG INTO SCENE
//////////// apply VL fog over opaque and translucents
  color *= vl.a;
  color += vl.rgb;
  
////// --------------- VARIOUS FOG EFFECTS (in front of volumetric fog)
//////////// blindness, nightvision, liquid fogs and misc fogs

////// --------------- bloomy rain effect
  #ifdef OVERWORLD_SHADER
    float rainDrops =  clamp(texture2D(colortex9,texcoord).a,  0.0,1.0); 
    if(rainDrops > 0.0) bloomyFogMult *= clamp(1.0 - pow(rainDrops*5.0,2),0.0,1.0);
  #endif
  
////// --------------- lava.
  if (isEyeInWater == 2){
    color.rgb = vec3(4.0,0.5,0.1);
  }

///////// --------------- powdered snow
  if (isEyeInWater == 3){
    color.rgb = mix(color.rgb,vec3(10,15,20),clamp(linearDistance*0.5,0.,1.));
    bloomyFogMult = 0.0;
  }

////// --------------- blidnesss
  color.rgb *= mix(1.0,clamp( exp(pow(linearDistance*(blindness*0.2),2) * -5),0.,1.)   ,    blindness);

//////// --------------- darkness effect
  color.rgb *= mix(1.0, (1.0-darknessLightFactor*2.0) * clamp(1.0-pow(length(fragpos2)*(darknessFactor*0.07),2.0),0.0,1.0), darknessFactor);
  
////// --------------- FINALIZE
  #ifdef display_LUT
  	vec2 movedTC = texcoord;
    vec3 thingy = texture2D(colortex4,movedTC).rgb / 30;

    if(luma(thingy) > 0.0){
      color.rgb =  thingy;
      vl.a = 1.0;
    }
  #endif

  gl_FragData[0].r = vl.a * bloomyFogMult; // pass fog alpha so bloom can do bloomy fog
  gl_FragData[1].rgb = clamp(color.rgb, 0.0,68000.0);
}