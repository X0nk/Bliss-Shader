#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/bokeh.glsl"
#include "/lib/items.glsl"
#include "/lib/physics_ocean.glsl"

uniform float frameTimeCounter;
#include "/lib/Shadow_Params.glsl"

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

varying vec3 physics_localPosition;
varying float physics_localWaviness;

varying vec4 lmtexcoord;
varying vec4 color;

uniform sampler2D colortex4;
uniform sampler2D noisetex;
flat varying float exposure;

#ifdef OVERWORLD_SHADER
	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
	flat varying vec3 WsunVec;

	#if defined Daily_Weather
		flat varying vec4 dailyWeatherParams0;
		flat varying vec4 dailyWeatherParams1;
	#endif
#endif

varying vec4 normalMat;
varying vec3 binormal;
varying vec4 tangent;
varying vec3 flatnormal;

varying vec3 shitnormal;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
varying vec3 viewVector;

flat varying int glass;

attribute vec4 at_tangent;
attribute vec4 mc_Entity;


uniform vec3 sunPosition;
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


// float getWave (vec3 pos, float range){
// 	return pow(1.0-texture2D(noisetex, (pos.xz + frameTimeCounter * WATER_WAVE_SPEED)/150.0).b,2) * WATER_WAVE_STRENGTH / range;
// }
// vec3 getWaveNormal(vec3 posxz, float range){

// 	float deltaPos = 0.5;

// 	vec3 coord = posxz;

// 	float h0 = getWave(coord,range);
// 	float h1 = getWave(coord - vec3(deltaPos,0.0,0.0),range);
// 	float h3 = getWave(coord - vec3(0.0,0.0,deltaPos),range);


// 	float xDelta = (h1-h0)/deltaPos*1.5;
// 	float yDelta = (h3-h0)/deltaPos*1.5;

// 	vec3 wave = normalize(vec3(xDelta, yDelta,	1.0-pow(abs(xDelta+yDelta),2.0)));

// 	return wave;
// }
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	// lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	lmtexcoord.xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	vec2 lmcoord = gl_MultiTexCoord1.xy / 240.0;
	lmtexcoord.zw = lmcoord;

 	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;

    physics_localWaviness = texelFetch(physics_waviness, ivec2(gl_Vertex.xz) - physics_textureOffset, 0).r;
    float waveOffsetY = physics_waveHeight(gl_Vertex.xz, PHYSICS_ITERATIONS_OFFSET, physics_localWaviness, physics_gameTime);
    physics_localPosition = gl_Vertex.xyz;// + vec3(0.0, waveOffsetY, 0.0);

	vec3 displacedPos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;

	#ifdef DISTANT_HORIZONS
		float range = min(1.0 + pow(length(displacedPos) / min(far,256.0),2.0), 256.0);
	#else
		float range = min(1.0 + pow(length(displacedPos) / 256,2.0), 256.0);
	#endif


	displacedPos.y += smoothstep(256.0, 200.0, range) * waveOffsetY;
	//shitnormal = getWaveNormal(displacedPos, range);
	shitnormal = vec3(0.0, 0.0, 1.0);

	position = mat3(gbufferModelView) * displacedPos + gbufferModelView[3].xyz;

 	gl_Position = toClipSpace3(position);

	HELD_ITEM_BRIGHTNESS = 0.0;
	
	#ifdef Hand_Held_lights
		if(heldItemId > 999 || heldItemId2 > 999) HELD_ITEM_BRIGHTNESS = 0.9;
	#endif
	
	// 1.0 = water mask
	float mat = 1.0;

	gl_Position.z -= 1e-4;

	// translucent entities
	// #if defined ENTITIES || defined BLOCKENTITIES
	// 	mat = 0.9;
	// 	if (entityId == 1803) mat = 0.8;
	// #endif

	// translucent blocks
	// if (mc_Entity.x >= 301 && mc_Entity.x <= 321) mat = 0.7;
	
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
	exposure = texelFetch2D(colortex4,ivec2(10,37),0).r;

	#ifdef OVERWORLD_SHADER
		lightCol.rgb = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
		lightCol.a = float(sunElevation > 1e-5)*2.0 - 1.0;
	
		averageSkyCol_Clouds = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
	
		WsunVec = lightCol.a * normalize(mat3(gbufferModelViewInverse) * sunPosition);
		// WsunVec = normalize(LightDir);
	
		#if defined Daily_Weather
			dailyWeatherParams0 = vec4((texelFetch2D(colortex4,ivec2(1,1),0).rgb/150.0)/2.0, 0.0);
			dailyWeatherParams1 = vec4((texelFetch2D(colortex4,ivec2(2,1),0).rgb/150.0)/2.0, 0.0);
		#endif

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
