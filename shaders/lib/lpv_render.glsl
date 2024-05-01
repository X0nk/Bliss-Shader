vec4 cubic(const in float v) {
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * (1.0/6.0);
}

float LpvVoxelTest(const in ivec3 voxelCoord) {
    ivec3 gridCell = ivec3(floor(voxelCoord / LIGHT_BIN_SIZE));
    uint gridIndex = GetVoxelGridCellIndex(gridCell);
    ivec3 blockCell = voxelCoord - gridCell * LIGHT_BIN_SIZE;

    uint blockId = GetVoxelBlockMask(blockCell, gridIndex);
    return IsTraceOpenBlock(blockId) ? 1.0 : 0.0;
}

vec4 SampleLpvNearest(const in ivec3 lpvPos) {
    vec4 lpvSample = (frameCounter % 2) == 0
    #ifndef RENDER_GBUFFER
        ? texelFetch(texLPV_1, lpvPos, 0)
        : texelFetch(texLPV_2, lpvPos, 0);
    #else
        ? texelFetch(texLPV_2, lpvPos, 0)
        : texelFetch(texLPV_1, lpvPos, 0);
    #endif

    lpvSample.rgb = HsvToRgb(lpvSample.rgb);

    return lpvSample / DynamicLightRangeF;
}

vec4 SampleLpvLinear(const in vec3 lpvPos) {
    // vec3 pos = lpvPos - 0.49999;
    vec3 pos = lpvPos - 0.5;
    ivec3 lpvCoord = ivec3(floor(pos));
    vec3 lpvF = fract(pos);

    vec4 sample_x1y1z1 = SampleLpvNearest(lpvCoord + ivec3(0, 0, 0));
    vec4 sample_x2y1z1 = SampleLpvNearest(lpvCoord + ivec3(1, 0, 0));
    vec4 sample_x1y2z1 = SampleLpvNearest(lpvCoord + ivec3(0, 1, 0));
    vec4 sample_x2y2z1 = SampleLpvNearest(lpvCoord + ivec3(1, 1, 0));

    vec4 sample_x1y1z2 = SampleLpvNearest(lpvCoord + ivec3(0, 0, 1));
    vec4 sample_x2y1z2 = SampleLpvNearest(lpvCoord + ivec3(1, 0, 1));
    vec4 sample_x1y2z2 = SampleLpvNearest(lpvCoord + ivec3(0, 1, 1));
    vec4 sample_x2y2z2 = SampleLpvNearest(lpvCoord + ivec3(1, 1, 1));

    #ifdef LPV_VOXEL_TEST
        vec3 lpvCameraOffset = fract(cameraPosition);
        vec3 voxelCameraOffset = fract(cameraPosition / LIGHT_BIN_SIZE) * LIGHT_BIN_SIZE;
        ivec3 voxelPos = ivec3(lpvPos - SceneLPVCenter + VoxelBlockCenter + voxelCameraOffset - lpvCameraOffset + 0.5);

        float voxel_x1y1z1 = LpvVoxelTest(voxelPos + ivec3(0, 0, 0));
        float voxel_x2y1z1 = LpvVoxelTest(voxelPos + ivec3(1, 0, 0));
        float voxel_x1y2z1 = LpvVoxelTest(voxelPos + ivec3(0, 1, 0));
        float voxel_x2y2z1 = LpvVoxelTest(voxelPos + ivec3(1, 1, 0));

        float voxel_x1y1z2 = LpvVoxelTest(voxelPos + ivec3(0, 0, 1));
        float voxel_x2y1z2 = LpvVoxelTest(voxelPos + ivec3(1, 0, 1));
        float voxel_x1y2z2 = LpvVoxelTest(voxelPos + ivec3(0, 1, 1));
        float voxel_x2y2z2 = LpvVoxelTest(voxelPos + ivec3(1, 1, 1));

        sample_x1y1z1 *= voxel_x1y1z1;
        sample_x2y1z1 *= voxel_x2y1z1;
        sample_x1y2z1 *= voxel_x1y2z1;
        sample_x2y2z1 *= voxel_x2y2z1;

        sample_x1y1z2 *= voxel_x1y1z2;
        sample_x2y1z2 *= voxel_x2y1z2;
        sample_x1y2z2 *= voxel_x1y2z2;
        sample_x2y2z2 *= voxel_x2y2z2;


        // TODO: Add special checks for avoiding diagonal blending between occluded edges/corners

        // TODO: preload voxel grid into array
        // then prevent blending if all but current and opposing quadrants are empty

        // ivec3 iq = 1 - ivec3(step(vec3(0.5), lpvF));
        // float voxel_iqx = 1.0 - LpvVoxelTest(ivec3(voxelPos) + ivec3(iq.x, 0, 0));
        // float voxel_iqy = 1.0 - LpvVoxelTest(ivec3(voxelPos) + ivec3(0, iq.y, 0));
        // float voxel_iqz = 1.0 - LpvVoxelTest(ivec3(voxelPos) + ivec3(0, 0, iq.z));
        // float voxel_corner = 1.0 - voxel_iqx * voxel_iqy * voxel_iqz;

        // float voxel_y1 = LpvVoxelTest(ivec3(voxelPos + vec3(0, 0, 0)));
        // sample_x1y1z1 *= voxel_y1;
        // sample_x2y1z1 *= voxel_y1;
        // sample_x1y1z2 *= voxel_y1;
        // sample_x2y1z2 *= voxel_y1;

        // float voxel_y2 = LpvVoxelTest(voxelPos + ivec3(0, 1, 0));
        // sample_x1y2z1 *= voxel_y2;
        // sample_x2y2z1 *= voxel_y2;
        // sample_x1y2z2 *= voxel_y2;
        // sample_x2y2z2 *= voxel_y2;
    #endif

    vec4 sample_y1z1 = mix(sample_x1y1z1, sample_x2y1z1, lpvF.x);
    vec4 sample_y2z1 = mix(sample_x1y2z1, sample_x2y2z1, lpvF.x);

    vec4 sample_y1z2 = mix(sample_x1y1z2, sample_x2y1z2, lpvF.x);
    vec4 sample_y2z2 = mix(sample_x1y2z2, sample_x2y2z2, lpvF.x);

    vec4 sample_z1 = mix(sample_y1z1, sample_y2z1, lpvF.y);
    vec4 sample_z2 = mix(sample_y1z2, sample_y2z2, lpvF.y);

    return mix(sample_z1, sample_z2, lpvF.z);// * voxel_corner;
}

vec4 SampleLpvCubic(in vec3 lpvPos) {
    vec3 pos = lpvPos - 0.5;
    vec3 texF = fract(pos);
    pos = floor(pos);

    vec4 cubic_x = cubic(texF.x);
    vec4 cubic_y = cubic(texF.y);
    vec4 cubic_z = cubic(texF.z);

    vec3 pos_min = pos - 0.5;
    vec3 pos_max = pos + 1.5;

    vec3 s_min = vec3(cubic_x.x, cubic_y.x, cubic_z.x) + vec3(cubic_x.y, cubic_y.y, cubic_z.y);
    vec3 s_max = vec3(cubic_x.z, cubic_y.z, cubic_z.z) + vec3(cubic_x.w, cubic_y.w, cubic_z.w);

    vec3 offset_min = pos_min + vec3(cubic_x.y, cubic_y.y, cubic_z.y) / s_min;
    vec3 offset_max = pos_max + vec3(cubic_x.w, cubic_y.w, cubic_z.w) / s_max;

    vec4 sample_x1y1z1 = SampleLpvLinear(vec3(offset_max.x, offset_max.y, offset_max.z));
    vec4 sample_x2y1z1 = SampleLpvLinear(vec3(offset_min.x, offset_max.y, offset_max.z));
    vec4 sample_x1y2z1 = SampleLpvLinear(vec3(offset_max.x, offset_min.y, offset_max.z));
    vec4 sample_x2y2z1 = SampleLpvLinear(vec3(offset_min.x, offset_min.y, offset_max.z));

    vec4 sample_x1y1z2 = SampleLpvLinear(vec3(offset_max.x, offset_max.y, offset_min.z));
    vec4 sample_x2y1z2 = SampleLpvLinear(vec3(offset_min.x, offset_max.y, offset_min.z));
    vec4 sample_x1y2z2 = SampleLpvLinear(vec3(offset_max.x, offset_min.y, offset_min.z));
    vec4 sample_x2y2z2 = SampleLpvLinear(vec3(offset_min.x, offset_min.y, offset_min.z));

    #ifdef LPV_VOXEL_TEST
        vec3 lpvCameraOffset = fract(cameraPosition);
        vec3 voxelCameraOffset = fract(cameraPosition / LIGHT_BIN_SIZE) * LIGHT_BIN_SIZE;
        ivec3 voxelPos = ivec3(lpvPos - SceneLPVCenter + VoxelBlockCenter + voxelCameraOffset - lpvCameraOffset + 0.5);

        float voxel_x1y1z1 = LpvVoxelTest(voxelPos + ivec3(1, 1, 1));
        float voxel_x2y1z1 = LpvVoxelTest(voxelPos + ivec3(0, 1, 1));
        float voxel_x1y2z1 = LpvVoxelTest(voxelPos + ivec3(1, 0, 1));
        float voxel_x2y2z1 = LpvVoxelTest(voxelPos + ivec3(0, 0, 1));

        float voxel_x1y1z2 = LpvVoxelTest(voxelPos + ivec3(1, 1, 0));
        float voxel_x2y1z2 = LpvVoxelTest(voxelPos + ivec3(0, 1, 0));
        float voxel_x1y2z2 = LpvVoxelTest(voxelPos + ivec3(1, 0, 0));
        float voxel_x2y2z2 = LpvVoxelTest(voxelPos + ivec3(0, 0, 0));

        sample_x1y1z1 *= voxel_x1y1z1;
        sample_x2y1z1 *= voxel_x2y1z1;
        sample_x1y2z1 *= voxel_x1y2z1;
        sample_x2y2z1 *= voxel_x2y2z1;

        sample_x1y1z2 *= voxel_x1y1z2;
        sample_x2y1z2 *= voxel_x2y1z2;
        sample_x1y2z2 *= voxel_x1y2z2;
        sample_x2y2z2 *= voxel_x2y2z2;
    #endif

    vec3 mixF = s_min / (s_min + s_max);

    vec4 sample_y1z1 = mix(sample_x1y1z1, sample_x2y1z1, mixF.x);
    vec4 sample_y2z1 = mix(sample_x1y2z1, sample_x2y2z1, mixF.x);

    vec4 sample_y1z2 = mix(sample_x1y1z2, sample_x2y1z2, mixF.x);
    vec4 sample_y2z2 = mix(sample_x1y2z2, sample_x2y2z2, mixF.x);

    vec4 sample_z1 = mix(sample_y1z1, sample_y2z1, mixF.y);
    vec4 sample_z2 = mix(sample_y1z2, sample_y2z2, mixF.y);

    return mix(sample_z1, sample_z2, mixF.z);
}

vec4 SampleLpv(const in vec3 samplePos) {
    #if LPV_SAMPLE_MODE == LPV_SAMPLE_CUBIC
        vec4 lpvSample = SampleLpvCubic(samplePos);
    #elif LPV_SAMPLE_MODE == LPV_SAMPLE_LINEAR
        vec4 lpvSample = SampleLpvLinear(samplePos);
    #else
        ivec3 coord = ivec3(samplePos);
        vec4 lpvSample = SampleLpvNearest(coord);
    #endif

    return lpvSample;
}

vec4 SampleLpv(const in vec3 lpvPos, const in vec3 geoNormal, const in vec3 texNormal) {
    #if MATERIAL_NORMALS != 0
        vec3 samplePos = lpvPos - 0.5 * geoNormal + texNormal;
    #else
        vec3 samplePos = lpvPos + 0.5 * geoNormal;
    #endif

    return SampleLpv(samplePos);
}

// vec3 GetLpvBlockLight(in vec4 lpvSample, const in float power) {
//     return (lpvSample.rgb * LPV_BLOCKLIGHT_SCALE) / 8.0 * DynamicLightBrightness;
// }

vec3 GetLpvBlockLight(const in vec4 lpvSample) {
    // return GetLpvBlockLight(lpvSample, 1.0);
    return (1.0/8.0) * (lpvSample.rgb * LPV_BLOCKLIGHT_SCALE) * DynamicLightBrightness;
}

float GetLpvSkyLight(const in vec4 lpvSample) {
    float skyLight = saturate(lpvSample.a);
    return _pow2(skyLight);
}
