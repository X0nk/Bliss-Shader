// #ifdef IS_LPV_ENABLED
//     vec3 GetHandLight(const in int itemId, const in vec3 playerPos, const in vec3 normal) {
//         vec3 lightFinal = vec3(0.0);
//         vec3 lightColor = vec3(0.0);
//         float lightRange = 0.0;

//         uvec2 blockData = texelFetch(texBlockData, itemId, 0).rg;
//         vec4 lightColorRange = unpackUnorm4x8(blockData.r);
//         lightColor = srgbToLinear(lightColorRange.rgb);
//         lightRange = lightColorRange.a * 255.0;

//         // if (lightRange > 0.0) {
//         //     float lightDist = length(playerPos);
//         //     vec3 lightDir = playerPos / lightDist;
//         //     float NoL = 1.0;//max(dot(normal, lightDir), 0.0);
//         //     float falloff = pow(1.0 - lightDist / lightRange, 3.0);
//         //     lightFinal = lightColor * NoL * max(falloff, 0.0);
//         // }

//         return lightColor;
//     }
// #endif

vec3 doBlockLightLighting(
    vec3 lightColor, float lightmap,
    vec3 playerPos, vec3 lpvPos
){
    lightmap = clamp(lightmap,0.0,1.0);

    float lightmapBrightspot = min(max(lightmap-0.7,0.0)*3.3333,1.0);
    lightmapBrightspot *= lightmapBrightspot*lightmapBrightspot;

    float lightmapLight = 1.0-sqrt(1.0-lightmap);
    lightmapLight *= lightmapLight;

    float lightmapCurve = mix(lightmapLight, 2.5, lightmapBrightspot);
    // lightmapCurve = lightmap;
    vec3 blockLight = lightmapCurve * lightColor;
    
    #if defined IS_LPV_ENABLED && defined MC_GL_ARB_shader_image_load_store
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
        blockLight = mix(blockLight, lpvSample.rgb + lightColor * 2.5 * min(max(lightmap-0.999,0.0)/(1.0-0.999),1.0), voxelRangeFalloff);
    #endif

    return blockLight * TORCH_AMOUNT;
}

vec3 doIndirectLighting(
    vec3 lightColor, vec3 minimumLightColor, float lightmap
){

    // float lightmapCurve = pow(1.0-pow(1.0-lightmap,2.0),2.0);
    // float lightmapCurve = lightmap*lightmap;
    float lightmapCurve = (pow(lightmap,15.0)*2.0 + lightmap*lightmap)/3.0; //make sure its 0.0-1.0
    // lightmapCurve = lightmap;
    vec3 indirectLight = lightColor * lightmapCurve * ambient_brightness; 

    // indirectLight = max(indirectLight, minimumLightColor * (MIN_LIGHT_AMOUNT * 0.02 * 0.2 + nightVision));
    // indirectLight += minimumLightColor * (MIN_LIGHT_AMOUNT * 0.02 * 0.2 + nightVision*0.02);
    
    float minimumLightAmount = 0.02*nightVision + 0.005 * mix(MINIMUM_INDOOR_LIGHT, MINIMUM_OUTDOOR_LIGHT, clamp(eyeBrightnessSmooth.y/240.0 + lightmap,0.0,1.0));
    
    indirectLight += minimumLightColor * minimumLightAmount;
    
    return indirectLight;
}

// uniform int heldItemId;
// uniform int heldItemId2;
// uniform float centerDepthSmooth;
// uniform vec3 eyePosition;
uniform vec3 relativeEyePosition;
uniform vec3 playerLookVector;
uniform bool firstPersonCamera;

#if defined VIVECRAFT
	uniform bool vivecraftIsVR;
	uniform vec3 vivecraftRelativeMainHandPos;
	uniform vec3 vivecraftRelativeOffHandPos;
	uniform mat4 vivecraftRelativeMainHandRot;
	uniform mat4 vivecraftRelativeOffHandRot;
#endif

#ifdef IS_LPV_ENABLED
    vec4 getHandheldLightData(int ID){

        uvec2 blockData = texelFetch(texBlockData, ID, 0).rg;
        vec4 lightColorRange = unpackUnorm4x8(blockData.r);
        vec3 lightColor = srgbToLinear(lightColorRange.rgb);
        float lightRange = lightColorRange.a * 255.0;

        return vec4(lightColor, lightRange);
    }
#endif

float createHandheldPointLightFalloff(in float linearDistance, in float range){
    
    // float gradient = 1.0 - clamp(linearDistance/range, 0.0, 1.0);
    float gradient = 1.0 - clamp(1.0 - linearDistance/range, -0.999,1.0);
    gradient = max(exp(-10.0 * gradient),0.0);

    return gradient;
}

float createHandheldPointlight(in vec3 position, in vec3 normal, in float range){

    float NdotL = clamp(dot(-normal, normalize(position)),0.0,1.0);
    
    float falloff = createHandheldPointLightFalloff(length(position), range);
    
    return NdotL * falloff;
}

void calculateFinishedPointLight(
    in vec3 viewPos, in vec3 normal, 

    float lightLevel, int heldItemId, vec3 handOffset, 

    inout vec3 handPos, inout vec3 lighting
){
    
    if(lightLevel > 1e-6){
        // in third person, mirror positions when backfacing third person is used.
        float headViewDir = max((mat3(gbufferModelView) * playerLookVector).z,0);
        viewPos.z -= headViewDir;
        handOffset.x *= mix(1.0,-1.0,headViewDir);

        // offset viewPos to match hand position
        handPos = mat3(gbufferModelViewInverse) * (viewPos + handOffset) + gbufferModelViewInverse[3].xyz;
        
        // make sure the position is centered on the player, not the camera.
        if(!firstPersonCamera) handPos += relativeEyePosition;
        
        #if HANDHELD_LIGHTSOURCE_MODE > 1
            /// previous frame data to lag the light behind to seem handheld.
            handPos -= (cameraPosition-previousCameraPosition)*3.0;
        #endif
        
        // get color and stuff
        #ifdef IS_LPV_ENABLED
            vec4 sampledLightColor = getHandheldLightData(heldItemId);
            lighting = sampledLightColor.rgb;
            float lightRange = sampledLightColor.a;
            
            // ensure that there is color if no light item is held. or if the light item is not listed.
            #if HANDHELD_LIGHTSOURCE_MODE == 3
                if(heldItemId < 1){
                    lighting = vec3(HANDHELD_LIGHTSOURCE_R, HANDHELD_LIGHTSOURCE_G, HANDHELD_LIGHTSOURCE_B);
                    lightRange = 15.0;
                }
            #else
                if(heldItemId < 1){
                    lighting = vec3(HANDHELD_LIGHTSOURCE_R, HANDHELD_LIGHTSOURCE_G, HANDHELD_LIGHTSOURCE_B);
                    lightRange = lightLevel;
                    lighting *= lightRange/15.0;
                }
            #endif
        #else
            lighting = vec3(HANDHELD_LIGHTSOURCE_R, HANDHELD_LIGHTSOURCE_G, HANDHELD_LIGHTSOURCE_B);
            float lightRange = lightLevel;
            lighting *= lightRange/15.0;
        #endif

        #if HANDHELD_LIGHTSOURCE_RANGE > 0
            lightRange = float(HANDHELD_LIGHTSOURCE_RANGE);
        #endif
        
        // combine ndotl, attentuation, color, and pass it on.
        lighting *= createHandheldPointlight(handPos, normal, max(lightRange + 2,1e-6));
        
        #if HANDHELD_LIGHTSOURCE_MODE > 1
            /// previous frame data to lag the light behind to seem handheld.
            vec3 prevPos = mat3(gbufferPreviousModelView) * handPos + gbufferPreviousModelView[3].xyz;
            // project outwards from the camera to get that zooming out effect.
            vec2 scaledViewPos = prevPos.xy / max(-prevPos.z - 0.0, 1e-7);
            float scaledLinearDistance = length(scaledViewPos);

            // create projected pattern
    	    float projectedCircle = clamp(1.0 - scaledLinearDistance*FLASHLIGHT_SIZE,0.0,1.0);
    	    float lenseDirt = texture(noisetex, scaledViewPos * 0.2 + 0.1).b;
    	    float lenseShape = (pow(abs(pow(abs(projectedCircle-1.0),2.0)*2.0 - 0.5),2.0) + lenseDirt*0.2) * 10.0;

            // for fake indirect bounce. makes the flashlight more usable.
            float bounce = clamp(1.0 - length(handPos)/max(lightRange,16), 0.0,1.0);

            // mask to point light
    	    lighting *= pow(1.0-pow(1.0-projectedCircle,2),2) * lenseShape * FLASHLIGHT_BRIGHTNESS_MULT + bounce*0.005;

            //#if defined FLASHLIGHT_SPECULAR && (defined DEFERRED_SPECULAR || defined FORWARD_SPECULAR)
            //  float flashLightSpecular = lightFalloff * exp2(-7.0*shiftedLinearDistance*shiftedLinearDistance) * FLASHLIGHT_BRIGHTNESS_MULT;
            //  flashLightSpecularData = vec4(normalize(shiftedPlayerPos), flashLightSpecular);	
            //#endif

    	    //#ifdef FLASHLIGHT_BOUNCED_INDIRECT
    	    //  float lightWidth = 1.0+linearDistance*3.0;
    	    //  vec3 pointPos = mat3(gbufferModelViewInverse) * (toScreenSpace(vec3(texcoord, centerDepthSmooth)) + vec3(-0.25, 0.2, 0.0));
    	    //  float flashLightHitPoint = distance(pointPos, shiftedPlayerPos);
    	    //  float indirectFlashLight = exp(-10.0 * (1.0 - clamp(1.0-length(shiftedViewPos.xy)/lightWidth,0.0,1.0)) );
    	    //  indirectFlashLight *= pow(clamp(1.0-flashLightHitPoint/lightWidth,0,1),2.0);
    	    //  flashlightDiffuse += albedo/150.0 * indirectFlashLight * lightFalloff;
    	    //#endif
        #endif
    }
}

void doHandHeldLight(
    in vec3 viewPos, in vec3 normal
    ,inout vec3 passMainHandPos, inout vec3 passMainHandCol, inout vec3 passOffHandPos, inout vec3 passOffHandCol 
){

    #if HANDHELD_LIGHTSOURCE_MODE == 3
        calculateFinishedPointLight(viewPos, normal, 16.0, heldItemId, vec3(-0.25, 0.1-playerLookVector.y*0.2, 0.1), passMainHandPos, passMainHandCol);
    #else
        calculateFinishedPointLight(viewPos, normal, float(heldBlockLightValue), heldItemId, vec3(-0.25, 0.1-playerLookVector.y*0.2, 0.1), passMainHandPos, passMainHandCol);
        calculateFinishedPointLight(viewPos, normal, float(heldBlockLightValue2), heldItemId2, vec3( 0.25, 0.1-playerLookVector.y*0.2, 0.1), passOffHandPos, passOffHandCol);
    #endif

    passMainHandCol *= HANDHELD_LIGHTSOURCE_BRIGHTNESS;
    passOffHandCol *= HANDHELD_LIGHTSOURCE_BRIGHTNESS;
}