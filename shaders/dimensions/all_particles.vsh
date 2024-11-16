#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/items.glsl"

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

varying vec4 lmtexcoord;
varying vec4 color;
uniform sampler2D colortex4;

flat varying float exposure;

#ifdef LINES
	flat varying int SELECTION_BOX;
#endif

#ifdef OVERWORLD_SHADER
	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
	flat varying vec3 WsunVec;
	#if defined Daily_Weather
		flat varying vec4 dailyWeatherParams0;
		flat varying vec4 dailyWeatherParams1;
	#endif
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

#include "/lib/TAA_jitter.glsl"

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}		




#ifdef DAMAGE_BLOCK_EFFECT
	varying vec4 vtexcoordam; // .st for add, .pq for mul
	varying vec4 vtexcoord;

	attribute vec4 mc_midTexCoord;
	varying vec4 tangent;
	attribute vec4 at_tangent;
	varying vec4 normalMat;
	flat varying vec3 WsunVec2;
#endif

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	
#ifdef DAMAGE_BLOCK_EFFECT
	WsunVec2 = (float(sunElevation > 1e-5)*2.0 - 1.0)*normalize(mat3(gbufferModelViewInverse) * sunPosition);
#endif
	lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vec2 lmcoord = gl_MultiTexCoord1.xy / 240.0;
	lmtexcoord.zw = lmcoord;

	#ifdef DAMAGE_BLOCK_EFFECT
		vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texcoordminusmid = lmtexcoord.xy-midcoord;
		vtexcoordam.pq  = abs(texcoordminusmid)*2;
		vtexcoordam.st  = min(lmtexcoord.xy,midcoord-texcoordminusmid);
		vtexcoord.xy    = sign(texcoordminusmid)*0.5+0.5;

		tangent = vec4(normalize(gl_NormalMatrix * at_tangent.rgb), at_tangent.w);
		
		normalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), 1.0);
	#endif


	HELD_ITEM_BRIGHTNESS = 0.0;

	#ifdef Hand_Held_lights
		if(heldItemId > 999 || heldItemId2 > 999) HELD_ITEM_BRIGHTNESS = 0.9;
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
	
	exposure = texelFetch2D(colortex4,ivec2(10,37),0).r;
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
		#if defined Daily_Weather
			dailyWeatherParams0 = vec4((texelFetch2D(colortex4,ivec2(1,1),0).rgb/150.0) / 2.0, 0.0);
			dailyWeatherParams1 = vec4((texelFetch2D(colortex4,ivec2(2,1),0).rgb/150.0) / 2.0, 0.0);
		#endif
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
