#version 120
//Horizontal bilateral blur for volumetric fog + Forward rendered objects + Draw volumetric fog
#extension GL_EXT_gpu_shader4 : enable



varying vec2 texcoord;
flat varying vec3 zMults;
uniform sampler2D depthtex0;
uniform sampler2D colortex3;
uniform sampler2D colortex2;
uniform sampler2D colortex0;

uniform int frameCounter;
uniform float far;
uniform float near;
uniform int isEyeInWater;

uniform vec2 texelSize;
float ld(float depth) {
    return 1.0 / (zMults.y - depth * zMults.z);		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}

vec4 BilateralUpscale(sampler2D tex, sampler2D depth,vec2 coord,float frDepth){
  vec4 vl = vec4(0.0);
  float sum = 0.0;
  mat3x3 weights;
  ivec2 posD = ivec2(coord/2.0)*2;
  ivec2 posVl = ivec2(coord/2.0);
  float dz = zMults.x;
  ivec2 pos = (ivec2(gl_FragCoord.xy+frameCounter) % 3 );
	//pos = ivec2(1,-1);

  ivec2 tcDepth =  posD + ivec2(-2,-2) + pos*2;
  float dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  float w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(-1)+pos,0)*w;
  sum += w;

	tcDepth =  posD + ivec2(-2,0) + pos*2;
  dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(-1,0)+pos,0)*w;
  sum += w;

	tcDepth =  posD + ivec2(0) + pos*2;
  dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(0)+pos,0)*w;
  sum += w;

	tcDepth =  posD + ivec2(0,-2) + pos*2;
  dsample = ld(texelFetch2D(depth,tcDepth,0).r);
  w = abs(dsample-frDepth) < dz ? 1.0 : 1e-5;
  vl += texelFetch2D(tex,posVl+ivec2(0,-1)+pos,0)*w;
  sum += w;

  return vl/sum;
}

void main() {
/* DRAWBUFFERS:0 */

  //3x3 bilateral upscale from half resolution
  float frDepth = ld(texture2D(depthtex0,texcoord).x);
  vec4 vl = BilateralUpscale(colortex0,depthtex0,gl_FragCoord.xy,frDepth);

  vec3 color = texture2D(colortex3,texcoord).rgb;
  vec4 transparencies = texture2D(colortex2,texcoord);
  color = color*(1.0-transparencies.a)+transparencies.rgb*10.;

  color *= vl.a;
  color += vl.rgb;

	gl_FragData[0].rgb = clamp(color,6.11*1e-5,65000.0);

	gl_FragData[0].a = vl.a;
}
