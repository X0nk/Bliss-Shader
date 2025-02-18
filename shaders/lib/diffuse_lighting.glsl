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