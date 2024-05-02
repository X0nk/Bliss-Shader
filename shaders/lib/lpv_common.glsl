layout(rgba8) uniform image3D imgLpv1;
layout(rgba8) uniform image3D imgLpv2;

const uint LpvSize = uint(exp2(LPV_SIZE));
const uvec3 LpvSize3 = uvec3(LpvSize);

const vec2 LpvBlockSkyRange = vec2(1.0, 24.0);

// #if defined RENDER_SHADOWCOMP || defined RENDER_GBUFFER
//     layout(r16ui) uniform uimage2D imgVoxelMask;
// #elif defined RENDER_BEGIN || defined RENDER_GEOMETRY || defined RENDER_VERTEX
//     layout(r16ui) uniform writeonly uimage2D imgVoxelMask;
// #else
//     layout(r16ui) uniform readonly uimage2D imgVoxelMask;
// #endif

// #define LIGHT_NONE 0

vec3 GetLpvPosition(const in vec3 playerPos) {
	vec3 cameraOffset = fract(cameraPosition);
	return playerPos + cameraOffset + LpvSize3/2u;
}
