#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/bokeh.glsl"
#include "/lib/items.glsl"

uniform float frameTimeCounter;
#include "/lib/Shadow_Params.glsl"

#if defined PHYSICSMOD_OCEAN_SHADER
	#include "/lib/oceans.glsl"
#endif

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

varying vec4 lmtexcoord;
varying vec4 color;

uniform sampler2D colortex4;
uniform sampler2D noisetex;

#ifdef OVERWORLD_SHADER
	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
	flat varying vec3 WsunVec;

	#include "/lib/scene_controller.glsl"
#endif

varying vec4 normalMat;
varying vec3 binormal;
varying vec4 tangent;
varying vec3 flatnormal;

#ifdef LARGE_WAVE_DISPLACEMENT
varying vec3 shitnormal;
#endif

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
varying vec3 viewVector;

flat varying int glass;
#if defined ENTITIES && defined IS_IRIS
	flat varying int NAMETAG;
#endif

attribute vec4 at_tangent;
attribute vec4 mc_Entity;


uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
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

#include "/lib/TAA_jitter.glsl"


#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}


float getWave (vec3 pos, float range){
	return pow(1.0-texture2D(noisetex, (pos.xz + frameTimeCounter * WATER_WAVE_SPEED)/150.0).b,2) * WATER_WAVE_STRENGTH / range;
}
vec3 getWaveNormal(vec3 posxz, float range){

	float deltaPos = 0.5;

	vec3 coord = posxz;

	float h0 = getWave(coord,range);
	float h1 = getWave(coord - vec3(deltaPos,0.0,0.0),range);
	float h3 = getWave(coord - vec3(0.0,0.0,deltaPos),range);


	float xDelta = (h1-h0)/deltaPos*1.5;
	float yDelta = (h3-h0)/deltaPos*1.5;

	vec3 wave = normalize(vec3(xDelta, yDelta,	1.0-pow(abs(xDelta+yDelta),2.0)));

	return wave;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	#if defined PHYSICSMOD_OCEAN_SHADER && defined PHYSICS_OCEAN
    	// basic texture to determine how shallow/far away from the shore the water is
    	physics_localWaviness = texelFetch(physics_waviness, ivec2(gl_Vertex.xz) - physics_textureOffset, 0).r;
    	// transform gl_Vertex (since it is the raw mesh, i.e. not transformed yet)
    	vec4 finalPosition = vec4(gl_Vertex.x, gl_Vertex.y + physics_waveHeight(gl_Vertex.xz, PHYSICS_ITERATIONS_OFFSET, physics_localWaviness, physics_gameTime), gl_Vertex.z, gl_Vertex.w);
    	// pass this to the fragment shader to fetch the texture there for per fragment normals
    	physics_localPosition = finalPosition.xyz;

		vec3 position = mat3(gl_ModelViewMatrix) * vec3(finalPosition) + gl_ModelViewMatrix[3].xyz;
	#else
		vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
	#endif

	// lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	lmtexcoord.xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	vec2 lmcoord = gl_MultiTexCoord1.xy / 240.0;
	lmtexcoord.zw = lmcoord;



	#ifdef LARGE_WAVE_DISPLACEMENT
		if(mc_Entity.x == 8.0) {
			vec3 displacedPos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz + cameraPosition;
			#ifdef DISTANT_HORIZONS
				float range = min(1.0 + pow(length(displacedPos - cameraPosition) / min(far,256.0),2.0), 256.0);
			#else
				float range = min(1.0 + pow(length(displacedPos - cameraPosition) / 256,2.0), 256.0);
			#endif

			displacedPos.y -= (1.0-getWave(displacedPos, range)) * 0.5 - 0.2;
			shitnormal = getWaveNormal(displacedPos, range);
    		position = mat3(gbufferModelView) * (displacedPos - cameraPosition) + gbufferModelView[3].xyz;
		}
	#endif
	
	// vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
   	vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
	#ifdef PLANET_CURVATURE
		float curvature = length(worldpos) / (16*8);
		worldpos.y -= curvature*curvature * CURVATURE_AMOUNT;
	#endif

	position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;
	
 	gl_Position = toClipSpace3(position);

	HELD_ITEM_BRIGHTNESS = 0.0;
	
	#ifdef Hand_Held_lights
		if(heldItemId > 999 || heldItemId2 > 999) HELD_ITEM_BRIGHTNESS = 0.9;
	#endif
	
	// 1.0 = water mask
	// 0.9 = entity mask
	// 0.8 = reflective entities
	// 0.7 = reflective blocks
	float mat = 0.0;

	// water mask
	if(mc_Entity.x == 8.0) {
    	mat = 1.0;
  	}

	// translucent entities
	#if defined ENTITIES || defined BLOCKENTITIES
		mat = 0.9;
		if (entityId == 1803) mat = 0.8;
	#endif

	// translucent blocks
	if (mc_Entity.x >= 301 && mc_Entity.x <= 321) mat = 0.7;

	#if defined ENTITIES && defined IS_IRIS
		NAMETAG = 0;
		if (entityId == 1600) NAMETAG = 1;
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

	viewVector = position.xyz;
	// viewVector = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = normalize(tbnMatrix * viewVector);


	color = vec4(gl_Color.rgb, 1.0);

	#ifdef OVERWORLD_SHADER
		lightCol.rgb = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
		lightCol.a = float(sunElevation > 1e-5)*2.0 - 1.0;
	
		averageSkyCol_Clouds = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
	
		// WsunVec = lightCol.a * normalize(mat3(gbufferModelViewInverse) * sunPosition);
		
		WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);
		vec3 moonVec = normalize(mat3(gbufferModelViewInverse) * moonPosition);
		vec3 WmoonVec = moonVec;
		if(dot(-moonVec, WsunVec) < 0.9999) WmoonVec = -moonVec;

		WsunVec = mix(WmoonVec, WsunVec, clamp(lightCol.a,0,1));

		readSceneControllerParameters(colortex4, parameters.smallCumulus, parameters.largeCumulus, parameters.altostratus, parameters.fog);

	#endif

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
	#ifdef TAA
		#if defined ENTITIES && defined IS_IRIS
		// remove jitter for nametags lol
			if (entityId != 1600) gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
		#else
			gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
		#endif
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
