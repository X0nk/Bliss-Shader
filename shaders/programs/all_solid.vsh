#extension GL_EXT_gpu_shader4 : enable
#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/


#ifndef USE_LUMINANCE_AS_HEIGHTMAP
#ifndef MC_NORMAL_MAP
	#undef POM
#endif
#endif

#ifdef POM
	#define MC_NORMAL_MAP
#endif


varying vec4 color;
varying float VanillaAO;

varying vec4 lmtexcoord;
varying vec4 normalMat;

#ifdef POM
	varying vec4 vtexcoordam; // .st for add, .pq for mul
	varying vec4 vtexcoord;
#endif

#ifdef MC_NORMAL_MAP
	varying vec4 tangent;
	attribute vec4 at_tangent;
	varying vec3 FlatNormals;
#endif


attribute vec4 mc_Entity;
uniform int blockEntityId;
uniform int entityId;

flat varying float blockID;

flat varying int NameTags;

attribute vec4 mc_midTexCoord;

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
	gl_Position = ftransform();
	lmtexcoord.xy = (gl_MultiTexCoord0).xy;

	FlatNormals = normalize(gl_NormalMatrix * gl_Normal);

	NameTags = 0;
	blockID = mc_Entity.x;

	#ifdef POM
		vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texcoordminusmid = lmtexcoord.xy-midcoord;
		vtexcoordam.pq  = abs(texcoordminusmid)*2;
		vtexcoordam.st  = min(lmtexcoord.xy,midcoord-texcoordminusmid);
		vtexcoord.xy    = sign(texcoordminusmid)*0.5+0.5;
	#endif

	vec2 lmcoord = gl_MultiTexCoord1.xy/255.;
	lmtexcoord.zw = lmcoord;
	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
	
	color = gl_Color;
	
	VanillaAO = 1.0 - clamp(color.a,0,1);
	if (color.a < 0.3) color.a = 1.0; // fix vanilla ao on some custom block models.


	#ifdef MC_NORMAL_MAP
		tangent = vec4(normalize(gl_NormalMatrix *at_tangent.rgb),at_tangent.w);
	#endif

	normalMat = vec4(normalize(gl_NormalMatrix *gl_Normal), 1.0);

#ifdef ENTITIES
	// try and single out nametag text and then discard nametag background
	if( dot(gl_Color.rgb, vec3(0.35)) < 1.0) NameTags = 1;

	if(gl_Color.a >= 0.24 && gl_Color.a <= 0.25 ) gl_Position = vec4(10,10,10,1);
#endif



#ifdef WORLD

	normalMat = vec4(normalize(gl_NormalMatrix *gl_Normal),mc_Entity.x == 10004 || mc_Entity.x == 10003 ? 0.5 : mc_Entity.x == 10001 ? 0.6 : 1.0);

	normalMat.a = mc_Entity.x == 10005 ? 0.8 : normalMat.a;

	if (mc_Entity.x == 100 ){
		color.rgb = normalize(color.rgb)*sqrt(3.0);
		normalMat.a = 0.9;
	}

	gl_Position = toClipSpace3(position);

#endif

	// #ifdef TAA_UPSCALING
	// 	gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	// #endif
	#ifdef TAA
		gl_Position.xy += offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
