#version 120
//Horizontal bilateral blur for volumetric fog + Forward rendered objects + Draw volumetric fog
#extension GL_EXT_gpu_shader4 : enable

#define Cave_fog // cave fog....
#define CaveFogFallOff 1.3 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 ] 

#define CaveFogColor_R 0.1 //  [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define CaveFogColor_G 0.2  //  [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define CaveFogColor_B 0.5   //  [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]

// #define display_LUT // aaaaaaaaaaaaaaaaaaaaaaa

varying vec2 texcoord;
flat varying vec3 zMults;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex7;
uniform sampler2D colortex3;
// uniform sampler2D colortex4;
uniform sampler2D colortex2;
uniform sampler2D colortex0;
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform int frameCounter;
uniform float far;
uniform float near;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec2 texelSize;
uniform vec3 cameraPosition;

uniform mat4  gbufferModelView;

uniform float isWastes;
uniform float isWarpedForest;
uniform float isCrimsonForest;
uniform float isSoulValley;
uniform float isBasaltDelta;

uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform float rainStrength;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float nightVision;



#include "lib/waterBump.glsl"
#include "lib/waterOptions.glsl"
#include "lib/volumetricClouds.glsl"
float ld(float depth) {
    return 1.0 / (zMults.y - depth * zMults.z);		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}
vec4 BilateralUpscale(sampler2D tex, sampler2D depth,vec2 coord,float frDepth){
  vec4 vl = vec4(0.0);
  float sum = 0.0;
  mat3x3 weights;
  ivec2 posD = ivec2(coord/2.0)*2;
  ivec2 posVl = ivec2(coord/2.0);
  float dz = zMults.x;
  ivec2 pos = (ivec2(gl_FragCoord.xy+frameCounter) % 2 )*2;
	//pos = ivec2(1,-1);

  ivec2 tcDepth =  posD + ivec2(-4,-4) + pos*2;
  float dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  float w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(-2)+pos,0)*w;
  sum += w;

	tcDepth =  posD + ivec2(-4,0) + pos*2;
  dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(-2,0)+pos,0)*w;
  sum += w;

	tcDepth =  posD + ivec2(0) + pos*2;
  dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(0)+pos,0)*w;
  sum += w;

	tcDepth =  posD + ivec2(0,-4) + pos*2;
  dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(0,-2)+pos,0)*w;
  sum += w;

  return vl/sum;
}
float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}
void main() {
  /* DRAWBUFFERS:73 */
  //3x3 bilateral upscale from half resolution
  float z = texture2D(depthtex0,texcoord).x;
  float z2 = texture2D(depthtex1,texcoord).x;
  float frDepth = ld(z);
  vec4 vl = BilateralUpscale(colortex0,depthtex0,gl_FragCoord.xy,frDepth);



  vec4 transparencies = texture2D(colortex2,texcoord);
  vec4 trpData = texture2D(colortex7,texcoord);
  bool iswater = trpData.a > 0.99;
  vec2 refractedCoord = texcoord;

  vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z));
  vec3 fragpos2 = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z2));
  // vec3 np3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz + cameraPosition;

	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);


  if (iswater){
    float norm = getWaterHeightmap(np3.xz*1.71, 4.0, 0.25, 1.0);
    float displ = norm/(length(fragpos)/far)/35.;
    refractedCoord += displ;

    if (texture2D(colortex7,refractedCoord).a < 0.99)
      refractedCoord = texcoord;

  }

  
  vec3 color = texture2D(colortex3,refractedCoord).rgb;
  if (frDepth > 2.5/far || transparencies.a < 0.99)  // Discount fix for transparencies through hand
    color = color*(1.0-transparencies.a)+transparencies.rgb*10.;

  float dirtAmount = Dirt_Amount;
	vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
	vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
	vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;

  color *= vl.a;


	// vec3 fogColor = clamp(gl_Fog.color.rgb*pow(luma(gl_Fog.color.rgb),-0.75)*0.65,0.0,1.0)*0.05;

  /// lightnign flashes fog
  // if (isEyeInWater == 0){

  //   vec3 lightSource = normalize(WsunVec);
	//   vec3 viewspace_sunvec = mat3(gbufferModelView) * lightSource;
	//   float SdotV = dot(normalize(viewspace_sunvec), normalize(fragpos));
	//   float lightning_shine = clamp(phaseg(SdotV, 0.35) ,0,1);

  //   vec3 flashingfogCol = SunCol * 0.25;
  //   float flashingfogdist = clamp(pow(length(fragpos)/far,5.), 0.0, 1.0) ;
  //   color.rgb += flashingfogCol * lightning_shine	* flashingfogdist;
  //   // vl.a *= 1.0 - sqrt(flashingfogdist);
  // }




  // underwater fog
  if (isEyeInWater == 1){
    // color.rgb *= exp(-length(fragpos)/2*totEpsilon);
    // vl.a *= (dot(exp(-length(fragpos)/1.2*totEpsilon),vec3(0.2,0.7,0.1)))*0.5+0.5;
    
    float fogfade = clamp(exp(-length(fragpos) /12 )   ,0.0,1.0);
    float fogcolfade =  clamp(exp(np3.y*1.5 - 1.5),0.0,1.0);
    color.rgb *= fogfade;
    color.rgb = color.rgb * (1.0 + vec3(0.0,0.1,0.2) * 12 * (1.0 - fogfade)) + (vec3(0.0,0.1,0.2) * 0.5 * (1.0 - fogfade))*fogcolfade;
   
    vl.a *= fogfade*0.75 +0.25;
  }
  /// lava.
  if (isEyeInWater == 2){
    color.rgb = vec3(4.0,0.5,0.1);
  }
  /// powdered snow
  if (isEyeInWater == 3){
    color.rgb = mix(color.rgb,vec3(10,15,20),clamp(length(fragpos)*0.5,0.,1.));
    vl.a = 0.0;
  }
  // blidnesss
  color.rgb *= mix(1.0, clamp(1.5-pow(length(fragpos2)*(blindness*0.2),2.0),0.0,1.0), blindness);
  // darkness effect
  color.rgb *= mix(1.0, (1.0-darknessLightFactor*2.0) * clamp(1.0-pow(length(fragpos2)*(darknessFactor*0.07),2.0),0.0,1.0), darknessFactor);


  // float BiomeParams = isWastes + isWarpedForest + isCrimsonForest + isSoulValley + isBasaltDelta  ;

  color += vl.rgb;
  gl_FragData[0].r = vl.a;
  gl_FragData[1].rgb = clamp(color.rgb,0.0,68000.0);
  gl_FragData[1].rgb = clamp(color,6.11*1e-5,65000.0);

  #ifdef display_LUT
    gl_FragData[1].rgb =  texture2D(colortex4,texcoord*0.45).rgb * 0.000035;
  #endif
}
