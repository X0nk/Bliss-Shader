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
// #ifdef NETHER_SHADER
//     vec3 DoAmbientLighting_Nether(vec3 FogColor, vec3 TorchColor, float Lightmap, vec3 Normal, vec3 np3, vec3 WorldPos){

//         float TorchLM = 10.0 - ( 1.0 / (pow(exp(-0.5*inversesqrt(Lightmap)),5.0)+0.1));
//         TorchLM = pow(TorchLM/4,10) + pow(Lightmap,1.5)*0.5; //pow(TorchLM/4.5,10)*2.5 + pow(Lightmap.x,1.5)*0.5;
//     	vec3 TorchLight = TorchColor * TorchLM * 0.75;
//         TorchLight *= TORCH_AMOUNT;

//         FogColor = max(FogColor, vec3(0.05) * MIN_LIGHT_AMOUNT*0.01 + nightVision); 

//         return  FogColor + TorchLight ;
//     }
// #endif

// #ifdef END_SHADER
//     vec3 DoAmbientLighting_End(vec3 FogColor, vec3 TorchColor, float Lightmap, vec3 Normal, vec3 np3){

//         float TorchLM = 10.0 - ( 1.0 / (pow(exp(-0.5*inversesqrt(Lightmap)),5.0)+0.1));
//         TorchLM = pow(TorchLM/4,10) + pow(Lightmap,1.5)*0.5; 
//     	vec3 TorchLight = TorchColor * TorchLM * 0.75;
//         TorchLight *= TORCH_AMOUNT;


//         FogColor = FogColor / max(dot(FogColor,vec3(0.3333)),0.05);

//         vec3 FogTint = FogColor*clamp(1.1 + dot(Normal,np3),0.0,1.0) * 0.1;

//         vec3 AmbientLight = max(vec3(0.5,0.75,1.0)* 0.1, (MIN_LIGHT_AMOUNT*0.01 + nightVision*0.5) ); 


//         return TorchLight + AmbientLight;// + AmbientLight + FogTint;
//     }

// #endif

// #ifdef FALLBACK_SHADER
//     vec3 DoAmbientLighting_Fallback(vec3 Color, vec3 TorchColor, float Lightmap, vec3 Normal, vec3 p3){

//         float TorchLM = 10.0 - ( 1.0 / (pow(exp(-0.5*inversesqrt(Lightmap)),5.0)+0.1));
//         TorchLM = pow(TorchLM/4,10) + pow(Lightmap,1.5)*0.5; 
//     	vec3 TorchLight = TorchColor * TorchLM * 0.75;
//         TorchLight *= TORCH_AMOUNT;

//         float NdotL = clamp(-dot(Normal,normalize(p3)),0.0,1.0);

//         float PlayerLight = exp(  (1.0-clamp(1.0 - length(p3) / 32.0,0.0,1.0)) *-10.0);
//         // vec3 AmbientLight = TorchColor * PlayerLight * NdotL; 
//         vec3 AmbientLight = vec3(0.5,0.3,1.0)*0.2 * (Normal.y*0.5+0.6);


//         return TorchLight + AmbientLight;// + AmbientLight + FogTint;
//     }
// #endif