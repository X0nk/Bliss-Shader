#version 120
//Horizontal bilateral blur for volumetric fog + Forward rendered objects + Draw volumetric fog
#extension GL_EXT_gpu_shader4 : disable

#include "/lib/settings.glsl"


varying vec2 texcoord;
flat varying vec3 zMults;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex13;
uniform sampler2D colortex11;
uniform sampler2D colortex7;
uniform sampler2D colortex3;
uniform sampler2D colortex2;
uniform sampler2D colortex0;
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform int frameCounter;
uniform float far;
uniform float near;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform vec2 texelSize;
uniform vec3 cameraPosition;

uniform int isEyeInWater;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;


#include "/lib/waterBump.glsl"

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
float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
void main() {
  /* DRAWBUFFERS:73 */
  //3x3 bilateral upscale from half resolution
  float z = texture2D(depthtex0,texcoord).x;
  float z2 = texture2D(depthtex1,texcoord).x;
  float frDepth = ld(z);
  float glassdepth = clamp((ld(z2) - ld(z)) * 0.5,0.0,0.15);

  // vec4 vl = BilateralUpscale(colortex0,depthtex0,gl_FragCoord.xy,frDepth);
  float bloomyfogmult = 1.0;

  vec4 Translucent_Programs = texture2D(colortex2,texcoord); // the shader for all translucent progams.

  vec4 trpData = texture2D(colortex7,texcoord);
  bool iswater = trpData.a > 0.99;
  vec2 refractedCoord = texcoord;



	vec2 data = texture2D(colortex11,texcoord).xy; // translucents
  vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y));

	vec3 normals = mat3(gbufferModelViewInverse) * worldToView(decode(dataUnpacked0.yw) );

  // vec4 vl = BilateralUpscale(colortex0,depthtex0,gl_FragCoord.xy,frDepth);

  #ifdef Refraction
    refractedCoord += normals.xy * glassdepth;
    
    float refractedalpha = texture2D(colortex13,refractedCoord).a;
    if(refractedalpha <= 0.0) refractedCoord = texcoord; // remove refracted coords on solids
  #endif

  vec3 color = texture2D(colortex3,refractedCoord).rgb;
  
  if (Translucent_Programs.a > 0.0){
		#ifdef Glass_Tint
	    vec3 GlassAlbedo = texture2D(colortex13,texcoord).rgb * 5.0;
      color = color*GlassAlbedo.rgb + color * clamp(pow(1.0-luma(GlassAlbedo.rgb),10.),0.0,1.0);
    #endif

    color = color*(1.0-Translucent_Programs.a) + Translucent_Programs.rgb; 
  } 

  if (isEyeInWater == 0){
    vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z));
    float fogdistfade = 1.0 - clamp( exp(-pow(length(fragpos / far),2.)*5.0)  ,0.0,1.0);
    bloomyfogmult = 1.0 - fogdistfade*0.5 ;

    color.rgb = mix(color.rgb, gl_Fog.color.rgb*0.5*NetherFog_brightness, fogdistfade) ;  
  }

  // color *= vl.a;
  // color += vl.rgb;
  // bloomyfogmult *= pow(vl.a,0.1);



  // underwater fog
  if (isEyeInWater == 1){
    vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z));
    float fogfade = clamp(exp(-length(fragpos) /5. )   ,0.0,1.0);
    bloomyfogmult *= fogfade*0.70+0.3  ;
  }
  /// lava.
  if (isEyeInWater == 2){
    color.rgb = vec3(4.0,0.5,0.1);
  }
  /// powdered snow
  if (isEyeInWater == 3){
    vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z));
    color.rgb = mix(color.rgb,vec3(10,15,20),clamp(length(fragpos)*0.5,0.,1.));
    bloomyfogmult = 0.0;
  }
  // blidnesss
  if (blindness > 0.0){
    vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z));
    color.rgb *= mix(1.0,clamp( exp(pow(length(fragpos)*(blindness*0.2),2) * -5),0.,1.)   ,    blindness);
  }
  // darkness effect
  if(darknessFactor > 0.0){
    vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z2));
    color.rgb *= mix(1.0, (1.0-darknessLightFactor*2.0) * clamp(1.0-pow(length(fragpos)*(darknessFactor*0.07),2.0),0.0,1.0), darknessFactor);
  }

  gl_FragData[0].r = bloomyfogmult;
  gl_FragData[1].rgb = clamp(color,6.11*1e-5,65000.0);
}
