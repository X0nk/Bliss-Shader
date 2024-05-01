#version 430 compatibility

#define RENDER_SETUP

#include "/lib/settings.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const ivec3 workGroups = ivec3(4, 5, 1);

#ifdef IS_LPV_ENABLED
    #include "/lib/lpv_blocks.glsl"


    vec3 GetSceneLightColor(const in uint blockId) {
        if (blockId == 10005) return vec3(1.0);
        return vec3(0.0);
    }

    float GetSceneLightRange(const in uint blockId) {
        if (blockId == 10005) return 12.0;
        return 0.0;
    }

    void GetLpvBlockMask(const in uint blockId, out float mixWeight, out uint mixMask) {
        mixWeight = 0.0;
        mixMask = 0xFFFF;
    }
#endif


void main() {
    #ifdef IS_LPV_ENABLED
        uint blockId = uint(gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * 32);
        //if (blockId >= 1280) return;

        LpvBlockData block;

        uint mixMask;
        float mixWeight;
        GetLpvBlockMask(blockId, mixWeight, mixMask);
        block.data = BuildBlockLpvData(mixMask, mixWeight);

        // vec3 lightOffset = GetSceneLightOffset(lightType);
        vec3 lightColor = GetSceneLightColor(blockId);
        float lightRange = GetSceneLightRange(blockId);
        float lightSize = 0.0;//GetSceneLightSize(lightType);
        // bool lightTraced = GetLightTraced(lightType);
        // bool lightSelfTraced = GetLightSelfTraced(lightType);

        // light.Offset = packSnorm4x8(vec4(lightOffset, 0.0));
        block.LightColor = packUnorm4x8(vec4(lightColor, 0.0));
        block.LightRangeSize = packUnorm4x8(vec4(lightRange/255.0, lightSize, 0.0, 0.0));
        // light.LightMetadata = (lightTraced ? 1u : 0u);
        // light.LightMetadata |= (lightSelfTraced ? 1u : 0u) << 1u;

        LpvBlockMap[blockId] = block;
    #endif
}
