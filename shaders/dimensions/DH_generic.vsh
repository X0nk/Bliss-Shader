#define ANTIALIASING_RELATED_SETTINGS
#define DEPTH_OF_FIELD_RELATED_SETTINGS
#define GEOMETRY_ANIMATION_RELATED_SETTINGS
#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

varying vec4 pos;
varying vec4 gcolor;

uniform vec2 texelSize;

#if DOF_QUALITY == 5
	uniform int hideGUI;
	uniform int frameCounter;
	uniform float aspectRatio;
	uniform float screenBrightness;
	uniform float far;
	#include "/lib/bokeh.glsl"
#endif

uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform mat4 dhProjection;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

#include "/lib/TAA_jitter.glsl"
#include "/lib/vertex_displacement.glsl"


void main() {

    // gl_Position = ftransform();

    vec4 vPos = gl_Vertex;

    vec3 cameraOffset = fract(cameraPosition);
    vPos.xyz = floor(vPos.xyz + cameraOffset + 0.5) - cameraOffset;

    vec4 viewPos = gl_ModelViewMatrix * vPos;
	vec4 localPos = gbufferModelViewInverse * viewPos;

	#if CURVATURE_AMOUNT !=  0
		vec4 worldPos = localPos;

		applyWorldCurvature(worldPos.xyz);

		worldPos = gbufferModelView * worldPos;
    	gl_Position = dhProjection * worldPos;
	#else
    	gl_Position = dhProjection * viewPos;
	#endif


	#if TAA_MODE == 3
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
    #if TAA_MODE > 0 && defined DH_TAA_JITTER
		gl_Position.xy += taaJitter * gl_Position.w*texelSize;
	#endif
	
    pos = gl_ModelViewMatrix * gl_Vertex;
    gcolor = gl_Color;
	
	#if DOF_QUALITY == 5
		vec2 jitter = clamp(jitter_offsets[frameCounter % 64], -1.0, 1.0);
		jitter = rotate(radians(float(frameCounter))) * jitter;
		jitter.y *= aspectRatio;
		jitter.x *= DOF_ANAMORPHIC_RATIO;

		#if MANUAL_FOCUS == -2
		float focusMul = 0;
		#elif MANUAL_FOCUS == -1
		float focusMul = gl_Position.z + (far / 3.0) - mix(pow(512.0, screenBrightness), 512.0 * screenBrightness, 0.25);
		#else
		float focusMul = gl_Position.z + (far / 3.0) - MANUAL_FOCUS;
		#endif

		vec2 totalOffset = (jitter * JITTER_STRENGTH) * focusMul * 1e-2;
		gl_Position.xy += hideGUI >= 1 ? totalOffset : vec2(0);
	#endif
}