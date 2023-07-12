// in this here file im doing all the lighting for sunlight, ambient light, torches, for solids and translucents.

uniform float nightVision;

//// OVERWORLD ////
#ifdef OVERWORLD
vec3 DoAmbientLighting (vec3 SkyColor, vec3 TorchColor, vec2 Lightmap, float skyLightDir){
    // Lightmap.x = 0.0;
    // Lightmap.y = 1.0;

    float TorchLM = 10.0 - ( 1.0 / (pow(exp(-0.5*inversesqrt(Lightmap.x)),5.0)+0.1));
    TorchLM = pow(TorchLM/4,10) + pow(Lightmap.x,1.5)*0.5; //pow(TorchLM/4.5,10)*2.5 + pow(Lightmap.x,1.5)*0.5;
	vec3 TorchLight = TorchColor * TorchLM * 0.75;
    TorchLight *= TORCH_AMOUNT;

    SkyColor = (SkyColor * ambient_brightness) / 30.0;

    float skyLM = (pow(Lightmap.y,15.0)*2.0 + pow(Lightmap.y,2.5))*0.5;
    vec3 SkyLight = max(SkyColor * skyLM,  vec3(0.2,0.4,1.0) * (MIN_LIGHT_AMOUNT*0.01 + nightVision) ); 

    return   SkyLight * skyLightDir + TorchLight;
}

vec3 DoDirectLighting(vec3 SunColor, float Shadow, float NdotL, float SubsurfaceScattering){

    // vec3 SunLight = max(NdotL * Shadow, SubsurfaceScattering) * SunColor;
    vec3 SunLight = NdotL * Shadow * SunColor;
    
    return SunLight;
}
#endif

#ifdef NETHER
//// NETHER ////
vec3 DoAmbientLighting_Nether(vec3 FogColor, vec3 TorchColor, float Lightmap, vec3 Normal, vec3 np3, vec3 WorldPos){
    
    float TorchLM = 10.0 - ( 1.0 / (pow(exp(-0.5*inversesqrt(Lightmap)),5.0)+0.1));
    TorchLM = pow(TorchLM/4,10) + pow(Lightmap,1.5)*0.5; //pow(TorchLM/4.5,10)*2.5 + pow(Lightmap.x,1.5)*0.5;
	vec3 TorchLight = TorchColor * TorchLM * 0.75;
    TorchLight *= TORCH_AMOUNT;

    vec3 LavaGlow = vec3(TORCH_R,TORCH_G,TORCH_B);
    LavaGlow *= pow(clamp(1.0-max(Normal.y,0.0) + dot(Normal,np3),0.0,1.0),3.0);
	LavaGlow *= clamp(exp2(-max((WorldPos.y - 50.0) / 5,0.0)),0.0,1.0);
    LavaGlow *= pow(Lightmap,0.2);

    vec3 FogTint = FogColor*clamp(1.1 + dot(Normal,np3),0.0,1.0) * 0.05;

    vec3 AmbientLight = max(vec3(0.05), (MIN_LIGHT_AMOUNT*0.01 + nightVision*0.5) ); 

    return  AmbientLight + FogTint + TorchLight + LavaGlow;
}
#endif

#ifdef END
//// END ////
vec3 DoAmbientLighting_End(vec3 FogColor, vec3 TorchColor, float Lightmap, vec3 Normal, vec3 np3){

    // vec3 TorchLight = TorchColor * clamp(pow(Lightmap,3.0),0.0,1.0);
	// vec3 TorchLight = TorchColor * pow(1.0-pow(1.0-clamp(Lightmap,0.0,1.0) ,0.1),2);
    // TorchLight = exp(TorchLight * 30) - 1.0;

    float TorchLM = 10.0 - ( 1.0 / (pow(exp(-0.5*inversesqrt(Lightmap)),5.0)+0.1));
    TorchLM = pow(TorchLM/4,10) + pow(Lightmap,1.5)*0.5; //pow(TorchLM/4.5,10)*2.5 + pow(Lightmap.x,1.5)*0.5;
	vec3 TorchLight = TorchColor * TorchLM * 0.75;
    TorchLight *= TORCH_AMOUNT;


    FogColor =  (FogColor / pow(0.00001 + dot(FogColor,vec3(0.3333)),1.0) ) * 0.1;
    // vec3 AmbientLight =  sqrt( clamp(1.25 + dot(Normal,np3),0.0,1.0)) * (vec3(0.5,0.75,1.0) * 0.05);
    // vec3 AmbientLight =  sqrt( clamp(1.25 + dot(Normal,np3),0.0,1.0)*0.5) * FogColor;
    // vec3 AmbientLight = vec3(0.5,0.75,1.0) * 0.05 + FogColor*clamp(1.1 + dot(Normal,np3),0.0,1.0)*0.5;

    vec3 FogTint = FogColor*clamp(1.1 + dot(Normal,np3),0.0,1.0) * 0.05;
    
    vec3 AmbientLight = max(vec3(0.5,0.75,1.0) * 0.05, (MIN_LIGHT_AMOUNT*0.01 + nightVision*0.5) ); 


    return TorchLight + AmbientLight + FogTint;
}
#endif