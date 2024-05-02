#version 430 compatibility

#define RENDER_SETUP

#include "/lib/settings.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const ivec3 workGroups = ivec3(4, 5, 1);

#ifdef IS_LPV_ENABLED
    #include "/lib/blocks.glsl"
    #include "/lib/lpv_blocks.glsl"
#endif


void main() {
    #ifdef IS_LPV_ENABLED
        uint blockId = uint(gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * 32);
        //if (blockId >= 1280) return;

        vec3 lightColor = vec3(0.0);
        float lightRange = 0.0;
        float mixWeight = 0.0;
        uint mixMask = 0xFFFF;

        switch (blockId) {
            case BLOCK_GLOWSTONE:
                lightColor = vec3(0.8, 0.7, 0.1);
                lightRange = 15.0;
                break;
            case BLOCK_REDSTONE_TORCH:
                lightColor = vec3(1.0, 0.1, 0.1);
                lightRange = 7.0;
                break;
            case BLOCK_SEA_LANTERN:
                lightColor = vec3(1.0);
                lightRange = 15.0;
                break;
            case BLOCK_SOUL_TORCH:
                lightColor = vec3(0.1, 0.6, 1.0);
                lightRange = 10.0;
                break;
            case BLOCK_TORCH:
                lightColor = vec3(1.0, 0.6, 0.1);
                lightRange = 14.0;
                break;
        }

        LpvBlockData block;
        block.data = BuildBlockLpvData(mixMask, mixWeight);
        block.LightColor = packUnorm4x8(vec4(lightColor, 0.0));
        block.LightRangeSize = packUnorm4x8(vec4(lightRange/255.0, 0.0, 0.0, 0.0));

        LpvBlockMap[blockId] = block;
    #endif
}
