// #version 120
#extension GL_EXT_gpu_shader4 : enable
#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"


/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;
varying vec3 binormal;
varying vec3 tangent;
uniform mat4 gbufferModelViewInverse;
varying vec3 viewVector;

flat varying int glass;

attribute vec4 at_tangent;
attribute vec4 mc_Entity;

uniform sampler2D colortex4;

uniform vec3 sunPosition;
flat varying vec3 WsunVec;
uniform float sunElevation;

varying vec4 tangent_other;

flat varying vec4 lightCol; //main light source color (rgb),used light source(1=sun,-1=moon)
flat varying vec3 avgAmbient;


uniform vec2 texelSize;
uniform int framemod8;
		const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}









//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	vec4 Swtich_gl_vertex = gl_Vertex;

	lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vec2 lmcoord = gl_MultiTexCoord1.xy/255.;
	lmtexcoord.zw = lmcoord;

 	vec3 position = mat3(gl_ModelViewMatrix) * vec3(Swtich_gl_vertex) + gl_ModelViewMatrix[3].xyz;
 	gl_Position = toClipSpace3(position);
	color = gl_Color;
	float mat = 0.0;
	
	if(mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
    mat = 1.0;

    gl_Position.z -= 1e-4;
  }

	if (mc_Entity.x == 10002) mat = 0.2;
	if (mc_Entity.x == 72) mat = 0.5;

	// if (mc_Entity.x == 8) mat = 0.1;
	
	normalMat = vec4(normalize( gl_NormalMatrix*gl_Normal),mat);



	tangent_other = vec4(normalize(gl_NormalMatrix * at_tangent.rgb),normalMat.a);

	tangent = normalize( gl_NormalMatrix *at_tangent.rgb);
	binormal = normalize(cross(tangent.rgb,normalMat.xyz)*at_tangent.w);

	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normalMat.x,
								  tangent.y, binormal.y, normalMat.y,
						     	  tangent.z, binormal.z, normalMat.z);

	viewVector = ( gl_ModelViewMatrix * Swtich_gl_vertex).xyz;
	viewVector = normalize(tbnMatrix * viewVector);



  	// #ifdef TAA_UPSCALING
	// 	gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	// #endif
	#ifdef TAA
	gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
	#endif

	vec3 sc = texelFetch2D(colortex4,ivec2(6,37),0).rgb;

	
	lightCol.a = float(sunElevation > 1e-5)*2-1.;
	lightCol.rgb = sc;

	WsunVec = lightCol.a*normalize(mat3(gbufferModelViewInverse) *sunPosition);
	
	avgAmbient = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
}
