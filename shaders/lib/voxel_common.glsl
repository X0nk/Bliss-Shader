layout(r16ui) uniform uimage3D imgVoxelMask;

const uint VoxelSize = uint(exp2(LPV_SIZE));
const uvec3 VoxelSize3 = uvec3(VoxelSize);

const float voxelDistance = 64.0;
