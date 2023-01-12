#version 120
//Horizontal bilateral blur for volumetric fog + Forward rendered objects + Draw volumetric fog
#extension GL_EXT_gpu_shader4 : enable
#include "lib/settings.glsl"

flat varying vec3 zMults;
flat varying vec2 TAA_Offset;


/*
const int colortex11Format = RGBA16F;			//Final output, transparencies id (gbuffer->composite4)
*/


uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
// uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex11;
uniform sampler2D colortex13;
uniform sampler2D colortex15;
uniform vec2 texelSize;

flat varying vec3 noooormal;
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
uniform float rainStrength;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float nightVision;

#include "lib/waterBump.glsl"
#include "/lib/res_params.glsl"

#include "lib/sky_gradient.glsl"
#include "lib/volumetricClouds.glsl"
// #include "lib/biome_specifics.glsl"



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


// #include "lib/specular.glsl"




vec4 BilateralUpscale(sampler2D tex, sampler2D depth,vec2 coord,float frDepth){
  coord = coord;
  vec4 vl = vec4(0.0);
  float sum = 0.0;
  mat3x3 weights;
  const ivec2 scaling = ivec2(1.0/VL_RENDER_RESOLUTION);
  ivec2 posD = ivec2(coord*VL_RENDER_RESOLUTION)*scaling;
  ivec2 posVl = ivec2(coord*VL_RENDER_RESOLUTION);
  float dz = zMults.x;
  ivec2 pos = (ivec2(gl_FragCoord.xy+frameCounter) % 2 )*2;

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

void main() {
  vec2 texcoord = gl_FragCoord.xy*texelSize;
  /* DRAWBUFFERS:73 */

  vec4 transparencies = texture2D(colortex2,texcoord);
  vec4 trpData = texture2D(colortex7,texcoord);

	vec4 speculartex = texture2D(colortex8,texcoord); // translucents
  float sunlight = speculartex.b;

  bool iswater = trpData.a > 0.99;
  float translucentAlpha = trpData.a;

  //3x3 bilateral upscale from half resolution
  float z = texture2D(depthtex0,texcoord).x;
  float z2 = texture2D(depthtex1,texcoord).x;
  float frDepth = ld(z2);
  vec4 vl = BilateralUpscale(colortex0,depthtex1,gl_FragCoord.xy,frDepth);
  // vec4 vl = texture2D(colortex0,texcoord * 0.5);


	vec4 data = texture2D(colortex11,texcoord); // translucents
  vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y));
	vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w));

	vec3 normals = mat3(gbufferModelViewInverse) * worldToView(decode(dataUnpacked0.yw) );

	vec4 data_terrain = texture2D(colortex1,texcoord); // terraom
	vec4 dataUnpacked1_terrain = vec4(decodeVec2(data_terrain.z),decodeVec2(data_terrain.w));

	bool hand = (abs(dataUnpacked1_terrain.w-0.75) < 0.01);


  vec2 refractedCoord = texcoord;
  
  float rainDrops =  clamp(texture2D(colortex9,texcoord).a,  0.0,1.0); // bloomy rain effect



	vec2 tempOffset = TAA_Offset;
	vec3 fragpos = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z));
	vec3 fragpos2 = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z2));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);

  #ifdef Refraction
    vec3 worldPos =  p3 + cameraPosition;

    // thank you sixthsurge, though i may be doing stuff weirdly with the tangent, it works... as far as i can tell.
    vec3 geometryNormal = normalize(cross(dFdx(worldPos), dFdy(worldPos))); 
    
    vec3 geometryNormal2 = geometryNormal; 
    vec3 tangent = geometryNormal2.y > 0.50 || geometryNormal2.y < -0.50  ? normalize(cross(vec3(0,0,1),geometryNormal)) : normalize(cross(vec3(0.0, 1.0, 0.0), geometryNormal));
    
    // vec3 tangent =  normalize(cross(vec3(1.0, 1.0, 1.0), geometryNormal)) ;
    vec3 bitangent = normalize(cross(tangent, geometryNormal)) ;
    mat3 tbn = mat3(tangent, bitangent, geometryNormal); 
    vec3 tangentSpaceNormal = normals * tbn;

	  float dist = clamp(ld(fragpos.z)*100,0,0.15); // shrink as distance increases

    if( translucentAlpha > 0.0)  refractedCoord += (tangentSpaceNormal.xy * dist ) * RENDER_SCALE;

    bool glass = texture2D(colortex7,refractedCoord).a > 0.0 && texture2D(colortex13,texcoord).a > 0.0;
    if(!glass) refractedCoord = texcoord;
  #endif
  
  // underwater squiggles
  // if(isEyeInWater == 1 && !iswater) refractedCoord = texcoord + pow(texture2D(noisetex,texcoord  -  vec2(0,frameTimeCounter/25)).b - 0.5, 2.0)*0.05;


  vec3 color = texture2D(colortex3,refractedCoord).rgb;

  if (frDepth > 2.5/far || transparencies.a < 0.99 || !hand) color = color * (1.0-transparencies.a) + transparencies.rgb*10.; // Discount fix for transparencies through hand



  float dirtAmount = Dirt_Amount;
  vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
  vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
  vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;

  color *= vl.a ;

  if(rainDrops > 0.0) {
    // refractedCoord = mix(refractedCoord, vec2(texcoord.x,texcoord.y * 0.9 + 0.05), rainStrength)   ;
    vl.a *= clamp(exp2(-rainDrops*5),0.,1.); // bloomy rain effect
  }


	float lightleakfix = clamp((eyeBrightnessSmooth.y )/240.0,0.0,1.0);

  //cave fog  
  #ifdef Cave_fog
    if (isEyeInWater == 0){
      float fogdistfade = 1.0 - clamp( exp(-pow(length(fragpos / far),2.)*5.0)  ,0.0,1.0);
      float fogfade =  clamp( exp(clamp( np3.y*0.5 +0.5,0,1) * -6.0)  ,0.0,1.0);

      color.rgb = mix(color.rgb, vec3(CaveFogColor_R,CaveFogColor_G,CaveFogColor_B)*fogfade,  fogdistfade * (1.0-lightleakfix) * (1.0-darknessFactor)* clamp( 1.5 - np3.y,0.,1)) ;  
      // color.rgb = mix(color.rgb, vec3(CaveFogColor_R,CaveFogColor_G,CaveFogColor_B)*fogfade,  fogdistfade) ;   
    }
  #endif

  // underwater fog
  if (isEyeInWater == 1){
    float fogfade = clamp(exp(-length(fragpos) /9. )   ,0.0,1.0);
    color.rgb *= fogfade;
    vl.a *= fogfade*0.70+0.3  ;
  }

  color += vl.rgb;
  gl_FragData[0].r = vl.a;
  
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
  // color.rgb *= mix(1.0, clamp(1.5-pow(length(fragpos2)*(blindness*0.2),2.0),0.0,1.0), blindness);
  color.rgb *= mix(1.0,      clamp( exp(pow(length(fragpos)*(blindness*0.2),2) * -5),0.,1.)   ,    blindness);

  // darkness effect
  color.rgb *= mix(1.0, (1.0-darknessLightFactor*2.0) * clamp(1.0-pow(length(fragpos2)*(darknessFactor*0.07),2.0),0.0,1.0), darknessFactor);
  

  gl_FragData[1].rgb = clamp(color.rgb,0.0,68000.0);

  #ifdef display_LUT
    gl_FragData[1].rgb =  texture2D(colortex4,texcoord/2.5).rgb *0.035;
  #endif

	// gl_FragData[1].rgb =mix(vec3(0.2,0.5,1), vec3(0,0,0), clamp(  exp2(pow(clamp(0.5-np3.y,0,1)  ,2)* -0.5)      ,0,1));
}