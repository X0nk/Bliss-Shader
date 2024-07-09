#include "/lib/settings.glsl"

// #if defined END_SHADER || defined NETHER_SHADER
// 	#undef IS_LPV_ENABLED
// #endif

#ifdef IS_LPV_ENABLED
	#extension GL_EXT_shader_image_load_store: enable
	#extension GL_ARB_shading_language_packing: enable
#endif

#include "/lib/res_params.glsl"

varying vec4 lmtexcoord;
varying vec4 color;
flat varying float exposure;

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

#ifdef IS_LPV_ENABLED
	uniform usampler1D texBlockData;
	uniform sampler3D texLpv1;
	uniform sampler3D texLpv2;
#endif


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

#include "/lib/util.glsl"

#ifdef OVERWORLD_SHADER
	
	#define CLOUDSHADOWSONLY
	#include "/lib/volumetricClouds.glsl"
#endif

#ifdef IS_LPV_ENABLED
	uniform int heldItemId;
	uniform int heldItemId2;
	uniform int frameCounter;

	#include "/lib/hsv.glsl"
	#include "/lib/lpv_common.glsl"
	#include "/lib/lpv_render.glsl"
#endif

#include "/lib/diffuse_lighting.glsl"
#include "/lib/sky_gradient.glsl"

vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

// #define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

uniform int framemod8;

#include "/lib/TAA_jitter.glsl"


//Mie phase function
float phaseg(float x, float g){
    float gg = g * g;
    return (gg * -0.25 + 0.25) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5) / 3.14;
}

//encoding by jodie
float encodeVec2(vec2 a){
    const vec2 constant1 = vec2( 1., 256.) / 65535.;
    vec2 temp = floor( a * 255. );
	return temp.x*constant1.x+temp.y*constant1.y;
}
float encodeVec2(float x,float y){
    return encodeVec2(vec2(x,y));
}



// #undef BASIC_SHADOW_FILTER
#ifdef OVERWORLD_SHADER
float ComputeShadowMap(inout vec3 directLightColor, vec3 playerPos, float maxDistFade){

	if(maxDistFade <= 0.0) return 1.0;

	// setup shadow projection
	vec3 projectedShadowPosition = mat3(shadowModelView) * playerPos + shadowModelView[3].xyz;
	projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

	// un-distort
	#ifdef DISTORT_SHADOWMAP
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;
	#else
		float distortFactor = 1.0;
	#endif

	// hamburger
	projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);
	
	float shadowmap = 0.0;
	vec3 translucentTint = vec3(0.0);

	#ifdef TRANSLUCENT_COLORED_SHADOWS

		// determine when opaque shadows are overlapping translucent shadows by getting the difference of opaque depth and translucent depth
		float shadowDepthDiff = pow(clamp((shadow2D(shadowtex1, projectedShadowPosition).x - projectedShadowPosition.z) * 2.0,0.0,1.0),2.0);

		// get opaque shadow data to get opaque data from translucent shadows.
		float opaqueShadow = shadow2D(shadowtex0, projectedShadowPosition).x;
		shadowmap += max(opaqueShadow, shadowDepthDiff);

		// get translucent shadow data
		vec4 translucentShadow = texture2D(shadowcolor0, projectedShadowPosition.xy);

		// this curve simply looked the nicest. it has no other meaning.
		float shadowAlpha = pow(1.0 - pow(translucentShadow.a,5.0),0.2);

		// normalize the color to remove luminance, and keep the hue. remove all opaque color.
		// mulitply shadow alpha to shadow color, but only on surfaces facing the lightsource. this is a tradeoff to protect subsurface scattering's colored shadow tint from shadow bias on the back of the caster.
		translucentShadow.rgb = max(normalize(translucentShadow.rgb + 0.0001), max(opaqueShadow, 1.0-shadowAlpha)) * shadowAlpha;

		// make it such that full alpha areas that arent in a shadow have a value of 1.0 instead of 0.0
		translucentTint += mix(translucentShadow.rgb, vec3(1.0),  opaqueShadow*shadowDepthDiff);

	#else
		shadowmap += shadow2D(shadow, projectedShadowPosition).x;
	#endif

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		// tint the lightsource color with the translucent shadow color
		directLightColor *= mix(vec3(1.0), translucentTint.rgb, maxDistFade);
	#endif

	return mix(1.0, shadowmap, maxDistFade);
}
#endif

#if defined DAMAGE_BLOCK_EFFECT && defined POM
#extension GL_ARB_shader_texture_lod : enable

mat3 inverseMatrix(mat3 m) {
  float a00 = m[0][0], a01 = m[0][1], a02 = m[0][2];
  float a10 = m[1][0], a11 = m[1][1], a12 = m[1][2];
  float a20 = m[2][0], a21 = m[2][1], a22 = m[2][2];

  float b01 = a22 * a11 - a12 * a21;
  float b11 = -a22 * a10 + a12 * a20;
  float b21 = a21 * a10 - a11 * a20;

  float det = a00 * b01 + a01 * b11 + a02 * b21;

  return mat3(b01, (-a22 * a01 + a02 * a21), (a12 * a01 - a02 * a11),
              b11, (a22 * a00 - a02 * a20), (-a12 * a00 + a02 * a10),
              b21, (-a21 * a00 + a01 * a20), (a11 * a00 - a01 * a10)) / det;
}
const float MAX_OCCLUSION_DISTANCE = MAX_DIST;
const float MIX_OCCLUSION_DISTANCE = MAX_DIST*0.9;
const int   MAX_OCCLUSION_POINTS   = MAX_ITERATIONS;

varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;

vec2 dcdx = dFdx(vtexcoord.st*vtexcoordam.pq)*exp2(Texture_MipMap_Bias);
vec2 dcdy = dFdy(vtexcoord.st*vtexcoordam.pq)*exp2(Texture_MipMap_Bias);


#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

uniform mat4 gbufferProjection;

vec3 toClipSpace3(vec3 viewSpacePosition) {
    return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

flat varying vec3 WsunVec2;
const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

	uniform sampler2D normals;
	varying vec4 tangent;
	varying vec4 normalMat;

	vec4 readNormal(in vec2 coord)
	{
		return texture2DGradARB(normals,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
	}
	vec4 readTexture(in vec2 coord)
	{
		return texture2DGradARB(texture,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
	}
#endif

uniform float near;
// uniform float far;
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

vec4 texture2D_POMSwitch(
	sampler2D sampler, 
	vec2 lightmapCoord,
	vec4 dcdxdcdy
){
	return texture2DGradARB(sampler, lightmapCoord, dcdxdcdy.xy, dcdxdcdy.zw);
}

uniform vec3 eyePosition;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

#ifdef DAMAGE_BLOCK_EFFECT
	/* RENDERTARGETS:11 */
#else
	/* DRAWBUFFERS:29 */
#endif

void main() {
	
#ifdef DAMAGE_BLOCK_EFFECT
	vec2 adjustedTexCoord = lmtexcoord.xy;
	#ifdef POM
		vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(0.0));
		vec3 worldpos = mat3(gbufferModelViewInverse) * fragpos  + gbufferModelViewInverse[3].xyz + cameraPosition;

		vec3 normal = normalMat.xyz;
		vec3 tangent2 = normalize(cross(tangent.rgb,normal)*tangent.w);
		mat3 tbnMatrix = mat3(tangent.x, tangent2.x, normal.x,
							  tangent.y, tangent2.y, normal.y,
							  tangent.z, tangent2.z, normal.z);

		adjustedTexCoord = fract(vtexcoord.st)*vtexcoordam.pq+vtexcoordam.st;
		vec3 viewVector = normalize(tbnMatrix*fragpos);

		float dist = length(fragpos);

		float maxdist = MAX_OCCLUSION_DISTANCE;

		// float depth  = gl_FragCoord.z;
		if (dist < maxdist) {

			float depthmap = readNormal(vtexcoord.st).a;
			float used_POM_DEPTH = 1.0;

	 		if ( viewVector.z < 0.0 && depthmap < 0.9999 && depthmap > 0.00001) {	

				#ifdef Adaptive_Step_length
					vec3 interval = (viewVector.xyz /-viewVector.z/MAX_OCCLUSION_POINTS * POM_DEPTH) * clamp(1.0-pow(depthmap,2),0.1,1.0);
					used_POM_DEPTH = 1.0;
				#else
					vec3 interval = viewVector.xyz/-viewVector.z/ MAX_OCCLUSION_POINTS*POM_DEPTH;
				#endif
				vec3 coord = vec3(vtexcoord.st, 1.0);

				coord += interval * used_POM_DEPTH;

				float sumVec = 0.5;
				for (int loopCount = 0; (loopCount < MAX_OCCLUSION_POINTS) && (1.0 - POM_DEPTH + POM_DEPTH * readNormal(coord.st).a  ) < coord.p  && coord.p >= 0.0; ++loopCount) {
					coord = coord + interval * used_POM_DEPTH; 
					sumVec += used_POM_DEPTH; 
				}

				if (coord.t < mincoord) {
					if (readTexture(vec2(coord.s,mincoord)).a == 0.0) {
						coord.t = mincoord;
						discard;
					}
				}

				adjustedTexCoord = mix(fract(coord.st)*vtexcoordam.pq+vtexcoordam.st, adjustedTexCoord, max(dist-MIX_OCCLUSION_DISTANCE,0.0)/(MAX_OCCLUSION_DISTANCE-MIX_OCCLUSION_DISTANCE));

				// vec3 truePos = fragpos + sumVec*inverseMatrix(tbnMatrix)*interval;

				// depth = toClipSpace3(truePos).z;
			}
		}

		vec4 Albedo = texture2D_POMSwitch(texture, adjustedTexCoord.xy, vec4(dcdx,dcdy));
	#else
		vec4 Albedo = texture2D(texture, adjustedTexCoord.xy);
	#endif
	
	Albedo.rgb = toLinear(Albedo.rgb);

	if(dot(Albedo.rgb, vec3(0.33333)) < 1.0/255.0 || Albedo.a < 0.01 ) { discard; return; }
	
	gl_FragData[0] = vec4(encodeVec2(vec2(0.5)), encodeVec2(Albedo.rg), encodeVec2(vec2(Albedo.b,0.02)), 1.0);
#endif

#if !defined DAMAGE_BLOCK_EFFECT
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
	
	#ifdef WhiteWorld
		TEXTURE.rgb = vec3(0.5);
	#endif

	vec3 Albedo = toLinear(TEXTURE.rgb);
	
	vec2 lightmap = clamp(lmtexcoord.zw,0.0,1.0);


	#ifndef OVERWORLD_SHADER
		lightmap.y = 1.0;
	#endif

	#if defined Hand_Held_lights && !defined LPV_ENABLED
		#ifdef IS_IRIS
			vec3 playerCamPos = eyePosition;
		#else
			vec3 playerCamPos = cameraPosition;
		#endif
		lightmap.x = max(lightmap.x, HELD_ITEM_BRIGHTNESS * clamp( pow(max(1.0-length((feetPlayerPos+cameraPosition) - playerCamPos)/HANDHELD_LIGHT_RANGE,0.0),1.5),0.0,1.0));
	#endif

	#ifdef WEATHER
		gl_FragData[1] = vec4(0.0,0.0,0.0,TEXTURE.a); // for bloomy rain and stuff
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
		vec3 directLightColor = vec3(0.0);

		vec3 Indirect_lighting = vec3(0.0);
		vec3 AmbientLightColor = vec3(0.0);
		vec3 Torch_Color = vec3(TORCH_R,TORCH_G,TORCH_B);
		vec3 MinimumLightColor = vec3(1.0);

		if(isEyeInWater == 1) MinimumLightColor = vec3(10.0);
		if(lightmap.x >= 0.9) Torch_Color *= LIT_PARTICLE_BRIGHTNESS;

		#ifdef OVERWORLD_SHADER
			directLightColor =  lightCol.rgb/80.0;
			float Shadows = 1.0;

			vec3 shadowPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;

			float shadowMapFalloff = smoothstep(0.0, 1.0, min(max(1.0 - length(shadowPlayerPos) / (shadowDistance+16),0.0)*5.0,1.0));
			float shadowMapFalloff2 = smoothstep(0.0, 1.0, min(max(1.0 - length(shadowPlayerPos) / (shadowDistance+11),0.0)*5.0,1.0));

			float LM_shadowMapFallback = min(max(lightmap.y-0.8, 0.0) * 25,1.0);

			Shadows = ComputeShadowMap(directLightColor, shadowPlayerPos, shadowMapFalloff);

			Shadows = mix(LM_shadowMapFallback, Shadows, shadowMapFalloff2);

			#ifdef CLOUDS_SHADOWS	
				Shadows *= GetCloudShadow(feetPlayerPos);
			#endif

			Direct_lighting = directLightColor * Shadows;

			#ifndef LINES
				Direct_lighting *= phaseg(clamp(dot(feetPlayerPos_normalized, WsunVec),0.0,1.0), 0.65)*2 + 0.5;
			#endif

			AmbientLightColor = averageSkyCol_Clouds / 30.0;

			#ifdef IS_IRIS
				AmbientLightColor *= 2.5;
			#else
				AmbientLightColor *= 0.5;
			#endif
			
			Indirect_lighting = doIndirectLighting(AmbientLightColor, MinimumLightColor, lightmap.y);
		#endif
		
		#ifdef NETHER_SHADER
			Indirect_lighting = skyCloudsFromTexLOD2(vec3(0.0,1.0,0.0), colortex4, 6).rgb / 30.0;
		#endif

		#ifdef END_SHADER
			Indirect_lighting = vec3(0.3,0.6,1.0) * 0.5;
		#endif

	///////////////////////// BLOCKLIGHT LIGHTING OR LPV LIGHTING OR FLOODFILL COLORED LIGHTING
		#ifdef IS_LPV_ENABLED
			vec3 lpvPos = GetLpvPosition(feetPlayerPos);
		#else
			const vec3 lpvPos = vec3(0.0);
		#endif

		Indirect_lighting += doBlockLightLighting( vec3(TORCH_R,TORCH_G,TORCH_B), lightmap.x, exposure, feetPlayerPos, lpvPos);

		#ifdef LINES
			gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * toLinear(color.rgb);

			if(SELECTION_BOX > 0) gl_FragData[0].rgba = vec4(toLinear(vec3(SELECT_BOX_COL_R, SELECT_BOX_COL_G, SELECT_BOX_COL_B)), 1.0);
		#else
			gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * Albedo;
		#endif

		// distance fade targeting the world border...
		if(TEXTURE.a < 0.7 && TEXTURE.a > 0.2) gl_FragData[0] *= clamp(1.0 - length(feetPlayerPos) / 100.0 ,0.0,1.0);

		gl_FragData[0].rgb *= 0.1;

	#endif
#endif
}