layout (local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const ivec3 workGroups = ivec3(6, 6, 1);

#ifdef IS_LPV_ENABLED
    #include "/lib/blocks.glsl"
    #include "/lib/lpv_blocks.glsl"

    const vec3 LightColor_Amethyst = vec3(0.464, 0.227, 0.788);
    const vec3 LightColor_Candles = vec3(1.0, 0.4, 0.1);
    const vec3 LightColor_CopperBulb = vec3(1.0);
    const vec3 LightColor_LightBlock = vec3(1.0);
    const vec3 LightColor_RedstoneTorch = vec3(0.939, 0.305, 0.164);
    const vec3 LightColor_SeaPickle = vec3(0.283, 0.394, 0.212);

    #ifdef LPV_COLORED_CANDLES
        const vec3 LightColor_Candles_Black = vec3(0.200);
        const vec3 LightColor_Candles_Blue = vec3(0.000, 0.259, 1.000);
        const vec3 LightColor_Candles_Brown = vec3(0.459, 0.263, 0.149);
        const vec3 LightColor_Candles_Cyan = vec3(0.000, 0.839, 0.839);
        const vec3 LightColor_Candles_Gray = vec3(0.329, 0.357, 0.388);
        const vec3 LightColor_Candles_Green = vec3(0.263, 0.451, 0.000);
        const vec3 LightColor_Candles_LightBlue = vec3(0.153, 0.686, 1.000);
        const vec3 LightColor_Candles_LightGray = vec3(0.631, 0.627, 0.624);
        const vec3 LightColor_Candles_Lime = vec3(0.439, 0.890, 0.000);
        const vec3 LightColor_Candles_Magenta = vec3(0.757, 0.098, 0.812);
        const vec3 LightColor_Candles_Orange = vec3(1.000, 0.459, 0.000);
        const vec3 LightColor_Candles_Pink = vec3(1.000, 0.553, 0.718);
        const vec3 LightColor_Candles_Purple = vec3(0.569, 0.000, 1.000);
        const vec3 LightColor_Candles_Red = vec3(0.859, 0.000, 0.000);
        const vec3 LightColor_Candles_White = vec3(1.000);
        const vec3 LightColor_Candles_Yellow = vec3(1.000, 0.878, 0.000);
    #endif

    uint BuildLpvMask(const in uint north, const in uint east, const in uint south, const in uint west, const in uint up, const in uint down) {
        return east | (west << 1) | (down << 2) | (up << 3) | (south << 4) | (north << 5);
    }
#endif


void main() {
    #ifdef IS_LPV_ENABLED
        uint blockId = uint(gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * 32);
        if (blockId >= 2000) return;

        vec3 lightColor = vec3(0.0);
        float lightRange = 0.0;
        float mixWeight = 0.0;
        uint mixMask = 0xFFFF;
        vec3 tintColor = vec3(1.0);

        switch (blockId) {
            case BLOCK_WATER:
                mixWeight = 0.8;
                break;

            case BLOCK_BAMBOO:
                mixWeight = 0.8;
                break;

            case BLOCK_GRASS_SHORT:
            case BLOCK_GRASS_TALL_UPPER:
            case BLOCK_GRASS_TALL_LOWER:
                mixWeight = 0.85;
                break;

            case BLOCK_GROUND_WAVING:
            case BLOCK_GROUND_WAVING_VERTICAL:
            case BLOCK_AIR_WAVING:
                mixWeight = 0.9;
                break;

            case BLOCK_SAPLING:
                mixWeight = 0.9;
                break;

        // lightsources

            case BLOCK_AMETHYST_BUD_LARGE:
                lightColor = LightColor_Amethyst;
                lightRange = 4.0;
                mixWeight = 0.6;
                break;
            case BLOCK_AMETHYST_BUD_MEDIUM:
                lightColor = LightColor_Amethyst;
                lightRange = 2.0;
                mixWeight = 0.8;
                break;
            case BLOCK_AMETHYST_CLUSTER:
                lightColor = LightColor_Amethyst;
                lightRange = 5.0;
                mixWeight = 0.4;
                break;
            case BLOCK_BEACON:
                lightColor = vec3(1.0);
                lightRange = 15.0;
                break;
            case BLOCK_BREWING_STAND:
                lightColor = vec3(0.636, 0.509, 0.179);
                lightRange = 1.0;
                mixWeight = 0.8;
                break;

        #ifdef LPV_COLORED_CANDLES
            case BLOCK_CANDLES_PLAIN_LIT_1:
                lightColor = LightColor_Candles;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_PLAIN_LIT_2:
                lightColor = LightColor_Candles;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_PLAIN_LIT_3:
                lightColor = LightColor_Candles;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_PLAIN_LIT_4:
                lightColor = LightColor_Candles;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_BLACK_LIT_1:
                lightColor = LightColor_Candles_Black;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_BLACK_LIT_2:
                lightColor = LightColor_Candles_Black;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_BLACK_LIT_3:
                lightColor = LightColor_Candles_Black;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_BLACK_LIT_4:
                lightColor = LightColor_Candles_Black;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_BLUE_LIT_1:
                lightColor = LightColor_Candles_Blue;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_BLUE_LIT_2:
                lightColor = LightColor_Candles_Blue;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_BLUE_LIT_3:
                lightColor = LightColor_Candles_Blue;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_BLUE_LIT_4:
                lightColor = LightColor_Candles_Blue;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_BROWN_LIT_1:
                lightColor = LightColor_Candles_Brown;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_BROWN_LIT_2:
                lightColor = LightColor_Candles_Brown;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_BROWN_LIT_3:
                lightColor = LightColor_Candles_Brown;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_BROWN_LIT_4:
                lightColor = LightColor_Candles_Brown;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_CYAN_LIT_1:
                lightColor = LightColor_Candles_Cyan;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_CYAN_LIT_2:
                lightColor = LightColor_Candles_Cyan;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_CYAN_LIT_3:
                lightColor = LightColor_Candles_Cyan;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_CYAN_LIT_4:
                lightColor = LightColor_Candles_Cyan;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_GRAY_LIT_1:
                lightColor = LightColor_Candles_Gray;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_GRAY_LIT_2:
                lightColor = LightColor_Candles_Gray;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_GRAY_LIT_3:
                lightColor = LightColor_Candles_Gray;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_GRAY_LIT_4:
                lightColor = LightColor_Candles_Gray;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_GREEN_LIT_1:
                lightColor = LightColor_Candles_Green;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_GREEN_LIT_2:
                lightColor = LightColor_Candles_Green;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_GREEN_LIT_3:
                lightColor = LightColor_Candles_Green;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_GREEN_LIT_4:
                lightColor = LightColor_Candles_Green;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_LIGHT_BLUE_LIT_1:
                lightColor = LightColor_Candles_LightBlue;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIGHT_BLUE_LIT_2:
                lightColor = LightColor_Candles_LightBlue;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIGHT_BLUE_LIT_3:
                lightColor = LightColor_Candles_LightBlue;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIGHT_BLUE_LIT_4:
                lightColor = LightColor_Candles_LightBlue;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_LIGHT_GRAY_LIT_1:
                lightColor = LightColor_Candles_LightGray;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIGHT_GRAY_LIT_2:
                lightColor = LightColor_Candles_LightGray;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIGHT_GRAY_LIT_3:
                lightColor = LightColor_Candles_LightGray;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIGHT_GRAY_LIT_4:
                lightColor = LightColor_Candles_LightGray;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_LIME_LIT_1:
                lightColor = LightColor_Candles_Lime;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIME_LIT_2:
                lightColor = LightColor_Candles_Lime;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIME_LIT_3:
                lightColor = LightColor_Candles_Lime;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIME_LIT_4:
                lightColor = LightColor_Candles_Lime;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_MAGENTA_LIT_1:
                lightColor = LightColor_Candles_Magenta;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_MAGENTA_LIT_2:
                lightColor = LightColor_Candles_Magenta;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_MAGENTA_LIT_3:
                lightColor = LightColor_Candles_Magenta;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_MAGENTA_LIT_4:
                lightColor = LightColor_Candles_Magenta;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_ORANGE_LIT_1:
                lightColor = LightColor_Candles_Orange;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_ORANGE_LIT_2:
                lightColor = LightColor_Candles_Orange;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_ORANGE_LIT_3:
                lightColor = LightColor_Candles_Orange;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_ORANGE_LIT_4:
                lightColor = LightColor_Candles_Orange;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_PINK_LIT_1:
                lightColor = LightColor_Candles_Pink;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_PINK_LIT_2:
                lightColor = LightColor_Candles_Pink;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_PINK_LIT_3:
                lightColor = LightColor_Candles_Pink;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_PINK_LIT_4:
                lightColor = LightColor_Candles_Pink;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_PURPLE_LIT_1:
                lightColor = LightColor_Candles_Purple;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_PURPLE_LIT_2:
                lightColor = LightColor_Candles_Purple;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_PURPLE_LIT_3:
                lightColor = LightColor_Candles_Purple;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_PURPLE_LIT_4:
                lightColor = LightColor_Candles_Purple;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_RED_LIT_1:
                lightColor = LightColor_Candles_Red;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_RED_LIT_2:
                lightColor = LightColor_Candles_Red;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_RED_LIT_3:
                lightColor = LightColor_Candles_Red;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_RED_LIT_4:
                lightColor = LightColor_Candles_Red;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_WHITE_LIT_1:
                lightColor = LightColor_Candles_White;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_WHITE_LIT_2:
                lightColor = LightColor_Candles_White;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_WHITE_LIT_3:
                lightColor = LightColor_Candles_White;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_WHITE_LIT_4:
                lightColor = LightColor_Candles_White;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;

            case BLOCK_CANDLES_YELLOW_LIT_1:
                lightColor = LightColor_Candles_Yellow;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_YELLOW_LIT_2:
                lightColor = LightColor_Candles_Yellow;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_YELLOW_LIT_3:
                lightColor = LightColor_Candles_Yellow;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_YELLOW_LIT_4:
                lightColor = LightColor_Candles_Yellow;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;
        #else
            case BLOCK_CANDLES_LIT_1:
                lightColor = LightColor_Candles;
                lightRange = 3.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIT_2:
                lightColor = LightColor_Candles;
                lightRange = 6.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIT_3:
                lightColor = LightColor_Candles;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_CANDLES_LIT_4:
                lightColor = LightColor_Candles;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;
        #endif

            case BLOCK_CAVE_VINE_BERRIES:
                lightColor = vec3(0.651, 0.369, 0.157);
                lightRange = 14.0;
                mixWeight = 1.0;
                break;

        #ifdef LPV_REDSTONE_LIGHTS
            case BLOCK_COMPARATOR_LIT:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 4.0;
                break;
        #endif

            case BLOCK_COPPER_BULB_LIT:
                lightColor = LightColor_CopperBulb;
                lightRange = 15.0;
                break;
            case BLOCK_COPPER_BULB_EXPOSED_LIT:
                lightColor = LightColor_CopperBulb;
                lightRange = 12.0;
                break;
            case BLOCK_COPPER_BULB_OXIDIZED_LIT:
                lightColor = LightColor_CopperBulb;
                lightRange = 4.0;
                break;
            case BLOCK_COPPER_BULB_WEATHERED_LIT:
                lightColor = LightColor_CopperBulb;
                lightRange = 8.0;
                break;
            case BLOCK_CONDUIT:
                lightColor = vec3(1.0);
                lightRange = 15.0;
                break;
            case BLOCK_CRYING_OBSIDIAN:
                lightColor = vec3(0.390, 0.065, 0.646);
                lightRange = 10.0;
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
                mixWeight = 1.0;
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
            case BLOCK_GLOW_LICHEN:
                lightColor = vec3(0.092, 0.217, 0.126);
                lightRange = 7.0;
                break;
            case BLOCK_GLOWSTONE:
                lightColor = vec3(0.747, 0.594, 0.326);
                lightRange = 15.0;
                break;
            case BLOCK_JACK_O_LANTERN:
                lightColor = vec3(0.864, 0.598, 0.348);
                lightRange = 15.0;
                break;
            case BLOCK_LANTERN:
                lightColor = vec3(0.839, 0.541, 0.2);
                lightRange = 15.0;
                mixWeight = 0.8;
                break;
            case BLOCK_LAVA:
                lightColor = vec3(0.659, 0.302, 0.106);
                lightRange = 15.0;
                break;

            case BLOCK_LIGHT_1:
                lightColor = LightColor_LightBlock;
                lightRange = 1;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_2:
                lightColor = LightColor_LightBlock;
                lightRange = 2;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_3:
                lightColor = LightColor_LightBlock;
                lightRange = 3;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_4:
                lightColor = LightColor_LightBlock;
                lightRange = 4;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_5:
                lightColor = LightColor_LightBlock;
                lightRange = 5;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_6:
                lightColor = LightColor_LightBlock;
                lightRange = 6;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_7:
                lightColor = LightColor_LightBlock;
                lightRange = 7;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_8:
                lightColor = LightColor_LightBlock;
                lightRange = 8;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_9:
                lightColor = LightColor_LightBlock;
                lightRange = 9;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_10:
                lightColor = LightColor_LightBlock;
                lightRange = 10;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_11:
                lightColor = LightColor_LightBlock;
                lightRange = 11;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_12:
                lightColor = LightColor_LightBlock;
                lightRange = 12;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_13:
                lightColor = LightColor_LightBlock;
                lightRange = 13;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_14:
                lightColor = LightColor_LightBlock;
                lightRange = 14;
                mixWeight = 1.0;
                break;
            case BLOCK_LIGHT_15:
                lightColor = LightColor_LightBlock;
                lightRange = 15;
                mixWeight = 1.0;
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
                lightColor = LightColor_RedstoneTorch;
                lightRange = 7.0;
                break;

        #ifdef LPV_REDSTONE_LIGHTS
            case BLOCK_REDSTONE_WIRE_1:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 0.5;
                break;
            case BLOCK_REDSTONE_WIRE_2:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 1.0;
                break;
            case BLOCK_REDSTONE_WIRE_3:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 1.5;
                break;
            case BLOCK_REDSTONE_WIRE_4:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 2.0;
                break;
            case BLOCK_REDSTONE_WIRE_5:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 2.5;
                break;
            case BLOCK_REDSTONE_WIRE_6:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 3.0;
                break;
            case BLOCK_REDSTONE_WIRE_7:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 3.5;
                break;
            case BLOCK_REDSTONE_WIRE_8:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 4.0;
                break;
            case BLOCK_REDSTONE_WIRE_9:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 4.5;
                break;
            case BLOCK_REDSTONE_WIRE_10:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 5.0;
                break;
            case BLOCK_REDSTONE_WIRE_11:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 5.5;
                break;
            case BLOCK_REDSTONE_WIRE_12:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 6.0;
                break;
            case BLOCK_REDSTONE_WIRE_13:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 6.5;
                break;
            case BLOCK_REDSTONE_WIRE_14:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 7.0;
                break;
            case BLOCK_REDSTONE_WIRE_15:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 7.5;
                break;

            case BLOCK_REPEATER_LIT:
                lightColor = LightColor_RedstoneTorch;
                lightRange = 4.0;
                break;
        #endif

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
                mixWeight = 1.0;
                break;
            case BLOCK_SEA_PICKLE_WET_2:
                lightColor = LightColor_SeaPickle;
                lightRange = 9.0;
                mixWeight = 1.0;
                break;
            case BLOCK_SEA_PICKLE_WET_3:
                lightColor = LightColor_SeaPickle;
                lightRange = 12.0;
                mixWeight = 1.0;
                break;
            case BLOCK_SEA_PICKLE_WET_4:
                lightColor = LightColor_SeaPickle;
                lightRange = 15.0;
                mixWeight = 1.0;
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
                lightColor = vec3(0.1, 0.6, 1.0);
                lightRange = 10.0;
                mixWeight = 1.0;
                break;
            case BLOCK_SOUL_LANTERN:
            case BLOCK_SOUL_TORCH:
                lightColor = vec3(0.1, 0.6, 1.0);
                lightRange = 10.0;
                mixWeight = 0.8;
                break;
            case BLOCK_TORCH:
                lightColor = vec3(1.0, 0.6, 0.1);
                lightRange = 14.0;
                mixWeight = 0.8;
                break;

        // reflective translucents / glass

            case BLOCK_HONEY:
                tintColor = vec3(0.984, 0.733, 0.251);
                mixWeight = 1.0;
                break;
            case BLOCK_NETHER_PORTAL:
                lightColor = vec3(0.502, 0.165, 0.831);
                tintColor = vec3(0.502, 0.165, 0.831);
                lightRange = 11.0;
                mixWeight = 1.0;
                break;
            case BLOCK_SLIME:
                tintColor = vec3(0.408, 0.725, 0.329);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_BLACK:
                tintColor = vec3(0.3);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_BLUE:
                tintColor = vec3(0.1, 0.1, 0.98);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_BROWN:
                tintColor = vec3(0.566, 0.388, 0.148);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_CYAN:
                tintColor = vec3(0.082, 0.533, 0.763);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_GRAY:
                tintColor = vec3(0.4, 0.4, 0.4);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_GREEN:
                tintColor = vec3(0.125, 0.808, 0.081);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_LIGHT_BLUE:
                tintColor = vec3(0.320, 0.685, 0.955);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_LIGHT_GRAY:
                tintColor = vec3(0.7);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_LIME:
                tintColor = vec3(0.633, 0.924, 0.124);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_MAGENTA:
                tintColor = vec3(0.698, 0.298, 0.847);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_ORANGE:
                tintColor = vec3(0.919, 0.586, 0.185);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_PINK:
                tintColor = vec3(0.949, 0.274, 0.497);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_PURPLE:
                tintColor = vec3(0.578, 0.170, 0.904);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_RED:
                tintColor = vec3(0.999, 0.188, 0.188);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_WHITE:
                tintColor = vec3(0.96, 0.96, 0.96);
                mixWeight = 1.0;
                break;
            case BLOCK_GLASS_YELLOW:
                tintColor = vec3(0.965, 0.965, 0.123);
                mixWeight = 1.0;
                break;

        // LPV shapes

            case BLOCK_LPV_IGNORE:
                mixWeight = 1.0;
                break;

            case BLOCK_CARPET:
                mixMask = BuildLpvMask(1u, 1u, 1u, 1u, 1u, 0u);
                mixWeight = 0.9;
                break;

            case BLOCK_DOOR_N:
                mixMask = BuildLpvMask(0u, 1u, 1u, 1u, 1u, 1u);
                mixWeight = 0.8;
                break;
            case BLOCK_DOOR_E:
                mixMask = BuildLpvMask(1u, 0u, 1u, 1u, 1u, 1u);
                mixWeight = 0.8;
                break;
            case BLOCK_DOOR_S:
                mixMask = BuildLpvMask(1u, 1u, 0u, 1u, 1u, 1u);
                mixWeight = 0.8;
                break;
            case BLOCK_DOOR_W:
                mixMask = BuildLpvMask(1u, 1u, 1u, 0u, 1u, 1u);
                mixWeight = 0.8;
                break;

            case BLOCK_FENCE:
            case BLOCK_FENCE_GATE:
                mixWeight = 0.7;
                break;
            case BLOCK_FLOWER_POT:
                mixWeight = 0.7;
                break;
            case BLOCK_IRON_BARS:
                mixWeight = 0.6;
                break;
            case BLOCK_PRESSURE_PLATE:
                mixMask = BuildLpvMask(1u, 1u, 1u, 1u, 1u, 0u);
                mixWeight = 0.9;
                break;

            case BLOCK_SLAB_TOP:
                mixMask = BuildLpvMask(1u, 1u, 1u, 1u, 0u, 1u);
                mixWeight = 0.5;
                break;
            case BLOCK_SLAB_BOTTOM:
                mixMask = BuildLpvMask(1u, 1u, 1u, 1u, 1u, 0u);
                mixWeight = 0.5;
                break;

            case BLOCK_TRAPDOOR_BOTTOM:
                mixMask = BuildLpvMask(1u, 1u, 1u, 1u, 1u, 0u);
                mixWeight = 0.8;
                break;
            case BLOCK_TRAPDOOR_TOP:
                mixMask = BuildLpvMask(1u, 1u, 1u, 1u, 0u, 1u);
                mixWeight = 0.8;
                break;
            case BLOCK_TRAPDOOR_N:
                mixMask = BuildLpvMask(0u, 1u, 1u, 1u, 1u, 1u);
                mixWeight = 0.8;
                break;
            case BLOCK_TRAPDOOR_E:
                mixMask = BuildLpvMask(1u, 0u, 1u, 1u, 1u, 1u);
                mixWeight = 0.8;
                break;
            case BLOCK_TRAPDOOR_S:
                mixMask = BuildLpvMask(1u, 1u, 0u, 1u, 1u, 1u);
                mixWeight = 0.8;
                break;
            case BLOCK_TRAPDOOR_W:
                mixMask = BuildLpvMask(1u, 1u, 1u, 0u, 1u, 1u);
                mixWeight = 0.8;
                break;

        // Misc

            case BLOCK_SIGN:
                mixWeight = 0.9;
                break;
        }

        // hack to increase light (if set)
        if (lightRange > 0.0) lightRange += 1.0;

        LpvBlockData block;
        block.ColorRange = packUnorm4x8(vec4(lightColor, lightRange/255.0));
        block.MaskWeight = BuildBlockLpvData(mixMask, mixWeight);
        block.Tint = packUnorm4x8(vec4(tintColor, 0.0));
        LpvBlockMap[blockId] = block;
    #endif
}
