#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

varying vec4 pos;
varying vec4 gcolor;

uniform vec2 texelSize;
uniform int framemod8;

#if DOF_QUALITY == 5
	uniform int hideGUI;
	uniform int frameCounter;
	uniform float aspectRatio;
	uniform float screenBrightness;
	uniform float far;
	#include "/lib/bokeh.glsl"
#endif

#include "/lib/TAA_jitter.glsl"


void main() {
    gl_Position = ftransform();

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
    #ifdef TAA
		gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
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