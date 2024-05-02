#version 430 compatibility

#define RENDER_SETUP

#include "/lib/settings.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const ivec3 workGroups = ivec3(4, 5, 1);

#ifdef IS_LPV_ENABLED
    #include "/lib/blocks.glsl"
    #include "/lib/lpv_blocks.glsl"
#endif

const vec3 LightColor_SeaPickle = vec3(0.283, 0.394, 0.212);


void main() {
    #ifdef IS_LPV_ENABLED
        uint blockId = uint(gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * 32 + LpvBlockMapOffset);
        //if (blockId >= 1280) return;

        vec3 lightColor = vec3(0.0);
        float lightRange = 0.0;
        float mixWeight = 0.0;
        uint mixMask = 0xFFFF;

        switch (blockId) {
            case BLOCK_BEACON:
                lightColor = vec3(1.0);
                lightRange = 15.0;
                break;
            case BLOCK_CAVE_VINE_BERRIES:
                lightColor = vec3(0.717, 0.541, 0.188);
                lightRange = 14.0;
                break;
            case BLOCK_CONDUIT:
                lightColor = vec3(1.0);
                lightRange = 15.0;
                break;
            case BLOCK_END_GATEWAY:
                lightColor = vec3(1.0);
                lightRange = 15.0;
                break;
            case BLOCK_END_ROD:
                lightColor = vec3(0.957, 0.929, 0.875);
                lightRange = 14.0;
                break;
            case BLOCK_FIRE:
                lightColor = vec3(0.864, 0.598, 0.348);
                lightRange = 15.0;
                break;
            case BLOCK_FROGLIGHT_OCHRE:
                lightColor = vec3(0.768, 0.648, 0.108);
                lightRange = 15.0;
                break;
            case BLOCK_FROGLIGHT_PEARLESCENT:
                lightColor = vec3(0.737, 0.435, 0.658);
                lightRange = 15.0;
                break;
            case BLOCK_FROGLIGHT_VERDANT:
                lightColor = vec3(0.463, 0.763, 0.409);
                lightRange = 15.0;
                break;
            case BLOCK_GLOWSTONE:
                lightColor = vec3(0.747, 0.594, 0.326);
                lightRange = 15.0;
                break;
            case BLOCK_JACK_O_LANTERN:
                lightColor = vec3(1.0, 0.7, 0.1);
                lightRange = 15.0;
                break;
            case BLOCK_LANTERN:
                lightColor = vec3(1.0, 0.7, 0.1);
                lightRange = 15.0;
                break;
            case BLOCK_LAVA:
                lightColor = vec3(0.804, 0.424, 0.149);
                lightRange = 15.0;
                break;
            case BLOCK_MAGMA:
                lightColor = vec3(0.747, 0.323, 0.110);
                lightRange = 3.0;
                break;
            case BLOCK_REDSTONE_LAMP_LIT:
                lightColor = vec3(0.953, 0.796, 0.496);
                lightRange = 15.0;
                break;
            case BLOCK_REDSTONE_TORCH_LIT:
                lightColor = vec3(0.939, 0.305, 0.164);
                lightRange = 7.0;
                break;
            case BLOCK_RESPAWN_ANCHOR_4:
                lightColor = vec3(1.0, 0.2, 1.0);
                lightRange = 15.0;
                break;
            case BLOCK_SCULK_SENSOR_ACTIVE:
                lightColor = vec3(0.1, 0.4, 1.0);
                lightRange = 1.0;
                break;
            case BLOCK_SEA_PICKLE_WET_1:
                lightColor = LightColor_SeaPickle;
                lightRange = 6.0;
                break;
            case BLOCK_SEA_PICKLE_WET_2:
                lightColor = LightColor_SeaPickle;
                lightRange = 9.0;
                break;
            case BLOCK_SEA_PICKLE_WET_3:
                lightColor = LightColor_SeaPickle;
                lightRange = 12.0;
                break;
            case BLOCK_SEA_PICKLE_WET_4:
                lightColor = LightColor_SeaPickle;
                lightRange = 15.0;
                break;
            case BLOCK_SEA_LANTERN:
                lightColor = vec3(0.553, 0.748, 0.859);
                lightRange = 15.0;
                break;
            case BLOCK_SHROOMLIGHT:
                lightColor = vec3(0.848, 0.469, 0.205);
                lightRange = 15.0;
                break;
            case BLOCK_SMOKER_LIT:
                lightColor = vec3(0.8, 0.7, 0.1);
                lightRange = 13.0;
                break;
            case BLOCK_SOUL_FIRE:
            case BLOCK_SOUL_LANTERN:
            case BLOCK_SOUL_TORCH:
                lightColor = vec3(0.1, 0.6, 1.0);
                lightRange = 10.0;
                break;
            case BLOCK_TORCH:
                lightColor = vec3(1.0, 0.6, 0.1);
                lightRange = 14.0;
                break;


            case BLOCK_NETHER_PORTAL:
                lightColor = vec3(0.502, 0.165, 0.831);
                lightRange = 11.0;
                break;
        }

        LpvBlockData block;
        block.ColorRange = packUnorm4x8(vec4(lightColor, lightRange/255.0));
        block.MaskWeight = BuildBlockLpvData(mixMask, mixWeight);
        LpvBlockMap[blockId - LpvBlockMapOffset] = block;
    #endif
}
