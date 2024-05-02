#version 430 compatibility

#include "/lib/settings.glsl"

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

	const vec2 LpvBlockSkyFalloff = vec2(0.96, 0.96);
	const ivec3 lpvFlatten = ivec3(1, 10, 100);

	#define GAMMA 2.2
	#define EPSILON 1e-6


	uniform int frameCounter;
	uniform vec3 cameraPosition;

	#include "/lib/hsv.glsl"
	#include "/lib/blocks.glsl"
	#include "/lib/lpv_common.glsl"
	#include "/lib/lpv_blocks.glsl"
	#include "/lib/voxel_common.glsl"
	#include "/lib/voxel_read.glsl"

	// uniform mat4 gbufferModelViewInverse;

	int sumOf(ivec3 vec) {return vec.x + vec.y + vec.z;}

	vec3 RGBToLinear(const in vec3 color) {
		return pow(color, vec3(GAMMA));
	}

	vec3 Lpv_RgbToHsv(const in vec3 lightColor, const in float lightRange) {
	    vec3 lightValue = RgbToHsv(lightColor);
	    lightValue.b = lightRange / LpvBlockSkyRange.x;
	    return lightValue;
	}

	vec4 GetLpvValue(in ivec3 texCoord) {
	    if (clamp(texCoord, ivec3(0), ivec3(LpvSize) - 1) != texCoord) return vec4(0.0);

	    vec4 lpvSample = (frameCounter % 2) == 0
	        ? imageLoad(imgLpv2, texCoord)
	        : imageLoad(imgLpv1, texCoord);

	    lpvSample.ba = exp2(lpvSample.ba * LpvBlockSkyRange) - 1.0;
	    lpvSample.rgb = HsvToRgb(lpvSample.rgb);

	    return lpvSample;
	}

	int getSharedCoord(ivec3 pos) {
	    return sumOf(pos * lpvFlatten);
	}

	vec4 sampleShared(ivec3 pos) {
	    return lpvSharedData[getSharedCoord(pos + 1)];
	}

	vec4 sampleShared(ivec3 pos, int mask_index) {
	    int shared_index = getSharedCoord(pos + 1);

	    float mixWeight = 1.0;
	    uint mixMask = 0xFFFF;
	    uint blockId = voxelSharedData[shared_index];
	    
	    if (blockId > 0 && blockId != BLOCK_EMPTY)
	        ParseBlockLpvData(LpvBlockMap[blockId].data, mixMask, mixWeight);

	    return lpvSharedData[shared_index] * ((mixMask >> mask_index) & 1u);// * mixWeight;
	}

	vec4 mixNeighbours(const in ivec3 fragCoord, const in uint mask) {
	    vec4 nX1 = sampleShared(fragCoord + ivec3(-1,  0,  0), 1) * ((mask     ) & 1u);
	    vec4 nX2 = sampleShared(fragCoord + ivec3( 1,  0,  0), 0) * ((mask >> 1) & 1u);
	    vec4 nY1 = sampleShared(fragCoord + ivec3( 0, -1,  0), 3) * ((mask >> 2) & 1u);
	    vec4 nY2 = sampleShared(fragCoord + ivec3( 0,  1,  0), 2) * ((mask >> 3) & 1u);
	    vec4 nZ1 = sampleShared(fragCoord + ivec3( 0,  0, -1), 5) * ((mask >> 4) & 1u);
	    vec4 nZ2 = sampleShared(fragCoord + ivec3( 0,  0,  1), 4) * ((mask >> 5) & 1u);

	    const vec4 avgFalloff = (1.0/6.0) * LpvBlockSkyFalloff.xxxy;
	    return (nX1 + nX2 + nY1 + nY2 + nZ1 + nZ2) * avgFalloff;
	}

	void PopulateSharedIndex(const in ivec3 imgCoordOffset, const in ivec3 workGroupOffset, const in uint i) {
	    ivec3 pos = workGroupOffset + ivec3(i / lpvFlatten) % 10;

	    ivec3 lpvPos = imgCoordOffset + pos;
	    lpvSharedData[i] = GetLpvValue(lpvPos);
	    voxelSharedData[i] = GetVoxelBlock(lpvPos);
	}

	void PopulateShared() {
	    uint i = uint(gl_LocalInvocationIndex) * 2u;
	    if (i >= 1000u) return;

	    // ivec3 voxelOffset = GetLPVVoxelOffset();
	    ivec3 imgCoordOffset = ivec3(0);//GetLPVFrameOffset();
	    ivec3 workGroupOffset = ivec3(gl_WorkGroupID * gl_WorkGroupSize) - 1;

	    PopulateSharedIndex(imgCoordOffset, workGroupOffset, i);
	    PopulateSharedIndex(imgCoordOffset, workGroupOffset, i + 1u);
	}
#endif


////////////////////////////// VOID MAIN //////////////////////////////

void main() {
    #ifdef IS_LPV_ENABLED
        uvec3 chunkPos = gl_WorkGroupID * gl_WorkGroupSize;
        if (any(greaterThanEqual(chunkPos, LpvSize3))) return;

        PopulateShared();

        barrier();

        ivec3 imgCoord = ivec3(gl_GlobalInvocationID);
        if (any(greaterThanEqual(imgCoord, LpvSize3))) return;

        // vec3 viewDir = gbufferModelViewInverse[2].xyz;
        //vec3 lpvCenter = vec3(0.0);//GetLpvCenter(cameraPosition, viewDir);
        //vec3 blockLocalPos = imgCoord - lpvCenter + 0.5;

        vec4 lightValue = vec4(0.0);
        uint mixMask = 0xFFFF;
        vec3 tint = vec3(1.0);

        uint blockId = voxelSharedData[getSharedCoord(ivec3(gl_LocalInvocationID) + 1)];
        float mixWeight = blockId == BLOCK_EMPTY ? 1.0 : 0.0;

        LpvBlockData blockData = LpvBlockMap[blockId];
        if (blockId > 0 && blockId != BLOCK_EMPTY)
            ParseBlockLpvData(blockData.data, mixMask, mixWeight);

        #ifdef LPV_GLASS_TINT
            if (blockId >= BLOCK_HONEY && blockId <= BLOCK_TINTED_GLASS) {
                tint = GetLightGlassTint(blockId);
                mixWeight = 1.0;
            }
        #endif
        
        if (mixWeight > EPSILON) {
            vec4 lightMixed = mixNeighbours(ivec3(gl_LocalInvocationID), mixMask);
            lightMixed.rgb *= mixWeight * tint;
            lightValue += lightMixed;
        }

        lightValue.rgb = RgbToHsv(lightValue.rgb);
        lightValue.ba = log2(lightValue.ba + 1.0) / LpvBlockSkyRange;

        if (blockId > 0 && blockId != BLOCK_EMPTY) {
            vec3 lightColor = unpackUnorm4x8(blockData.LightColor).rgb;
            vec2 lightRangeSize = unpackUnorm4x8(blockData.LightRangeSize).xy;
            float lightRange = lightRangeSize.x * 255.0;

            lightColor = RGBToLinear(lightColor);

            // #ifdef LIGHTING_FLICKER
            //    vec2 lightNoise = GetDynLightNoise(cameraPosition + blockLocalPos);
            //    ApplyLightFlicker(lightColor, lightType, lightNoise);
            // #endif

            if (lightRange > EPSILON) {
                lightValue.rgb = Lpv_RgbToHsv(lightColor, lightRange);
            }
        }

        if (frameCounter % 2 == 0)
            imageStore(imgLpv1, imgCoord, lightValue);
        else
            imageStore(imgLpv2, imgCoord, lightValue);
    #endif
}
