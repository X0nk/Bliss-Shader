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

#ifdef LINES
	flat varying int SELECTION_BOX;
#endif

#ifdef OVERWORLD_SHADER
	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
	flat varying vec3 WsunVec;
	uniform sampler2D colortex4;
#endif
	


uniform vec3 sunPosition;
uniform float sunElevation;

uniform vec2 texelSize;
uniform int framemod8;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform ivec2 eyeBrightnessSmooth;

uniform int heldItemId;
uniform int heldItemId2;
flat varying float HELD_ITEM_BRIGHTNESS;

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
	
	lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vec2 lmcoord = gl_MultiTexCoord1.xy / 255.0; // is this even correct? lol'
	lmtexcoord.zw = lmcoord;


	HELD_ITEM_BRIGHTNESS = 0.0;

	#ifdef Hand_Held_lights
		if(heldItemId == 100 || heldItemId2 == 100) HELD_ITEM_BRIGHTNESS = 0.9;
	#endif


	#ifdef WEATHER
		vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;

   		vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz + cameraPosition;
		bool istopv = worldpos.y > cameraPosition.y + 5.0 && lmtexcoord.w > 0.94;

		if(!istopv){
			worldpos.xyz -= cameraPosition;
		}else{
			worldpos.xyz -= cameraPosition + vec3(2.0,0.0,2.0);
		}

		position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;

		gl_Position = toClipSpace3(position);
	#else
		gl_Position = ftransform();
	#endif


	color = gl_Color;
	// color.rgb = worldpos;
	
	#ifdef LINES
		SELECTION_BOX = 0;
		if(dot(color.rgb,vec3(0.33333))	 < 0.00001) SELECTION_BOX = 1;
	#endif
	
	#ifdef OVERWORLD_SHADER
		lightCol.rgb = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
		lightCol.a = float(sunElevation > 1e-5)*2.0 - 1.0;
	
		averageSkyCol_Clouds = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
	
		WsunVec = lightCol.a * normalize(mat3(gbufferModelViewInverse) * sunPosition);
	#endif
	
	#ifndef WEATHER
	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
	#ifdef TAA
		gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
	#endif
	#endif
}
