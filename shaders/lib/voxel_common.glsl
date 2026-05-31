#define BLOCK_EMPTY 0

const uint VoxelSize = uint(exp2(LPV_SIZE));
const ivec3 VoxelSize3 = ivec3(VoxelSize);
const ivec3 VoxelCenter = ivec3(VoxelSize/2u);
const float VoxelShiftF = LPV_FRUSTUM_OFFSET * 0.01;

const float LpvBlockRange = 15.0;


ivec3 GetVoxelCenter(const in vec3 viewDir) {
	vec3 offset = viewDir * (VoxelSize * VoxelShiftF);
	return VoxelCenter + ivec3(floor(offset));
}

vec3 GetVoxelOffset(const in vec3 cameraPos, const in vec3 playerViewDir) {
	return fract(cameraPos) + GetVoxelCenter(playerViewDir);
}

vec3 GetVoxelPosition(const in vec3 playerPos) {
	vec3 viewDir = gbufferModelViewInverse[2].xyz;
	return playerPos + GetVoxelOffset(cameraPosition, viewDir);
}

bool InVoxelBounds(const in ivec3 voxelPos) {
	const ivec3 voxelMin = ivec3(0);
	const ivec3 voxelMax = ivec3(VoxelSize-1u);
	return clamp(voxelPos, voxelMin, voxelMax) == voxelPos;
}
