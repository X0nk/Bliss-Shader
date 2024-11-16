#ifdef IS_LPV_ENABLED
    vec3 GetHandLight(const in int itemId, const in vec3 playerPos, const in vec3 normal) {
        vec3 lightFinal = vec3(0.0);
        vec3 lightColor = vec3(0.0);
        float lightRange = 0.0;

        uvec2 blockData = texelFetch(texBlockData, itemId, 0).rg;
        vec4 lightColorRange = unpackUnorm4x8(blockData.r);
        lightColor = srgbToLinear(lightColorRange.rgb);
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
#endif

vec3 doBlockLightLighting(
    vec3 lightColor, float lightmap, float exposureValue,
    vec3 playerPos, vec3 lpvPos
){

    float lightmapCurve = pow(1.0-sqrt(1.0-clamp(lightmap,0.0,1.0)),2.0) * 2.0;
    
    vec3 blockLight = lightColor * lightmapCurve; //;
    
    #if defined IS_LPV_ENABLED && defined MC_GL_EXT_shader_image_load_store
        vec4 lpvSample = SampleLpvLinear(lpvPos);
        vec3 lpvBlockLight = GetLpvBlockLight(lpvSample);

        // create a smooth falloff at the edges of the voxel volume.
        float fadeLength = 10.0; // in meters
        vec3 cubicRadius = clamp( min(((LpvSize3-1.0) - lpvPos)/fadeLength,      lpvPos/fadeLength) ,0.0,1.0);
        float voxelRangeFalloff = cubicRadius.x*cubicRadius.y*cubicRadius.z;
        voxelRangeFalloff = 1.0 - pow(1.0-pow(voxelRangeFalloff,1.5),3.0);
        
        // outside the voxel volume, lerp to vanilla lighting as a fallback
        blockLight = mix(blockLight, lpvBlockLight/5.0, voxelRangeFalloff);

        #ifdef Hand_Held_lights
            // create handheld lightsources
            const vec3 normal = vec3(0.0); // TODO

                if (heldItemId > 0)
                blockLight += GetHandLight(heldItemId, playerPos, normal);

                if (heldItemId2 > 0)
                blockLight += GetHandLight(heldItemId2, playerPos, normal);
        #endif
    #endif

    // try to make blocklight have consistent visiblity in different light levels.
    float autoBrightness = mix(1.0, 30.0,  clamp(exp(-10.0*exposureValue),0.0,1.0));
    blockLight *= autoBrightness;
    
    return blockLight * TORCH_AMOUNT;
}

vec3 doIndirectLighting(
    vec3 lightColor, vec3 minimumLightColor, float lightmap
){

    float lightmapCurve = (pow(lightmap,15.0)*2.0 + pow(lightmap,2.5))*0.5;

    vec3 indirectLight = lightColor * lightmapCurve * ambient_brightness * 0.7; 

    indirectLight += minimumLightColor * max(MIN_LIGHT_AMOUNT*0.01, nightVision * 0.1);

    return indirectLight;
}