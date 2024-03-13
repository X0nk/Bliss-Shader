#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/bokeh.glsl"

uniform float frameTimeCounter;
#include "/lib/Shadow_Params.glsl"

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

varying vec4 lmtexcoord;
varying vec4 color;

#ifdef OVERWORLD_SHADER
	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
	flat varying vec3 WsunVec;
#endif

varying vec4 normalMat;
varying vec3 binormal;
varying vec4 tangent;
varying vec3 flatnormal;

uniform mat4 gbufferModelViewInverse;
varying vec3 viewVector;

flat varying int glass;

attribute vec4 at_tangent;
attribute vec4 mc_Entity;

uniform sampler2D colortex4;

uniform vec3 sunPosition;
uniform float sunElevation;

varying vec4 tangent_other;

uniform int frameCounter;
// uniform float far;
uniform float aspectRatio;
uniform float viewHeight;
uniform float viewWidth;
uniform int hideGUI;
uniform float screenBrightness;

uniform int heldItemId;
uniform int heldItemId2;
flat varying float HELD_ITEM_BRIGHTNESS;

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

varying vec4 pos;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vec2 lmcoord = gl_MultiTexCoord1.xy / 255.0; // is this even correct? lol
	lmtexcoord.zw = lmcoord;

 	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
 	gl_Position = toClipSpace3(position);

    pos = vec4(position,1);

	HELD_ITEM_BRIGHTNESS = 0.0;

	#ifdef Hand_Held_lights
		if(heldItemId == 100 || heldItemId2 == 100) HELD_ITEM_BRIGHTNESS = 0.9;
	#endif
	
	float mat = 0.0;
	
	if(mc_Entity.x == 8.0) {
    	mat = 1.0;

    	gl_Position.z -= 1e-4;
  	}

	if (mc_Entity.x == 10002) mat = 0.2;
	if (mc_Entity.x == 72) mat = 0.5;

	#if defined ENTITIES || defined BLOCKENTITIES
		mat = 0.1;
	#endif

	
	tangent = vec4(normalize(gl_NormalMatrix *at_tangent.rgb),at_tangent.w);

	normalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), 1.0);
	normalMat.a = mat;

	vec3 tangent2 = normalize( gl_NormalMatrix *at_tangent.rgb);
	binormal = normalize(cross(tangent2.rgb,normalMat.xyz)*at_tangent.w);

	mat3 tbnMatrix = mat3(tangent2.x, binormal.x, normalMat.x,
								  tangent2.y, binormal.y, normalMat.y,
						     	  tangent2.z, binormal.z, normalMat.z);
	
	flatnormal = normalMat.xyz;

	viewVector = ( gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = normalize(tbnMatrix * viewVector);


	color = vec4(gl_Color.rgb, 1.0);

	#ifdef OVERWORLD_SHADER
		lightCol.rgb = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
		lightCol.a = float(sunElevation > 1e-5)*2.0 - 1.0;
	
		averageSkyCol_Clouds = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
	
		WsunVec = lightCol.a * normalize(mat3(gbufferModelViewInverse) * sunPosition);
		// WsunVec = normalize(LightDir);
	#endif



	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
	#ifdef TAA
		gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
	#endif

	#if DOF_QUALITY == 5
		vec2 jitter = clamp(jitter_offsets[frameCounter % 64], -1.0, 1.0);
		jitter = rotate(radians(float(frameCounter))) * jitter;
		jitter.y *= aspectRatio;
		jitter.x *= DOF_ANAMORPHIC_RATIO;

		#if MANUAL_FOCUS == -2
		float focusMul = 0;
		#elif MANUAL_FOCUS == -1
		float focusMul = gl_Position.z - mix(pow(512.0, screenBrightness), 512.0 * screenBrightness, 0.25);
		#else
		float focusMul = gl_Position.z - MANUAL_FOCUS;
		#endif

		vec2 totalOffset = (jitter * JITTER_STRENGTH) * focusMul * 1e-2;
		gl_Position.xy += hideGUI >= 1 ? totalOffset : vec2(0);
	#endif
}
