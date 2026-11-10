#include "/lib/settings.glsl"

uniform sampler2D colortex3;
uniform vec2 texelSize;
uniform float viewHeight;
uniform float viewWidth;

#include "/lib/TAA_jitter.glsl"

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
/* RENDERTARGETS:0,6 */
	vec2 jitter = taaJitter*texelSize*0.5;
  vec2 screenEdges = 2.0/vec2(viewWidth, viewHeight);
  ivec2 center = ivec2(gl_FragCoord.xy);

  // remember to re-compress the 0.0-65000.0 range down to 0.0-1.0 when doing the maths, then scale back up when writing.
  // variance clip: https://developer.download.nvidia.com/gameworks/events/GDC2016/msalvi_temporal_supersampling.pdf
  vec3 col0 = texelFetch(colortex3, center, 0).rgb/65000.0;
  vec3 col1 = texelFetch(colortex3, center + ivec2( 1, 1), 0).rgb/65000.0;
  vec3 col2 = texelFetch(colortex3, center + ivec2( 1,-1), 0).rgb/65000.0;
  vec3 col3 = texelFetch(colortex3, center + ivec2(-1,-1), 0).rgb/65000.0;
  vec3 col4 = texelFetch(colortex3, center + ivec2(-1, 1), 0).rgb/65000.0;
  vec3 col5 = texelFetch(colortex3, center + ivec2( 0, 1), 0).rgb/65000.0;
  vec3 col6 = texelFetch(colortex3, center + ivec2( 0,-1), 0).rgb/65000.0;
  vec3 col7 = texelFetch(colortex3, center + ivec2(-1, 0), 0).rgb/65000.0;
  vec3 col8 = texelFetch(colortex3, center + ivec2( 1, 0), 0).rgb/65000.0;

	vec3 momentsA = (col0+col1+col2+col3+col4+col5+col6+col7+col8)/9.0;
	vec3 momentsB = (col0*col0+col1*col1+col2*col2+col3*col3+col4*col4+col5*col5+col6*col6+col7*col7+col8*col8)/9.0;

  gl_FragData[0].rgb = momentsA*65000.0;
  gl_FragData[1].rgb = momentsB*65000.0;
}