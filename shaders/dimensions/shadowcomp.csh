#define RENDER_SHADOWCOMP

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#if   LPV_SIZE == 8
    const ivec3 workGroups = ivec3(32, 32, 32);
#elif LPV_SIZE == 7
    const ivec3 workGroups = ivec3(16, 16, 16);
#elif LPV_SIZE == 6
    const ivec3 workGroups = ivec3(8, 8, 8);
#endif

#ifdef IS_LPV_ENABLED
    shared vec4 lpvSharedData[10*10*10];
    shared uint voxelSharedData[10*10*10];

    const float LpvBlockFalloff = 0.96;
    const ivec3 lpvFlatten = ivec3(1, 10, 100);

    uniform int frameCounter;
    uniform vec3 cameraPosition;
    uniform vec3 previousCameraPosition;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferPreviousModelView;

    #include "/lib/hsv.glsl"
    #include "/lib/util.glsl"
    #include "/lib/blocks.glsl"
    #include "/lib/voxel_buffer.glsl"
    #include "/lib/voxel_common.glsl"
    #include "/lib/lpv_blocks.glsl"
    #include "/lib/lpv_buffer.glsl"

    int sumOf(ivec3 vec) {return vec.x + vec.y + vec.z;}

    int getSharedIndex(ivec3 pos) {
        return sumOf(pos * lpvFlatten);
    }

    ivec3 GetVoxelFrameOffset() {
        vec3 cameraViewDir = gbufferModelViewInverse[2].xyz;
        vec3 lpvPosNow = GetVoxelOffset(cameraPosition, cameraViewDir);

        vec3 previousCameraViewDir = vec3(gbufferPreviousModelView[0].z, gbufferPreviousModelView[1].z, gbufferPreviousModelView[2].z);
        vec3 lpvPosLast = GetVoxelOffset(previousCameraPosition, previousCameraViewDir);

        return ivec3(floor(lpvPosLast) - floor(lpvPosNow)) + ivec3(floor(cameraPosition) - floor(previousCameraPosition));
    }

    vec4 GetLpvValue(in ivec3 texCoord) {
        if (!InVoxelBounds(texCoord)) return vec4(0.0);

        vec4 lpvSample = (frameCounter % 2) == 0
            ? imageLoad(imgLpv2, texCoord)
            : imageLoad(imgLpv1, texCoord);

        vec3 hsv = RgbToHsv(lpvSample.rgb);
        hsv.z = exp2(hsv.z * LpvBlockRange) - 1.0;
        lpvSample.rgb = HsvToRgb(hsv.xyz);

        return lpvSample;
    }
    
    uint GetVoxelBlock(const in ivec3 voxelPos) {
        if (!InVoxelBounds(voxelPos)) return BLOCK_EMPTY;
        
        return imageLoad(imgVoxelMask, voxelPos).r;
    }

    void PopulateSharedIndex(const in ivec3 workGroupOffset, const in ivec3 imgCoordOffset, const in uint i) {
        ivec3 pos = workGroupOffset + ivec3(i / lpvFlatten) % 10;

        lpvSharedData[i] = GetLpvValue(imgCoordOffset + pos);
        voxelSharedData[i] = GetVoxelBlock(pos);
    }

    vec3 sampleShared(ivec3 pos, int mask_index) {
        int shared_index = getSharedIndex(pos + 1);

        float mixWeight = 1.0;
        uint mask = 0xFFFF;
        uint blockId = voxelSharedData[shared_index];
        
        if (blockId > 0 && blockId != BLOCK_EMPTY) {
            uvec2 blockData = imageLoad(imgBlockData, int(blockId)).rg;
            mask = (blockData.g >> 24u) & 0xFFFFu;
        }

        return lpvSharedData[shared_index].rgb * ((mask >> mask_index) & 1u);
    }

    vec3 mixNeighbours(const in ivec3 fragCoord, const in uint mask) {
        uvec3 m1 = (uvec3(mask) >> uvec3(0, 2, 4)) & uvec3(1u);
        uvec3 m2 = (uvec3(mask) >> uvec3(1, 3, 5)) & uvec3(1u);

        vec3 sX1 = sampleShared(fragCoord + ivec3(-1,  0,  0), 1) * m1.x;
        vec3 sX2 = sampleShared(fragCoord + ivec3( 1,  0,  0), 0) * m2.x;
        vec3 sY1 = sampleShared(fragCoord + ivec3( 0, -1,  0), 3) * m1.y;
        vec3 sY2 = sampleShared(fragCoord + ivec3( 0,  1,  0), 2) * m2.y;
        vec3 sZ1 = sampleShared(fragCoord + ivec3( 0,  0, -1), 5) * m1.z;
        vec3 sZ2 = sampleShared(fragCoord + ivec3( 0,  0,  1), 4) * m2.z;

        const float avgFalloff = (1.0/6.0) * LpvBlockFalloff;
        return (sX1 + sX2 + sY1 + sY2 + sZ1 + sZ2) * avgFalloff;
    }
#endif


////////////////////////////// VOID MAIN //////////////////////////////

void main() {
    #ifdef IS_LPV_ENABLED
        uvec3 chunkPos = gl_WorkGroupID * gl_WorkGroupSize;
        if (any(greaterThanEqual(chunkPos, VoxelSize3))) return;

        // Pre-populate shared-memory buffer for improved sampling performance
        uint i = uint(gl_LocalInvocationIndex) * 2u;
        if (i < 1000u) {
            ivec3 workGroupOffset = ivec3(gl_WorkGroupID * gl_WorkGroupSize) - 1;
            ivec3 imgCoordOffset = GetVoxelFrameOffset();

            PopulateSharedIndex(workGroupOffset, imgCoordOffset, i);
            PopulateSharedIndex(workGroupOffset, imgCoordOffset, i + 1u);
        }

        memoryBarrierShared();
        barrier();

        // Exit early if outside LPV buffer size
        ivec3 imgCoord = ivec3(gl_GlobalInvocationID);
        if (any(greaterThanEqual(imgCoord, VoxelSize3))) return;

        vec4 lightValue = vec4(0.0);
        vec3 lightColor = vec3(0.0);
        vec3 tintColor = vec3(1.0);
        float lightRange = 0.0;
        uint mixMask = 0xFFFF;
    
        // Decode light data for current voxel
        uint blockId = voxelSharedData[getSharedIndex(ivec3(gl_LocalInvocationID) + 1)];

        if (blockId > 0u) {
            uvec2 blockData = imageLoad(imgBlockData, int(blockId)).rg;
            vec4 lightColorRange = unpackUnorm4x8(blockData.r);
            lightColor = srgbToLinear(lightColorRange.rgb);
            lightRange = lightColorRange.a * 255.0;
            vec4 tintColorMask = unpackUnorm4x8(blockData.g);
            tintColor = srgbToLinear(tintColorMask.rgb);
            mixMask = (blockData.g >> 24u) & 0xFFFFu;
        }

        // Mix neighbor voxel light values
        if (any(greaterThan(tintColor, vec3(0.0)))) {
            vec3 lightMixed = mixNeighbours(ivec3(gl_LocalInvocationID), mixMask);
            lightMixed.rgb *= tintColor;
            lightValue.rgb += lightMixed;
        }

        // Add light for current voxel
        if (lightRange > 0.0) {
            vec3 hsv = RgbToHsv(lightColor);
            hsv.z = exp2(lightRange) - 1.0;
            lightValue.rgb += HsvToRgb(hsv);
        }

        // set alpha=1 for glass to prevent rain
        lightValue.a = lpvSharedData[getSharedIndex(ivec3(gl_LocalInvocationID) + ivec3(1,2,1))].a;
        if (blockId == 0 || blockId == BLOCK_GLASS) lightValue.a = 1.0;

        // Convert back to linear RGB space
        vec3 hsv = RgbToHsv(lightValue.rgb);
        hsv.z = log2(hsv.z + 1.0) / LpvBlockRange;
        lightValue.rgb = HsvToRgb(hsv.xyz);

        // Store final value
        if (frameCounter % 2 == 0)
            imageStore(imgLpv1, imgCoord, lightValue);
        else
            imageStore(imgLpv2, imgCoord, lightValue);
    #endif
}
