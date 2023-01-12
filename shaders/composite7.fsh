#version 120
#extension GL_EXT_gpu_shader4 : enable
uniform sampler2D colortex3;
// Compute 3x3 min max for TAA

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
/* DRAWBUFFERS:06 */
  ivec2 center = ivec2(gl_FragCoord.xy);
	vec3 current = texelFetch2D(colortex3, center, 0).rgb;
  vec3 cMin = current;
  vec3 cMax = current;
  current = texelFetch2D(colortex3, center + ivec2(-1, -1), 0).rgb;
  cMin = min(cMin, current);
  cMax = max(cMax, current);
  current = texelFetch2D(colortex3, center + ivec2(-1, 0), 0).rgb;
  cMin = min(cMin, current);
  cMax = max(cMax, current);
  current = texelFetch2D(colortex3, center + ivec2(-1, 1), 0).rgb;
  cMin = min(cMin, current);
  cMax = max(cMax, current);
  current = texelFetch2D(colortex3, center + ivec2(0, -1), 0).rgb;
  cMin = min(cMin, current);
  cMax = max(cMax, current);
  current = texelFetch2D(colortex3, center + ivec2(0, 1), 0).rgb;
  cMin = min(cMin, current);
  cMax = max(cMax, current);
  current = texelFetch2D(colortex3, center + ivec2(1, -1), 0).rgb;
  cMin = min(cMin, current);
  cMax = max(cMax, current);
  current = texelFetch2D(colortex3, center + ivec2(1, 0), 0).rgb;
  cMin = min(cMin, current);
  cMax = max(cMax, current);
  current = texelFetch2D(colortex3, center + ivec2(1, 1), 0).rgb;
  cMin = min(cMin, current);
  cMax = max(cMax, current);
  gl_FragData[0].rgb = cMax;
  gl_FragData[1].rgb = cMin;
}
