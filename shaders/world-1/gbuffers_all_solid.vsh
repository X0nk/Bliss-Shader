#extension GL_EXT_gpu_shader4 : enable
#include "/lib/res_params.glsl"
#define WAVY_PLANTS
#define WAVY_STRENGTH 1.0 //[0.1 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define WAVY_SPEED 1.0 //[0.001 0.01 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 1.0 1.25 1.5 2.0 3.0 4.0]
#define SEPARATE_AO
//#define POM
//#define USE_LUMINANCE_AS_HEIGHTMAP	//Can generate POM on any texturepack (may look weird in some cases)
// #define RTAO // I recommend turning ambientOcclusionLevel to zero with this on. like ssao, but rt, nicer, noiser, and slower. SSAO will turn OFF when this is ON
#define indirect_effect 1 // Choose what effect is applied to indirect light. [0 1 2 3]

#define Variable_Penumbra_Shadows	//Makes the shadows more blurry the more distant they are to objects (costs fps)
#define mob_SSS

#ifndef USE_LUMINANCE_AS_HEIGHTMAP
#ifndef MC_NORMAL_MAP
#undef POM
#endif
#endif

#ifdef POM
#define MC_NORMAL_MAP
#endif

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;
#ifdef POM
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;
#endif

#ifdef MC_NORMAL_MAP
	varying vec4 tangent;
	attribute vec4 at_tangent;
#endif

out vec3 test_motionVectors; 
in vec3 at_velocity;  

uniform float frameTimeCounter;
const float PI48 = 150.796447372*WAVY_SPEED;
float pi2wt = PI48*frameTimeCounter;
attribute vec4 mc_Entity;
uniform int blockEntityId;
uniform int entityId;
varying vec4 materialMask;
flat varying vec4 TESTMASK;
flat varying int lightningBolt;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
attribute vec4 mc_midTexCoord;
uniform vec3 cameraPosition;
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

vec2 calcWave(in vec3 pos) {

    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec2 ret = (sin(pi2wt*vec2(0.0063,0.0015)*4. - pos.xz + pos.y*0.05)+0.1)*magnitude;

    return ret;
}

vec3 calcMovePlants(in vec3 pos) {
    vec2 move1 = calcWave(pos );
	float move1y = -length(move1);
   return vec3(move1.x,move1y,move1.y)*5.*WAVY_STRENGTH;
}

vec3 calcWaveLeaves(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {

    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec3 ret = (sin(pi2wt*vec3(0.0063,0.0224,0.0015)*1.5 - pos))*magnitude;

    return ret;
}

vec3 calcMoveLeaves(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWaveLeaves(pos      , 0.0054, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
    return move1*5.*WAVY_STRENGTH;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	lmtexcoord.xy = (gl_MultiTexCoord0).xy;

	TESTMASK = vec4(normalize(gl_NormalMatrix * gl_Normal), 1.0);
	
	TESTMASK.r = blockEntityId == 222 ? 255 : TESTMASK.r;
	

	#ifdef ENTITIES
		test_motionVectors = at_velocity;
	#endif

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
	bool istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t;

	#ifdef MC_NORMAL_MAP
		tangent = vec4(normalize(gl_NormalMatrix *at_tangent.rgb),at_tangent.w);
	#endif

	normalMat = vec4(normalize(gl_NormalMatrix *gl_Normal), 1.0);

#ifdef ENTITIES

	#ifdef mob_SSS
		#ifdef Variable_Penumbra_Shadows
			normalMat.a = entityId == 1100 ? 1.0 : normalMat.a;
			normalMat.a = entityId == 1200 ? 1.0 : normalMat.a;
			normalMat.a = entityId == 1400 ? 1.0 : normalMat.a;
		#endif
	#endif


	gl_Position = ftransform();

#endif



#ifdef WORLD

	
	normalMat = vec4(normalize(gl_NormalMatrix *gl_Normal),mc_Entity.x == 10004 || mc_Entity.x == 10003 ? 0.5 : mc_Entity.x == 10001 ? 0.6 : 1.0);
	normalMat.a = mc_Entity.x == 10006 ? 0.6 : normalMat.a;
	normalMat.a = (mc_Entity.x == 10007 || mc_Entity.x == 10008) ? 0.55 : normalMat.a;

	normalMat.a = mc_Entity.x == 10005 ? 0.8 : normalMat.a;
	normalMat.a = mc_Entity.x == 99 ? 0.65 : normalMat.a;


	#ifdef WAVY_PLANTS
		if ((mc_Entity.x == 10001 && istopv) && abs(position.z) < 64.0) {
    vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz + cameraPosition;
		worldpos.xyz += calcMovePlants(worldpos.xyz)*lmtexcoord.w - cameraPosition;
    position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;
		}

		if (mc_Entity.x == 10003 && abs(position.z) < 64.0) {
    vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz + cameraPosition;
		worldpos.xyz += calcMoveLeaves(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0,0.2,1.0), vec3(0.5,0.1,0.5))*lmtexcoord.w  - cameraPosition;
    position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;
		}
	#endif

	if (mc_Entity.x == 100 ){
		color.rgb = normalize(color.rgb)*sqrt(3.0);
		normalMat.a = 0.9;
	}

	gl_Position = toClipSpace3(position);
	
	if (color.a < 0.3) color.a = 1.0;
	

	#ifdef SEPARATE_AO

		#if indirect_effect == 1 || indirect_effect == 0
			lmtexcoord.zw *= sqrt(color.a);
		#endif
		
	#else
		color.rgb *= color.a;
	#endif

#endif


	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
	#ifdef TAA
		gl_Position.xy += offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
