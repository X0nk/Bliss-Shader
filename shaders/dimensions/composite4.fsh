#include "/lib/settings.glsl"

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

	// vec3 current = texelFetch2D(colortex3, center, 0).rgb;
  // vec3 cMin = current;
  // vec3 cMax = current;
  // current = texelFetch2D(colortex3, center + ivec2(-1, -1), 0).rgb;
  // cMin = min(cMin, current);
  // cMax = max(cMax, current);
  // current = texelFetch2D(colortex3, center + ivec2(-1, 0), 0).rgb;
  // cMin = min(cMin, current);
  // cMax = max(cMax, current);
  // current = texelFetch2D(colortex3, center + ivec2(-1, 1), 0).rgb;
  // cMin = min(cMin, current);
  // cMax = max(cMax, current);
  // current = texelFetch2D(colortex3, center + ivec2(0, -1), 0).rgb;
  // cMin = min(cMin, current);
  // cMax = max(cMax, current);
  // current = texelFetch2D(colortex3, center + ivec2(0, 1), 0).rgb;
  // cMin = min(cMin, current);
  // cMax = max(cMax, current);
  // current = texelFetch2D(colortex3, center + ivec2(1, -1), 0).rgb;
  // cMin = min(cMin, current);
  // cMax = max(cMax, current);
  // current = texelFetch2D(colortex3, center + ivec2(1, 0), 0).rgb;
  // cMin = min(cMin, current);
  // cMax = max(cMax, current);
  // current = texelFetch2D(colortex3, center + ivec2(1, 1), 0).rgb;
  // cMin = min(cMin, current);
  // cMax = max(cMax, current);
  // gl_FragData[0].rgb = cMax;
  // gl_FragData[1].rgb = cMin;

  vec3 col0 = texelFetch2D(colortex3, center, 0).rgb;
  vec3 col1 = texelFetch2D(colortex3, center + ivec2(1, 1), 0).rgb;
  vec3 col2 = texelFetch2D(colortex3, center + ivec2(1, -1), 0).rgb;
  vec3 col3 = texelFetch2D(colortex3, center + ivec2(-1, -1), 0).rgb;
  vec3 col4 = texelFetch2D(colortex3, center + ivec2(-1, 1), 0).rgb;
  vec3 col5 = texelFetch2D(colortex3, center + ivec2(0, 1), 0).rgb;
  vec3 col6 = texelFetch2D(colortex3, center + ivec2(0, -1), 0).rgb;
  vec3 col7 = texelFetch2D(colortex3, center + ivec2(-1, 0), 0).rgb;
  vec3 col8 = texelFetch2D(colortex3, center + ivec2(1, 0), 0).rgb;

	vec3 colMax = max(col0,max(col1,max(col2,max(col3, max(col4, max(col5, max(col6, max(col7, col8))))))));
	vec3 colMin = min(col0,min(col1,min(col2,min(col3, min(col4, min(col5, min(col6, min(col7, col8))))))));

	vec3 colMax5 = max(col0,max(col5,max(col6,max(col7,col8))));
	vec3 colMin5 = min(col0,min(col5,min(col6,min(col7,col8))));

	colMin = 0.5 * (colMin + colMin5);
	colMax = 0.5 * (colMax + colMax5);

  gl_FragData[0].rgb = colMax;
  gl_FragData[1].rgb = colMin;
}
