struct LpvBlockData {           // 12 x1280 =?
    uint data;                  // 4
    uint LightColor;            // 4
    uint LightRangeSize;        // 4
    // uint LightMetadata;
};

#ifdef RENDER_SETUP
    layout(binding = 0) writeonly buffer lpvBlockData
#else
    layout(binding = 0) readonly buffer lpvBlockData
#endif
{
    LpvBlockData LpvBlockMap[];
};

uint BuildBlockLpvData(uint mixMask, float mixWeight) {
    uint data = uint(saturate(mixWeight) * 255.0);

    data = data | (mixMask << 8);

    return data;
}

void ParseBlockLpvData(const in uint data, out uint mixMask, out float mixWeight) {
    mixWeight = (data & 0xFF) / 255.0;

    mixMask = (data >> 8) & 0xFF;
}
