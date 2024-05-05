vec3 DoAmbientLightColor(
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

        // TODO: needs work, just binary transition for now
        // float LpvFadeF = clamp(lpvPos, vec3(0.0), LpvSize3 - 1.0) == lpvPos ? 1.0 : 0.0;

        // i gotchu
        float fadeLength = 10.0; // in blocks
        vec3 cubicRadius = clamp(           min(((LpvSize3-1.0) - lpvPos)/fadeLength,      lpvPos/fadeLength)          ,0.0,1.0);
        float LpvFadeF = cubicRadius.x*cubicRadius.y*cubicRadius.z;

        LpvFadeF = 1.0 - pow(1.0-pow(LpvFadeF,1.5),3.0); // make it nice and soft :)
        
        TorchLight = mix(TorchLight,LpvTorchLight/5.0,   LpvFadeF) ;
    #endif

    return IndirectLight + TorchLight * TorchBrightness_autoAdjust;
}

vec4 RT_AmbientLight(
    vec3 TorchColor, 
    vec2 Lightmap
){
    float skyLM = (pow(Lightmap.y,15.0)*2.0 + pow(Lightmap.y,2.5))*0.5;

    float TorchLM = 10.0 - ( 1.0 / (pow(exp(-0.5*inversesqrt(Lightmap.x)),5.0)+0.1));
    TorchLM = pow(TorchLM/4,10) + pow(Lightmap.x,1.5)*0.5;
    vec3 TorchLight = TorchColor * TORCH_AMOUNT * TorchLM;

    return vec4(TorchLight, skyLM);
}