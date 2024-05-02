void SetVoxelBlock(const in vec3 playerPos, const in uint blockId) {
	ivec3 voxelPos = GetVoxelIndex(playerPos);

	// TODO: exit early if outside bounds
	imageStore(imgVoxelMask, voxelPos, uvec4(blockId));
}
