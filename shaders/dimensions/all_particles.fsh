#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

varying vec4 lmtexcoord;
varying vec4 color;

#ifdef LINES
	flat varying int SELECTION_BOX;
#endif

#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;
	
	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif

	flat varying vec3 WsunVec;

	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
#endif

uniform int isEyeInWater;

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform sampler2D colortex4;


uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;

uniform float frameTimeCounter;
#include "/lib/Shadow_Params.glsl"

uniform vec2 texelSize;

uniform ivec2 eyeBrightnessSmooth;
uniform float rainStrength;
flat varying float HELD_ITEM_BRIGHTNESS;

#ifndef OVERWORLD_SHADER
	uniform float nightVision;
#endif

#ifdef OVERWORLD_SHADER
	#define CLOUDSHADOWSONLY
	#include "/lib/volumetricClouds.glsl"
#endif

#include "/lib/diffuse_lighting.glsl"
#include "/lib/sky_gradient.glsl"

vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

uniform int framemod8;

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);

//Mie phase function
float phaseg(float x, float g){
    float gg = g * g;
    return (gg * -0.25 + 0.25) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5) / 3.14;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

/* DRAWBUFFERS:29 */

void main() {
	
	#ifdef LINES
		#ifndef SELECT_BOX
			if(SELECTION_BOX > 0) discard;
		#endif
	#endif

	vec2 tempOffset = offsets[framemod8];
	vec3 viewPos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
	vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos;
	vec3 feetPlayerPos_normalized = normalize(feetPlayerPos);

	vec4 TEXTURE = texture2D(texture, lmtexcoord.xy)*color;

	vec3 Albedo = toLinear(TEXTURE.rgb);
	
	vec2 lightmap = lmtexcoord.zw;

	#ifndef OVERWORLD_SHADER
		lightmap.y = 1.0;
	#endif

	#ifdef Hand_Held_lights
		lightmap.x = max(lightmap.x, HELD_ITEM_BRIGHTNESS * clamp( pow(max(1.0-length(viewPos)/HANDHELD_LIGHT_RANGE,0.0),1.5),0.0,1.0));
	#endif



	#ifdef WEATHER
		gl_FragData[1].a = TEXTURE.a; // for bloomy rain and stuff
	#endif


#ifndef WEATHER
	#ifndef LINES
		gl_FragData[0].a = TEXTURE.a;
	#else
		gl_FragData[0].a = 1.0;
	#endif
	#ifndef BLOOMY_PARTICLES
		gl_FragData[1].a = 0.0; // for bloomy rain and stuff
	#endif
	
	vec3 Direct_lighting = vec3(0.0);
	vec3 Indirect_lighting = vec3(0.0);
	
	vec3 MinimumLightColor = vec3(1.0);
	if(isEyeInWater == 1) MinimumLightColor = vec3(10.0);

	vec3 Torch_Color = vec3(TORCH_R,TORCH_G,TORCH_B);
	
	
	if(lightmap.x >= 0.9) Torch_Color *= LIT_PARTICLE_BRIGHTNESS;

	#ifdef OVERWORLD_SHADER
		vec3 Shadows = vec3(1.0);
		
		vec3 feetPlayerPos_shadow = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
		vec3 projectedShadowPosition = mat3(shadowModelView) * feetPlayerPos_shadow + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		//apply distortion
		#ifdef DISTORT_SHADOWMAP
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;
		#else
			float distortFactor = 1.0;
		#endif

		//do shadows only if on shadow map
		if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution){
			Shadows = vec3(0.0);

			projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);

			#ifdef TRANSLUCENT_COLORED_SHADOWS
				float opaqueShadow = shadow2D(shadowtex0, projectedShadowPosition).x;
				Shadows += vec3(opaqueShadow);

				if(shadow2D(shadowtex1, projectedShadowPosition).x > projectedShadowPosition.z){ 
					vec4 translucentShadow = texture2D(shadowcolor0, projectedShadowPosition.xy);
					if(translucentShadow.a < 0.9) Shadows += normalize(translucentShadow.rgb+0.0001) * (1.0-opaqueShadow);
				}
			#else
				Shadows = vec3(shadow2D(shadow, projectedShadowPosition).x);
			#endif
		}

		float cloudShadow = GetCloudShadow(feetPlayerPos);

		Direct_lighting = (lightCol.rgb/80.0) * Shadows * cloudShadow;
		

		#ifndef LINES
			Direct_lighting *= phaseg(clamp(dot(feetPlayerPos_normalized, WsunVec),0.0,1.0), 0.65)*2 + 0.5;
		#endif

		vec3 AmbientLightColor = (averageSkyCol_Clouds / 30.0) * 3.0;

	#endif

	#ifdef NETHER_SHADER
		// vec3 AmbientLightColor = skyCloudsFromTexLOD2(vec3( 0, 1, 0), colortex4, 6).rgb / 15;
		vec3 AmbientLightColor = vec3(0.1);
	#endif

	#ifdef END_SHADER
		vec3 AmbientLightColor = vec3(1.0);
	#endif

	Indirect_lighting = DoAmbientLightColor(AmbientLightColor,MinimumLightColor, Torch_Color, clamp(lightmap.xy,0,1));

	#ifdef LINES
		gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * toLinear(color.rgb);
	#else
		gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * Albedo;
	#endif

	// distance fade targeting the world border...
	if(TEXTURE.a < 0.7 && TEXTURE.a > 0.2) gl_FragData[0] *= clamp(1.0 - length(feetPlayerPos) / 100.0 ,0.0,1.0);
#endif
}