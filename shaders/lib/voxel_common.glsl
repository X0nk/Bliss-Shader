layout(r16ui) uniform uimage3D imgVoxelMask;

const uint VoxelSize = uint(exp2(LPV_SIZE));
const uvec3 VoxelSize3 = uvec3(VoxelSize);

const float voxelDistance = 64.0;

#define BLOCK_EMPTY 0

ivec3 GetVoxelIndex(const in vec3 playerPos) {
	vec3 cameraOffset = fract(cameraPosition);
	return ivec3(floor(playerPos + cameraOffset) + VoxelSize3/2u);
}
