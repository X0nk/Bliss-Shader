ivec3 GetVoxelIndex(const in vec3 playerPos) {
	vec3 cameraOffset = fract(cameraPosition);
	return ivec3(floor(playerPos + cameraOffset) + VoxelSize3/2u);
}

void SetVoxelBlock(const in vec3 playerPos, const in uint blockId) {
	ivec3 voxelPos = GetVoxelIndex(playerPos);
	if (clamp(voxelPos, ivec3(0), ivec3(VoxelSize-1u)) != voxelPos) return;

	imageStore(imgVoxelMask, voxelPos, uvec4(blockId));
}
