#ifdef RENDER_SHADOW
	layout(r16ui) uniform uimage3D imgVoxelMask;
#else
	layout(r16ui) uniform readonly uimage3D imgVoxelMask;
#endif

const uint VoxelSize = uint(exp2(LPV_SIZE));
const uvec3 VoxelSize3 = uvec3(VoxelSize);

#define BLOCK_EMPTY 0
