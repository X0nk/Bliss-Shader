#include "/lib/settings.glsl"

uniform sampler2D colortex4;
uniform sampler2D colortex12;

uniform vec2 texelSize;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;

uniform float near;
uniform float far;

float linZ(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

uniform float dhFarPlane;
uniform float dhNearPlane;
float DH_ld(float dist) {
    return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
}
float DH_invLinZ (float lindepth){
	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
/* RENDERTARGETS:4,12 */
	vec3 oldTex = texelFetch2D(colortex4, ivec2(gl_FragCoord.xy), 0).xyz;

	float newTex = texelFetch2D(depthtex1, ivec2(gl_FragCoord.xy*4), 0).x;
	
	
	#ifdef DISTANT_HORIZONS
    	float QuarterResDepth = texelFetch2D(dhDepthTex, ivec2(gl_FragCoord.xy*4), 0).x;
		if(newTex >= 1.0) newTex = QuarterResDepth;
	#endif
	
 	if (newTex < 1.0)
	   gl_FragData[0] = vec4(oldTex, linZ(newTex)*linZ(newTex)*65000.0);
 	else
    gl_FragData[0] = vec4(oldTex, 2.0);

	float depth = texelFetch2D(depthtex1, ivec2(gl_FragCoord.xy*4), 0).x;

	#ifdef DISTANT_HORIZONS
	    float _near = near;
	    float _far = far*4.0;
	    if (depth >= 1.0) {
	        depth = texelFetch2D(dhDepthTex1, ivec2(gl_FragCoord.xy*4), 0).x;
	        _near = dhNearPlane;
	        _far = dhFarPlane;
	    }

	    depth = linearizeDepthFast(depth, _near, _far);
	    depth = depth / dhFarPlane;
	#endif

	if(depth < 1.0)
    	gl_FragData[1] = vec4(vec3(0.0), depth * depth * 65000.0);
	else
		gl_FragData[1] = vec4(vec3(0.0), 65000.0);


	#ifdef DISTANT_HORIZONS
   	 gl_FragData[1].a = DH_ld(QuarterResDepth)*DH_ld(QuarterResDepth)*65000.0;
	#endif
}