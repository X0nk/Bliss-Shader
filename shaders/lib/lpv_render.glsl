// float LpvVoxelTest(const in ivec3 voxelCoord) {
//     ivec3 gridCell = ivec3(floor(voxelCoord / LIGHT_BIN_SIZE));
//     uint gridIndex = GetVoxelGridCellIndex(gridCell);
//     ivec3 blockCell = voxelCoord - gridCell * LIGHT_BIN_SIZE;

//     uint blockId = GetVoxelBlockMask(blockCell, gridIndex);
//     return IsTraceOpenBlock(blockId) ? 1.0 : 0.0;
// }

vec4 SampleLpvNearest(const in ivec3 lpvPos) {
    vec4 lpvSample = (frameCounter % 2) == 0
        ? imageLoad(imgLpv1, lpvPos)
        : imageLoad(imgLpv2, lpvPos);

    //lpvSample.ba = exp2(lpvSample.ba * LpvBlockSkyRange) - 1.0;
    lpvSample.b = (lpvSample.b*lpvSample.b) * LpvBlockSkyRange.x;
    lpvSample.rgb = HsvToRgb(lpvSample.rgb);

    return lpvSample;
}

vec4 SampleLpvLinear(const in vec3 lpvPos) {
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

    // #ifdef LPV_VOXEL_TEST
    //     vec3 lpvCameraOffset = fract(cameraPosition);
    //     vec3 voxelCameraOffset = fract(cameraPosition / LIGHT_BIN_SIZE) * LIGHT_BIN_SIZE;
    //     ivec3 voxelPos = ivec3(lpvPos - SceneLPVCenter + VoxelBlockCenter + voxelCameraOffset - lpvCameraOffset + 0.5);

    //     float voxel_x1y1z1 = LpvVoxelTest(voxelPos + ivec3(0, 0, 0));
    //     float voxel_x2y1z1 = LpvVoxelTest(voxelPos + ivec3(1, 0, 0));
    //     float voxel_x1y2z1 = LpvVoxelTest(voxelPos + ivec3(0, 1, 0));
    //     float voxel_x2y2z1 = LpvVoxelTest(voxelPos + ivec3(1, 1, 0));

    //     float voxel_x1y1z2 = LpvVoxelTest(voxelPos + ivec3(0, 0, 1));
    //     float voxel_x2y1z2 = LpvVoxelTest(voxelPos + ivec3(1, 0, 1));
    //     float voxel_x1y2z2 = LpvVoxelTest(voxelPos + ivec3(0, 1, 1));
    //     float voxel_x2y2z2 = LpvVoxelTest(voxelPos + ivec3(1, 1, 1));

    //     sample_x1y1z1 *= voxel_x1y1z1;
    //     sample_x2y1z1 *= voxel_x2y1z1;
    //     sample_x1y2z1 *= voxel_x1y2z1;
    //     sample_x2y2z1 *= voxel_x2y2z1;

    //     sample_x1y1z2 *= voxel_x1y1z2;
    //     sample_x2y1z2 *= voxel_x2y1z2;
    //     sample_x1y2z2 *= voxel_x1y2z2;
    //     sample_x2y2z2 *= voxel_x2y2z2;


    //     // TODO: Add special checks for avoiding diagonal blending between occluded edges/corners

    //     // TODO: preload voxel grid into array
    //     // then prevent blending if all but current and opposing quadrants are empty

    //     // ivec3 iq = 1 - ivec3(step(vec3(0.5), lpvF));
    //     // float voxel_iqx = 1.0 - LpvVoxelTest(ivec3(voxelPos) + ivec3(iq.x, 0, 0));
    //     // float voxel_iqy = 1.0 - LpvVoxelTest(ivec3(voxelPos) + ivec3(0, iq.y, 0));
    //     // float voxel_iqz = 1.0 - LpvVoxelTest(ivec3(voxelPos) + ivec3(0, 0, iq.z));
    //     // float voxel_corner = 1.0 - voxel_iqx * voxel_iqy * voxel_iqz;

    //     // float voxel_y1 = LpvVoxelTest(ivec3(voxelPos + vec3(0, 0, 0)));
    //     // sample_x1y1z1 *= voxel_y1;
    //     // sample_x2y1z1 *= voxel_y1;
    //     // sample_x1y1z2 *= voxel_y1;
    //     // sample_x2y1z2 *= voxel_y1;

    //     // float voxel_y2 = LpvVoxelTest(voxelPos + ivec3(0, 1, 0));
    //     // sample_x1y2z1 *= voxel_y2;
    //     // sample_x2y2z1 *= voxel_y2;
    //     // sample_x1y2z2 *= voxel_y2;
    //     // sample_x2y2z2 *= voxel_y2;
    // #endif

    vec4 sample_y1z1 = mix(sample_x1y1z1, sample_x2y1z1, lpvF.x);
    vec4 sample_y2z1 = mix(sample_x1y2z1, sample_x2y2z1, lpvF.x);

    vec4 sample_y1z2 = mix(sample_x1y1z2, sample_x2y1z2, lpvF.x);
    vec4 sample_y2z2 = mix(sample_x1y2z2, sample_x2y2z2, lpvF.x);

    vec4 sample_z1 = mix(sample_y1z1, sample_y2z1, lpvF.y);
    vec4 sample_z2 = mix(sample_y1z2, sample_y2z2, lpvF.y);

    return mix(sample_z1, sample_z2, lpvF.z);// * voxel_corner;
}

vec3 GetLpvBlockLight(const in vec4 lpvSample) {
    // return GetLpvBlockLight(lpvSample, 1.0);
    return 3.0 * lpvSample.rgb;// * LPV_BLOCKLIGHT_SCALE);// * DynamicLightBrightness;
}

float GetLpvSkyLight(const in vec4 lpvSample) {
    float skyLight = saturate(lpvSample.a);
    // return _pow2(skyLight);
    return skyLight*skyLight;
}
