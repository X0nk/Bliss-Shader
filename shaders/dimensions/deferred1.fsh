#include "/lib/settings.glsl"
#include "/lib/macro_lod_mod.glsl"

uniform sampler2D colortex4;
uniform sampler2D colortex1;
uniform sampler2D colortex12;

uniform vec2 texelSize;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform float near;
uniform float far;

float linZ(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}
float DH_linZ(float dist) {
    return (2.0 * LOD_NEARPLANE) / (LOD_FARPLANE + LOD_NEARPLANE - dist * (LOD_FARPLANE - LOD_NEARPLANE));
}
float DH_invLinZ (float lindepth){
	return -((2.0*LOD_NEARPLANE/lindepth)-LOD_FARPLANE-LOD_NEARPLANE)/(LOD_FARPLANE-LOD_NEARPLANE);
}
void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}
vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	/* RENDERTARGETS:4,12 */


	vec3 oldTex = texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0).xyz;
	float newTex = texelFetch(depthtex1, ivec2(gl_FragCoord.xy*4), 0).x;

	float dataUnpacked = decodeVec2(texelFetch(colortex1,ivec2(gl_FragCoord.xy*4),0).w).y; 
	bool hand = abs(dataUnpacked-0.75) < 0.01;

	if(hand) convertHandDepth(newTex);

	#ifdef USING_LOD_MOD
    	float QuarterResDepth = texelFetch(LOD_DEPTHTEX0, ivec2(gl_FragCoord.xy*4), 0).x;
		QuarterResDepth = DH_linZ(QuarterResDepth);
   		gl_FragData[1].a = QuarterResDepth*QuarterResDepth*65000.0;
	#endif
	
	newTex = linZ(newTex);
	gl_FragData[0] = vec4(oldTex, newTex*newTex*65000.0);
}