#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/Shadow_Params.glsl"

varying vec4 lmtexcoord;
varying vec4 color;

#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;

	flat varying vec3 WsunVec;

	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
#endif

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

uniform vec2 texelSize;

uniform ivec2 eyeBrightnessSmooth;
uniform float rainStrength;

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
	#ifdef WEATHER
		gl_FragData[1].a = TEXTURE.a; // for bloomy rain and stuff
	#endif


#ifndef WEATHER
	#ifndef LINES
		gl_FragData[0].a = TEXTURE.a;
	#else
		gl_FragData[0].a = 1.0;
	#endif

	gl_FragData[1].a = 0.0; // for bloomy rain and stuff
	
	vec3 Direct_lighting = vec3(0.0);
	vec3 Indirect_lighting = vec3(0.0);
	vec3 Torch_Color = vec3(TORCH_R,TORCH_G,TORCH_B);
	
	#ifdef LIT
		Torch_Color *= LIT_PARTICLE_BRIGHTNESS;
	#endif

	#ifdef OVERWORLD_SHADER
		float Shadows = 1.0;
		
		vec3 feetPlayerPos_shadow = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
		vec3 projectedShadowPosition = mat3(shadowModelView) * feetPlayerPos_shadow + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		//apply distortion
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;

		//do shadows only if on shadow map
		if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution){

			projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);

			Shadows = shadow2D(shadow, projectedShadowPosition).x;
		}

		float cloudShadow = GetCloudShadow(feetPlayerPos);

		Direct_lighting = (lightCol.rgb/80.0) * Shadows * cloudShadow;
		

		#ifndef LINES
			Direct_lighting *= phaseg(clamp(dot(feetPlayerPos_normalized, WsunVec),0.0,1.0), 0.65)*2 + 0.5;
		#endif

		Indirect_lighting = DoAmbientLighting(averageSkyCol_Clouds, Torch_Color, clamp(lightmap.xy,0,1), 3.0);
	#endif
	
	#ifdef END_SHADER
   		float TorchLM = 10.0 - ( 1.0 / (pow(exp(-0.5*inversesqrt(lightmap.x)),5.0)+0.1));
   		TorchLM = pow(TorchLM/4,10) + pow(lightmap.x,1.5)*0.5;

		vec3 TorchLight = (Torch_Color * TorchLM * 0.75) * TORCH_AMOUNT;

		Indirect_lighting = max(vec3(0.5,0.75,1.0) * 0.1, (MIN_LIGHT_AMOUNT*0.01 + nightVision*0.5) ) + TorchLight;
	#endif

	#ifdef NETHER_SHADER
		vec3 AmbientLightColor = skyCloudsFromTexLOD2(vec3( 0, 1, 0), colortex4, 6).rgb / 10;

		vec3 nothing = vec3(0.0);
		Indirect_lighting = DoAmbientLighting_Nether(AmbientLightColor, Torch_Color, lightmap.x, nothing, nothing, nothing);
	#endif

	#ifdef FALLBACK_SHADER
		Indirect_lighting = DoAmbientLighting_Fallback(vec3(1.0), Torch_Color, lightmap.x, vec3(0.0), feetPlayerPos);
	#endif

	#ifndef LINES
		gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * Albedo;
	#else
		gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * toLinear(color.rgb);
	#endif

	// distance fade targeting the world border...
	if(TEXTURE.a < 0.7 && TEXTURE.a > 0.2) gl_FragData[0] *= clamp(1.0 - length(feetPlayerPos) / 100.0 ,0.0,1.0);
#endif
}