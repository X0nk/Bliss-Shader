const uint LpvSize = uint(exp2(LPV_SIZE));

layout(r16ui) uniform uimage3D imgVoxelMask;

// #if defined RENDER_SHADOWCOMP || defined RENDER_GBUFFER
//     layout(r16ui) uniform uimage2D imgVoxelMask;
// #elif defined RENDER_BEGIN || defined RENDER_GEOMETRY || defined RENDER_VERTEX
//     layout(r16ui) uniform writeonly uimage2D imgVoxelMask;
// #else
//     layout(r16ui) uniform readonly uimage2D imgVoxelMask;
// #endif
