vec3 DoAmbientLightColor(
    vec3 SkyColor, 
    vec3 TorchColor, 
    vec2 Lightmap
){
    
    // do sky lighting.
    float skyLM = (pow(Lightmap.y,15.0)*2.0 + pow(Lightmap.y,2.5))*0.5;
    SkyColor = (SkyColor / 30.0) * ambient_brightness * skyLM;
    vec3 MinimumLight = vec3(0.2,0.4,1.0) * (MIN_LIGHT_AMOUNT*0.01 + nightVision);
    vec3 IndirectLight = max(SkyColor, MinimumLight); 
    
    // do torch lighting.
    float TorchLM = 10.0 - ( 1.0 / (pow(exp(-0.5*inversesqrt(Lightmap.x)),5.0)+0.1));
    TorchLM = pow(TorchLM/4,10) + pow(Lightmap.x,1.5)*0.5;
    
	vec3 TorchLight = TorchColor * TORCH_AMOUNT * TorchLM;
    return IndirectLight + TorchLight;
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