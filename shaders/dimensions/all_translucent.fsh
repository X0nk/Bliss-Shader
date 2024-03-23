#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

varying vec4 lmtexcoord;
varying vec4 color;

#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;
	
	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif

	uniform float lightSign;
	flat varying vec3 WsunVec;

	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;
#endif

#ifdef BLOCKENTITIES
	#undef WATER_REFLECTIONS
#endif

#ifdef ENTITIES
	#undef WATER_BACKGROUND_SPECULAR
	#undef SCREENSPACE_REFLECTIONS
#endif

flat varying float HELD_ITEM_BRIGHTNESS;

const bool colortex4MipmapEnabled = true;
uniform sampler2D noisetex;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;
uniform sampler2D dhDepthTex1;
uniform sampler2D colortex12;
uniform sampler2D colortex14;
uniform sampler2D colortex5;

uniform sampler2D texture;
uniform sampler2D specular;
uniform sampler2D normals;

varying vec4 tangent;
varying vec4 normalMat;
varying vec3 binormal;
varying vec3 flatnormal;




uniform vec3 sunVec;
uniform float near;
// uniform float far;
uniform float sunElevation;

uniform int isEyeInWater;
uniform float rainStrength;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform ivec2 eyeBrightnessSmooth;

uniform int frameCounter;
uniform float frameTimeCounter;
uniform vec2 texelSize;
uniform int framemod8;

uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;


uniform float moonIntensity;
uniform float sunIntensity;
uniform vec3 sunColor;
uniform vec3 nsunColor;

#include "/lib/Shadow_Params.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/projections.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/waterBump.glsl"

#ifdef OVERWORLD_SHADER
	flat varying float Flashing;
	#include "/lib/lightning_stuff.glsl"
	#include "/lib/volumetricClouds.glsl"
#else
	uniform sampler2D colortex4;
	uniform float nightVision;
#endif

#ifdef END_SHADER
	#include "/lib/end_fog.glsl"
#endif

#include "/lib/diffuse_lighting.glsl"

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter) ;
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000);
	// vec2 coord = gl_FragCoord.xy + frameTimeCounter;
	// vec2 coord = gl_FragCoord.xy;
	float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715)) );
	return noise ;
}
float interleaved_gradientNoise(float temporal){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)+temporal);
	return noise;
}

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);







#define PW_DEPTH 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0]
#define PW_POINTS 1 //[2 4 6 8 16 32]

varying vec3 viewVector;
vec3 getParallaxDisplacement(vec3 posxz) {

	vec3 parallaxPos = posxz;
	vec2 vec = viewVector.xy * (1.0 / float(PW_POINTS)) * 22.0;
	float waterHeight = getWaterHeightmap(posxz.xz);
	parallaxPos.xz += waterHeight * vec;

	return parallaxPos;
}

// vec3 getParallaxDisplacement(vec3 posxz,float bumpmult,vec3 viewVec) {

// 	vec3 parallaxPos = posxz;
// 	vec2 vec = viewVector.xy * (1.0 / float(PW_POINTS)) * 22.0 * PW_DEPTH;
// 	float waterHeight = getWaterHeightmap(posxz.xz) ;
	
// 	parallaxPos.xz += waterHeight * vec;

// 	return parallaxPos;

// }

vec3 applyBump(mat3 tbnMatrix, vec3 bump, float puddle_values){
	float bumpmult = 1;
	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
	return normalize(bump*tbnMatrix);
}

// vec2 tapLocation(int sampleNumber,int nb, float nbRot,float jitter,float distort)
// {
//     float alpha = (sampleNumber+jitter)/nb;
//     float angle = jitter*6.28 + alpha * nbRot * 6.28;

//     float sin_v, cos_v;

// 	sin_v = sin(angle);
// 	cos_v = cos(angle);

//     return vec2(cos_v, sin_v)*sqrt(alpha);
// }
vec2 tapLocation_simple(
	int samples, int totalSamples, float rotation, float rng
){
	const float PI = 3.141592653589793238462643383279502884197169;
    float alpha = float(samples + rng) * (1.0 / float(totalSamples));
    float angle = alpha * (rotation * PI);

	float sin_v = sin(angle);
	float cos_v = cos(angle);

    return vec2(cos_v, sin_v) * sqrt(alpha);
}


vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}

vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}
vec4 encode (vec3 n, vec2 lightmaps){
	n.xy = n.xy / dot(abs(n), vec3(1.0));
	n.xy = n.z <= 0.0 ? (1.0 - abs(n.yx)) * sign(n.xy) : n.xy;
    vec2 encn = clamp(n.xy * 0.5 + 0.5,-1.0,1.0);
	
    return vec4(encn,vec2(lightmaps.x,lightmaps.y));
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


float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

vec3 rayTrace(vec3 dir, vec3 position,float dither, float fresnel, bool inwater){

    float quality = mix(15,SSR_STEPS,fresnel);
    vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
       (-near -position.z) / dir.z : far*sqrt(3.);
    vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
    direction.xy = normalize(direction.xy);

    //get at which length the ray intersects with the edge of the screen
    vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
    float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);


    vec3 stepv = direction * mult / quality * vec3(RENDER_SCALE,1.0);


	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) + stepv*dither;
	float minZ = clipPosition.z;
	float maxZ = spos.z+stepv.z*0.5;
	
	spos.xy += offsets[framemod8]*texelSize*0.5/RENDER_SCALE;

	float dist = 1.0 + clamp(position.z*position.z/50.0,0,2); // shrink sample size as distance increases
    for (int i = 0; i <= int(quality); i++) {

		// decode depth buffer
		// float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/texelSize/4),0).w/65000.0);
		#ifdef HAND
			vec2 testthing = spos.xy*texelSize; // fix for ssr on hand
		#else
			vec2 testthing = spos.xy/texelSize/4.0;
		#endif
		float sp = sqrt((texelFetch2D(colortex4,ivec2(testthing),0).a)/65000.0);
		sp = invLinZ(sp);

        if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ)) return vec3(spos.xy/RENDER_SCALE,sp);


        spos += stepv;
		//small bias
		if(inwater) {
			minZ = maxZ-0.000035/ld(spos.z);
		}else{
			minZ = maxZ-(0.0001/dist)/ld(spos.z);
		}
		maxZ += stepv.z;
    }

    return vec3(1.1);
}

vec3 GGX (vec3 n, vec3 v, vec3 l, float r, vec3 F0) {
  r = pow(r,2.5);

  vec3 h = l + v;
  float hn = inversesqrt(dot(h, h));

  float dotLH = clamp(dot(h,l)*hn,0.,1.);
  float dotNH = clamp(dot(h,n)*hn,0.,1.) ;
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNHsq = dotNH*dotNH;

  float denom = dotNHsq * r - dotNHsq + 1.0;
  float D = r / (3.141592653589793 * denom * denom);
  vec3 F = 0.2 + (1. - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
  float k2 = .25 * r;

  return dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
}


uniform float dhFarPlane;

#include "/lib/DistantHorizons_projections.glsl"
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

uniform vec4 entityColor;
/* RENDERTARGETS:2,7,11,14 */
void main() {
if (gl_FragCoord.x * texelSize.x < 1.0  && gl_FragCoord.y * texelSize.y < 1.0 )	{
	
	vec2 tempOffset = offsets[framemod8];
	
	vec3 viewPos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));

	vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
	

	//////////////////////////////// 
	//////////////////////////////// ALBEDO
	//////////////////////////////// 



	gl_FragData[0] = texture2D(texture, lmtexcoord.xy, Texture_MipMap_Bias) * color;


	
	vec3 Albedo = toLinear(gl_FragData[0].rgb);
	float UnchangedAlpha = gl_FragData[0].a;

	float iswater = normalMat.w;

	#ifdef HAND
		iswater = 0.1;
	#endif

	#ifdef Vanilla_like_water
		if (iswater > 0.95){
			Albedo *= sqrt(luma(Albedo));
			// Albedo = toLinear( gl_FragData[0].rgb * sqrt(luma(gl_FragData[0].rgb)));
		}
	#else
		if (iswater > 0.95){
			Albedo = vec3(0.0);
			gl_FragData[0].a = 1.0/255.0;
		}
	#endif


	vec4 COLORTEST = vec4(Albedo, UnchangedAlpha);
	
	#ifdef BIOME_TINT_WATER
		if (iswater > 0.95) COLORTEST.rgb = color.rgb;
	#endif


	//////////////////////////////// 
	//////////////////////////////// NORMAL
	//////////////////////////////// 

	vec3 normal = normalMat.xyz;
	vec2 TangentNormal = vec2(0); // for refractions
	
	vec3 tangent2 = normalize(cross(tangent.rgb,normal)*tangent.w);
	mat3 tbnMatrix = mat3(tangent.x, tangent2.x, normal.x,
						  tangent.y, tangent2.y, normal.y,
						  tangent.z, tangent2.z, normal.z);

	vec4 NormalTex = texture2D(normals, lmtexcoord.xy, Texture_MipMap_Bias).rgba;
	
	NormalTex.xy = NormalTex.xy*2.0-1.0;
	NormalTex.z = clamp(sqrt(1.0 - dot(NormalTex.xy, NormalTex.xy)),0.0,1.0) ;
	TangentNormal = NormalTex.xy*0.5+0.5;

	normal = applyBump(tbnMatrix, NormalTex.xyz,  1.0);

	
	#ifndef HAND
		if (iswater > 0.95){
			vec3 posxz = feetPlayerPos + cameraPosition;
		
			float bumpmult = 1.0;

			posxz.xyz = getParallaxDisplacement(posxz) ;

			vec3 bump = normalize(getWaveNormal(posxz, false));

			TangentNormal = (bump.xy/3.0)*0.5+0.5; // tangent space normals for refraction

			bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
			normal = normalize(bump * tbnMatrix);
		}
	#endif

	gl_FragData[2] = vec4(encodeVec2(TangentNormal), encodeVec2(COLORTEST.rg), encodeVec2(COLORTEST.ba), UnchangedAlpha);

	vec3 WS_normal = viewToWorld(normal);
	//////////////////////////////// 
	//////////////////////////////// DIFFUSE LIGHTING
	//////////////////////////////// 

	vec2 lightmap = lmtexcoord.zw;
	
	#ifndef OVERWORLD_SHADER
		lightmap.y = 1.0;
	#endif
	
	#ifdef Hand_Held_lights
		lightmap.x = max(lightmap.x, HELD_ITEM_BRIGHTNESS*clamp( pow(max(1.0-length(viewPos)/HANDHELD_LIGHT_RANGE,0.0),1.5),0.0,1.0));
	#endif

	vec3 Indirect_lighting = vec3(0.0);
	vec3 MinimumLightColor = vec3(1.0);
	if(isEyeInWater == 1) MinimumLightColor = vec3(10.0);
	vec3 Direct_lighting = vec3(0.0);

	#ifdef OVERWORLD_SHADER
		float NdotL = clamp(dot(normal, normalize(WsunVec*mat3(gbufferModelViewInverse))),0.0,1.0); NdotL = clamp((-15 + NdotL*255.0) / 240.0  ,0.0,1.0);
		vec3 Shadows = vec3(0.0);
		bool inShadowmapBounds = false;

		vec3 feetPlayerPos_shadow = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;

		// mat4 Custom_ViewMatrix = BuildShadowViewMatrix(LightDir);
		// vec3 projectedShadowPosition = mat3(Custom_ViewMatrix) * feetPlayerPos_shadow  + Custom_ViewMatrix[3].xyz;
		vec3 projectedShadowPosition = mat3(shadowModelView) * feetPlayerPos_shadow  + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		//apply distortion
		#ifdef DISTORT_SHADOWMAP
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;
		#else
			float distortFactor = 1.0;
		#endif
		
		bool ShadowBounds = false;
		if(shadowDistanceRenderMul > 0.0) ShadowBounds = length(feetPlayerPos_shadow) < max(shadowDistance - 20,0.0);
		
		if(shadowDistanceRenderMul < 0.0) ShadowBounds = abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0;

		// sample shadows only if on shadow map
		if(ShadowBounds){
			if (NdotL > 0.0){
				Shadows = vec3(0.0);
				projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);

				#ifndef HAND
					#ifdef BASIC_SHADOW_FILTER
						const float threshMul = max(2048.0/shadowMapResolution*shadowDistance/128.0,0.95);
						float distortThresh = (sqrt(1.0-NdotL*NdotL)/NdotL+0.7)/distortFactor;
						float diffthresh = distortThresh/6000.0*threshMul;

						float rdMul = 4.0/shadowMapResolution;
						float noise = blueNoise();

						int SampleCount = 7;
						for(int i = 0; i < SampleCount; i++){
							vec2 offsetS = tapLocation_simple(i, 7, 9, noise) * 0.5;
							float weight = 1.0+(i+noise)*rdMul/9.0*shadowMapResolution;

							#ifdef TRANSLUCENT_COLORED_SHADOWS
								vec3 shadowProjOffsets = projectedShadowPosition + vec3(rdMul*offsetS, -diffthresh*weight);
							
								float opaqueShadow = shadow2D(shadowtex0, shadowProjOffsets).x;
								Shadows += vec3(opaqueShadow/SampleCount);

								if(shadow2D(shadowtex1, shadowProjOffsets).x > shadowProjOffsets.z){ 
									vec4 translucentShadow = texture2D(shadowcolor0, shadowProjOffsets.xy);
									if(translucentShadow.a < 0.9) Shadows += (normalize(translucentShadow.rgb+0.0001) * clamp(1.0-opaqueShadow,0.0,1.0)) / SampleCount;
								}

							#else
								Shadows += vec3(shadow2D(shadow, projectedShadowPosition + vec3(rdMul*offsetS, -diffthresh*weight)).x / SampleCount);
							#endif
	
						}
					#else
					
						#ifdef TRANSLUCENT_COLORED_SHADOWS
							projectedShadowPosition -= vec3(0.0,0.0,0.0001);
							Shadows = vec3(shadow2D(shadowtex0, projectedShadowPosition ).x);

							if(shadow2D(shadowtex1, projectedShadowPosition).x > projectedShadowPosition.z){	 
								vec4 shadowLightColor = texture2D(shadowcolor0, projectedShadowPosition.xy);
								if(shadowLightColor.a < 0.9) Shadows += normalize(shadowLightColor.rgb+0.0001);
							}
						#else
							Shadows = vec3(shadow2D(shadow, projectedShadowPosition - vec3(0.0,0.0,0.0001)).x);
						#endif
					
					#endif
					



				#else
					Shadows = vec3(shadow2D(shadow, projectedShadowPosition - vec3(0.0,0.0,0.0005)).x);
				#endif
			}
			inShadowmapBounds = true;
		}

		if(!inShadowmapBounds) Shadows = vec3(1.0);

		Shadows *= GetCloudShadow(feetPlayerPos);

		Direct_lighting = (lightCol.rgb/80.0) * NdotL * Shadows;

		vec3 AmbientLightColor = averageSkyCol_Clouds/30.0;
		
		vec3 ambientcoefs = WS_normal / dot(abs(WS_normal), vec3(1));
		float SkylightDir = ambientcoefs.y*1.5;
		
		float skylight = max(pow(viewToWorld(flatnormal).y*0.5+0.5,0.1) + SkylightDir, 0.25);
		AmbientLightColor *= skylight;
	#endif

	#ifdef NETHER_SHADER
		// vec3 AmbientLightColor = skyCloudsFromTexLOD2(WS_normal, colortex4, 6).rgb / 15.0;
		
		// vec3 up 	= skyCloudsFromTexLOD2(vec3( 0, 1, 0), colortex4, 6).rgb/ 30.0;
		// vec3 down 	= skyCloudsFromTexLOD2(vec3( 0,-1, 0), colortex4, 6).rgb/ 30.0;

		// up   *= pow( max( WS_normal.y, 0), 2);
		// down *= pow( max(-WS_normal.y, 0), 2);
		// AmbientLightColor += up + down;
		
		vec3 AmbientLightColor = vec3(0.1);
		
	#endif

	#ifdef END_SHADER

		
		float vortexBounds = clamp(vortexBoundRange - length(feetPlayerPos+cameraPosition), 0.0,1.0);
        vec3 lightPos = LightSourcePosition(feetPlayerPos+cameraPosition, cameraPosition,vortexBounds);


		float lightningflash = texelFetch2D(colortex4,ivec2(1,1),0).x/150.0;
		vec3 lightColors = LightSourceColors(vortexBounds, lightningflash);

		float NdotL = clamp(dot(WS_normal, normalize(-lightPos))*0.5+0.5,0.0,1.0);
		NdotL *= NdotL;

		Direct_lighting = lightColors * endFogPhase(lightPos) * NdotL;

		vec3 AmbientLightColor = vec3(0.5,0.75,1.0) * 0.9 + 0.1;
		AmbientLightColor *= clamp(1.5 + dot(WS_normal, normalize(feetPlayerPos))*0.5,0,2);
	
	#endif
	Indirect_lighting = DoAmbientLightColor(AmbientLightColor, MinimumLightColor, vec3(TORCH_R,TORCH_G,TORCH_B), lightmap.xy);
	
	#ifdef ENTITIES
		Albedo.rgb = mix(Albedo.rgb, entityColor.rgb, clamp(entityColor.a*1.5,0,1));
	#endif

	vec3 FinalColor = (Indirect_lighting + Direct_lighting) * Albedo;
	
	// #ifdef Glass_Tint
	// 	FinalColor *= min(pow(gl_FragData[0].a,2.0),1.0);
	// #endif

	//////////////////////////////// 
	//////////////////////////////// SPECULAR
	//////////////////////////////// 
	#ifdef DAMAGE_BLOCK_EFFECT
		#undef WATER_REFLECTIONS
	#endif
	
	#ifdef WATER_REFLECTIONS
		vec2 SpecularTex = texture2D(specular, lmtexcoord.xy, Texture_MipMap_Bias).rg;
		
		SpecularTex = (iswater > 0.0 && iswater < 0.9) && SpecularTex.r > 0.0 && SpecularTex.g < 0.9 ? SpecularTex : vec2(1.0,0.02);
	
		float roughness = max(pow(1.0-SpecularTex.r,2.0),0.05);
		float f0 = SpecularTex.g;

		// roughness = 0.1;
		// f0 = 1.0;

		if (iswater > 0.0 && gl_FragData[0].a < 0.9999999){
			vec3 Reflections_Final = vec3(0.0);
			vec4 Reflections = vec4(0.0);
			vec3 SkyReflection = vec3(0.0); 
			vec3 SunReflection = vec3(0.0);
			
			float indoors = clamp((lightmap.y-0.6)*5.0, 0.0,1.0);
	
			vec3 reflectedVector = reflect(normalize(viewPos), normal);

			float normalDotEye = dot(normal, normalize(viewPos));
			float fresnel =  pow(clamp(1.0 + normalDotEye, 0.0, 1.0),5.0);

			#ifdef SNELLS_WINDOW
				// snells window looking thing
				if(isEyeInWater == 1) fresnel = pow(clamp(1.5 + normalDotEye,0.0,1.0), 25.0);
			#endif

			fresnel = mix(f0, 1.0, fresnel); 

			vec3 Metals = f0 > 229.5/255.0 ? normalize(Albedo+1e-7) * (dot(Albedo,vec3(0.21, 0.72, 0.07)) * 0.7 + 0.3) : vec3(1.0);
			
	
			// Sun, Sky, and screen-space reflections
			#ifdef OVERWORLD_SHADER
				#ifdef WATER_SUN_SPECULAR
					SunReflection = Direct_lighting * GGX(normal, -normalize(viewPos), WsunVec*mat3(gbufferModelViewInverse), roughness, vec3(f0)) ; 
				#endif
				#ifdef WATER_BACKGROUND_SPECULAR
 					if(isEyeInWater == 0) SkyReflection = skyCloudsFromTex(mat3(gbufferModelViewInverse) * reflectedVector, colortex4).rgb / 30.0 ;
				#endif
			#else
				#ifdef WATER_BACKGROUND_SPECULAR 
 					if(isEyeInWater == 0) SkyReflection = skyCloudsFromTexLOD2(mat3(gbufferModelViewInverse) * reflectedVector, colortex4, 0).rgb / 30.0 ;
				#endif
			#endif
			#ifdef SCREENSPACE_REFLECTIONS
				if(iswater > 0.0){
					vec3 rtPos = rayTrace(reflectedVector, viewPos.xyz, interleaved_gradientNoise(), fresnel, isEyeInWater == 1);
					if (rtPos.z < 1.){
						vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rtPos) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
						previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
						previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
						if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
							Reflections.a = 1.0;
							Reflections.rgb = texture2D(colortex5,previousPosition.xy).rgb ;
						}
					}
				}
			#endif

			#ifdef OVERWORLD_SHADER
				if(isEyeInWater == 1 && iswater > 0.9){
				 	SkyReflection.rgb = exp(-8.0 * vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B)) * clamp(WsunVec.y*lightCol.a,0,1) ;
				}
			#endif
			float visibilityFactor = clamp(exp2((pow(roughness,3.0) / f0) * -4),0,1);

			#ifdef ENTITIES
				Reflections_Final = FinalColor;
			#else
				Reflections_Final = mix(SkyReflection*indoors, Reflections.rgb, Reflections.a);
				Reflections_Final = mix(FinalColor, Reflections_Final * Metals, fresnel);
			#endif
			
			Reflections_Final += SunReflection * Metals;

			
			gl_FragData[0].rgb = Reflections_Final ;
			
			#ifndef ENTITIES
				//correct alpha channel with fresnel
				gl_FragData[0].a = mix(gl_FragData[0].a, 1.0, fresnel);
			#endif

	
		} else {
			
			gl_FragData[0].rgb = FinalColor;
		}
	
	#else
		gl_FragData[0].rgb = FinalColor;
	#endif
	
    // gl_FragData[0].rgb = vec3(1) * (texelFetch2D(depthtex0,ivec2(gl_FragCoord.xy),0).x - texelFetch2D(dhDepthTex1,ivec2(gl_FragCoord.xy),0).x);


	#if defined DISTANT_HORIZONS && defined DH_OVERDRAW_PREVENTION
    	gl_FragData[0].a = mix(gl_FragData[0].a, 0.0,  1.0-min(max(1.0 - length(feetPlayerPos.xz)/max(far,0.0),0.0)*2.0,1.0) );
	#endif

	#ifndef HAND
		gl_FragData[1] = vec4(Albedo, iswater);
	#endif
	
	#if DEBUG_VIEW == debug_DH_WATER_BLENDING
		if(gl_FragCoord.x*texelSize.x < 0.47) gl_FragData[0] = vec4(0.0);
	#endif

	gl_FragData[3].a = lmtexcoord.w;
}
}