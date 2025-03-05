uniform float nightVision;

#ifdef IS_LPV_ENABLED
	vec3 GetHandLight(const in int itemId, const in vec3 playerPos, const in vec3 normal) {
		vec3 lightFinal = vec3(0.0);
		vec3 lightColor = vec3(0.0);
		float lightRange = 0.0;

		uvec2 blockData = texelFetch(texBlockData, itemId, 0).rg;
		vec4 lightColorRange = unpackUnorm4x8(blockData.r);
		lightColor = srgbToLinear(lightColorRange.rgb);
		#if defined LPV_SHADOWS && defined LPV_HAND_SHADOWS
			lightColor *= LPV_SHADOWS_LIGHT_MULT;
		#endif
		lightRange = lightColorRange.a * 255.0;

		if (lightRange > 0.0) {
			float lightDist = length(playerPos);
			vec3 lightDir = playerPos / lightDist;
			float NoL = 1.0;//max(dot(normal, lightDir), 0.0);
			float falloff = pow(1.0 - lightDist / lightRange, 3.0);
			lightFinal = lightColor * NoL * max(falloff, 0.0);
		}

		return lightFinal;
	}

	#ifdef LPV_SHADOWS
		#include "/lib/cube/cubeData.glsl"
		#include "/lib/cube/lightData.glsl"

		uniform usampler1D texCloseLights;
		#ifdef LPV_HAND_SHADOWS
			uniform vec3 relativeEyePosition;
			uniform vec3 playerLookVector;
		#endif
		#if !defined TRANSLUCENT_COLORED_SHADOWS || defined DAMAGE_BLOCK_EFFECT || !defined OVERWORLD_SHADER
			uniform sampler2DShadow shadowtex0;
			#ifdef LPV_COLOR_SHADOWS
				uniform sampler2DShadow shadowtex1;
				uniform sampler2D shadowcolor0;
			#endif
		#endif

		vec3 worldToCube(vec3 worldPos, out int faceIndex) {
			vec3 worldPosAbs = abs(worldPos);
			/*
			cubeBack, 0
			cubeTop, 1
			cubeDown, 2
			cubeLeft, 3
			cubeForward, 4
			cubeRight 5
			*/
			if (worldPosAbs.z >= worldPosAbs.x && worldPosAbs.z >= worldPosAbs.y) {
				// looking in z direction (forward | back)
				faceIndex = worldPos.z <= 0.0 ? 0 : 4;
			}
			else if (worldPosAbs.y >= worldPosAbs.x) {
				// looking in y direction (up | down)
				faceIndex = worldPos.y <= 0.0 ? 2 : 1;
			}
			else {
				// looking in x direction (left | right)
				faceIndex = worldPos.x <= 0.0 ? 5 : 3;
			}
			vec4 coord = cubeProjection * directionMatices[faceIndex] * vec4(worldPos, 1.0);
			coord.xyz /= coord.w;
			return coord.xyz * 0.5 + 0.5;
		}

		vec2 cubeOffset(vec2 relativeCoord, int faceIndex, int cube) {
			return relativeCoord*cubeTileRelativeResolution + cubeFaceOffsets[faceIndex] + renderOffsets[cube];
		}

		vec3 getCubeShadow(vec3 cubeShadowPos, int faceIndex, int cube) {
			vec3 pos = vec3(cubeOffset(cubeShadowPos.xy, faceIndex, cube), cubeShadowPos.z);
			float solid = texture(shadowtex0, pos);
			#ifdef LPV_COLOR_SHADOWS
				float noTrans = texture(shadowtex1, pos);
				return noTrans > solid ? texture(shadowcolor0, pos.xy).rgb : vec3(solid);
			#else
				return vec3(solid);
			#endif
		}
	#endif
#endif

vec3 doBlockLightLighting(
	vec3 lightColor, float lightmap, float exposureValue,
	vec3 playerPos, vec3 lpvPos, vec3 normalWorld
){
	lightmap = clamp(lightmap,0.0,1.0);

	float lightmapBrightspot = min(max(lightmap-0.7,0.0)*3.3333,1.0);
	lightmapBrightspot *= lightmapBrightspot*lightmapBrightspot;

	float lightmapLight = 1.0-sqrt(1.0-lightmap);
	lightmapLight *= lightmapLight;

	float lightmapCurve = mix(lightmapLight, 2.5, lightmapBrightspot);
	vec3 blockLight = lightmapCurve * lightColor;
    
    
	#if defined IS_LPV_ENABLED && defined MC_GL_EXT_shader_image_load_store
		vec4 lpvSample = SampleLpvLinear(lpvPos);
		#ifdef VANILLA_LIGHTMAP_MASK
			lpvSample.rgb *= lightmapCurve;
		#endif
		vec3 lpvBlockLight = GetLpvBlockLight(lpvSample);

		// create a smooth falloff at the edges of the voxel volume.
		float fadeLength = 10.0; // in meters
		vec3 cubicRadius = clamp( min(((LpvSize3-1.0) - lpvPos)/fadeLength,      lpvPos/fadeLength) ,0.0,1.0);
		float voxelRangeFalloff = cubicRadius.x*cubicRadius.y*cubicRadius.z;
		voxelRangeFalloff = 1.0 - pow(1.0-pow(voxelRangeFalloff,1.5),3.0);
        
		// outside the voxel volume, lerp to vanilla lighting as a fallback
		blockLight = mix(blockLight, lpvSample.rgb, voxelRangeFalloff);

		#ifdef Hand_Held_lights
			// create handheld lightsources
			const vec3 normal = vec3(0.0); // TODO

		        if (heldItemId > 0)
				blockLight += GetHandLight(heldItemId, playerPos, normal);

			if (heldItemId2 > 0)
				blockLight += GetHandLight(heldItemId2, playerPos, normal);
		#endif

		#ifdef LPV_SHADOWS
			for(int i = 0; i < LPV_SHADOWS_LIGHT_COUNT; i++){
				uint data = texelFetch(texCloseLights, i, 0).r;
				float dist;
				ivec3 pos;
				uint blockId;
				if (getLightData(data, dist, pos, blockId)) {
					vec3 lightPos = -fract(previousCameraPosition) - cameraPosition + previousCameraPosition + vec3(pos) - 14.5;
					#ifdef LPV_HAND_SHADOWS
						if (dist < 0.0001) {
							vec2 viewDir = normalize(playerLookVector.xz) * 0.25;
							lightPos = -relativeEyePosition + vec3(viewDir.x, 0, viewDir.y);
						}
					#endif
					int face = 0;
					vec3 dir = playerPos - lightPos;
					float d = dot(-normalWorld, normalize(dir-0.1));
					if (d > 0) {
						uint blockData = texelFetch(texBlockData, int(blockId), 0).r;
						vec4 lightColorRange = unpackUnorm4x8(blockData);
						lightColorRange.a *= 255.0;
						float dist = length(dir);
						if (dist < lightColorRange.a) {
							const float bias = (3072.0 / shadowMapResolution) * 0.05;
							vec3 pos = worldToCube(dir + normalWorld * (0.05 + bias - bias * d), face);
							float blend = (1.0 - dist / lightColorRange.a) / (1.0 + dist * -0.3 + dist * dist * 0.4);
							blockLight += d * srgbToLinear(lightColorRange.rgb) * getCubeShadow(pos, face, i) * blend;
						}
					}
				} else {
					// since lights are sorted, if one light is invalid all followings are aswell
 					break;
				}
			}
		#endif
	#endif

	// try to make blocklight have consistent visiblity in different light levels.
	// float autoBrightness = mix(0.5, 1.0,  clamp(exp(-10.0*exposureValue),0.0,1.0));
	// blockLight *= autoBrightness;
    
	return blockLight * TORCH_AMOUNT;
}

vec3 doIndirectLighting(
	vec3 lightColor, vec3 minimumLightColor, float lightmap
){

	float lightmapCurve = pow(lightmap, 15.0) + pow(lightmap, 2.5) * 0.5;

	vec3 indirectLight = lightColor * lightmapCurve * ambient_brightness * 0.7; 

	indirectLight += minimumLightColor * ((MIN_LIGHT_AMOUNT * 0.2 + nightVision) * 0.02);

	return indirectLight;
}

uniform float centerDepthSmooth;
vec3 calculateFlashlight(in vec2 texcoord, in vec3 viewPos, in vec3 albedo, in vec3 normal, out vec4 flashLightSpecularData, bool hand){

	vec3 shiftedViewPos = viewPos + vec3(-0.25, 0.2, 0.0);
	vec3 shiftedPlayerPos = mat3(gbufferModelViewInverse) * shiftedViewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition) * 3.0;
	shiftedViewPos = mat3(gbufferPreviousModelView) * shiftedPlayerPos + gbufferPreviousModelView[3].xyz;
	vec2 scaledViewPos = shiftedViewPos.xy / max(-shiftedViewPos.z - 0.5, 1e-7);
	float linearDistance = length(shiftedPlayerPos);
	float shiftedLinearDistance = length(scaledViewPos);

	float lightFalloff = 1.0 - clamp(1.0-linearDistance/FLASHLIGHT_RANGE, -0.999,1.0);
	lightFalloff = max(exp(-10.0 * FLASHLIGHT_BRIGHTNESS_FALLOFF_MULT * lightFalloff),0.0);

	#if defined FLASHLIGHT_SPECULAR && (defined DEFERRED_SPECULAR || defined FORWARD_SPECULAR)
		float flashLightSpecular = lightFalloff * exp2(-7.0*shiftedLinearDistance*shiftedLinearDistance) * FLASHLIGHT_BRIGHTNESS_MULT;
		flashLightSpecularData = vec4(normalize(shiftedPlayerPos), flashLightSpecular);	
	#endif

	float projectedCircle = clamp(1.0 - shiftedLinearDistance*FLASHLIGHT_SIZE,0.0,1.0);
	float lenseDirt = texture2D(noisetex, scaledViewPos * 0.2 + 0.1).b;
	float lenseShape = (pow(abs(pow(abs(projectedCircle-1.0),2.0)*2.0 - 0.5),2.0) + lenseDirt*0.2) * 10.0;
	
	float offsetNdotL = clamp(dot(-normal, normalize(shiftedPlayerPos)),0,1);
	vec3 flashlightDiffuse = vec3(1.0) * lightFalloff * offsetNdotL * pow(1.0-pow(1.0-projectedCircle,2),2) * lenseShape * FLASHLIGHT_BRIGHTNESS_MULT;
	
	if(hand){
		flashlightDiffuse = vec3(0.0);
		flashLightSpecularData = vec4(0.0);
	}

	#ifdef FLASHLIGHT_BOUNCED_INDIRECT
		float lightWidth = 1.0+linearDistance*3.0;
		vec3 pointPos = mat3(gbufferModelViewInverse) *  (toScreenSpace(vec3(texcoord, centerDepthSmooth)) + vec3(-0.25, 0.2, 0.0));
		float flashLightHitPoint = distance(pointPos, shiftedPlayerPos);

		float indirectFlashLight = exp(-10.0 * (1.0 - clamp(1.0-length(shiftedViewPos.xy)/lightWidth,0.0,1.0)) );
		indirectFlashLight *= pow(clamp(1.0-flashLightHitPoint/lightWidth,0,1),2.0);

		flashlightDiffuse += albedo/150.0 * indirectFlashLight * lightFalloff;
	#endif

	return flashlightDiffuse * vec3(FLASHLIGHT_R,FLASHLIGHT_G,FLASHLIGHT_B);
}