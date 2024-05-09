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

vec3 DoAmbientLightColor(
    vec3 playerPos,
    vec3 lpvPos,
    vec3 SkyColor,
    vec3 MinimumColor,
    vec3 TorchColor, 
    vec2 Lightmap,
    float Exposure
){
	// Lightmap = vec2(0.0,1.0);

    float LightLevelZero = clamp(pow(eyeBrightnessSmooth.y/240. + Lightmap.y,2.0) ,0.0,1.0);

    // do sky lighting.
    float skyLM = (pow(Lightmap.y,15.0)*2.0 + pow(Lightmap.y,2.5))*0.5;
    vec3 MinimumLight = MinimumColor * (MIN_LIGHT_AMOUNT*0.01 + nightVision);
    vec3 IndirectLight = max(SkyColor * ambient_brightness * skyLM * 0.7,     MinimumLight); 
    
    // do torch lighting
    float TorchLM = pow(1.0-sqrt(1.0-clamp(Lightmap.x,0.0,1.0)),2.0) * 2.0;
    float TorchBrightness_autoAdjust = mix(1.0, 30.0,  clamp(exp(-10.0*Exposure),0.0,1.0)) ;
    vec3 TorchLight = TorchColor * TorchLM * TORCH_AMOUNT  ;
    
    #if defined IS_LPV_ENABLED && defined MC_GL_EXT_shader_image_load_store
        vec4 lpvSample = SampleLpvLinear(lpvPos);
        vec3 LpvTorchLight = GetLpvBlockLight(lpvSample);

        // i gotchu
        float fadeLength = 10.0; // in blocks
        vec3 cubicRadius = clamp( min(((LpvSize3-1.0) - lpvPos)/fadeLength,      lpvPos/fadeLength) ,0.0,1.0);
        float LpvFadeF = cubicRadius.x*cubicRadius.y*cubicRadius.z;

        LpvFadeF = 1.0 - pow(1.0-pow(LpvFadeF,1.5),3.0); // make it nice and soft :)
        
        TorchLight = mix(TorchLight,LpvTorchLight/5.0,   LpvFadeF);

        const vec3 normal = vec3(0.0); // TODO

        if (heldItemId > 0)
            TorchLight += GetHandLight(heldItemId, playerPos, normal);

        if (heldItemId2 > 0)
            TorchLight += GetHandLight(heldItemId2, playerPos, normal);
    #endif

    return IndirectLight + TorchLight * TorchBrightness_autoAdjust;
}


// this is dumb, and i plan to remove it eventually...
vec4 RT_AmbientLight(
    vec3 playerPos,
    vec3 lpvPos,
    float Exposure,
    vec2 Lightmap,
    vec3 TorchColor
){
    float skyLM = (pow(Lightmap.y,15.0)*2.0 + pow(Lightmap.y,2.5))*0.5;


    // do torch lighting
    float TorchLM = pow(1.0-sqrt(1.0-clamp(Lightmap.x,0.0,1.0)),2.0) * 2.0;
    float TorchBrightness_autoAdjust = mix(1.0, 30.0,  clamp(exp(-10.0*Exposure),0.0,1.0)) ;
    vec3 TorchLight = TorchColor * TorchLM * TORCH_AMOUNT  ;
    
    #if defined IS_LPV_ENABLED && defined MC_GL_EXT_shader_image_load_store
        vec4 lpvSample = SampleLpvLinear(lpvPos);
        vec3 LpvTorchLight = GetLpvBlockLight(lpvSample);

        // i gotchu
        float fadeLength = 10.0; // in blocks
        vec3 cubicRadius = clamp( min(((LpvSize3-1.0) - lpvPos)/fadeLength,      lpvPos/fadeLength) ,0.0,1.0);
        float LpvFadeF = cubicRadius.x*cubicRadius.y*cubicRadius.z;

        LpvFadeF = 1.0 - pow(1.0-pow(LpvFadeF,1.5),3.0); // make it nice and soft :)
        
        TorchLight = mix(TorchLight,LpvTorchLight/5.0,   LpvFadeF);

        const vec3 normal = vec3(0.0); // TODO

        if (heldItemId > 0)
            TorchLight += GetHandLight(heldItemId, playerPos, normal);

        if (heldItemId2 > 0)
            TorchLight += GetHandLight(heldItemId2, playerPos, normal);
    #endif

    return vec4(TorchLight, skyLM);
}