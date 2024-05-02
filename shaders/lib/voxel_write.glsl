void SetVoxelBlock(const in vec3 playerPos, const in uint blockId) {
	ivec3 voxelPos = GetVoxelIndex(playerPos);
	if (clamp(voxelPos, ivec3(0), ivec3(VoxelSize-1u)) != voxelPos) return;

	imageStore(imgVoxelMask, voxelPos, uvec4(blockId));
}
