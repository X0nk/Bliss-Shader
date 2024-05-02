uint GetVoxelBlock(const in ivec3 voxelPos) {
	// TODO: exit early if outside bounds
	
	return imageLoad(imgVoxelMask, voxelPos).r;
}

uint GetVoxelBlock(const in vec3 playerPos) {
	ivec3 voxelPos = GetVoxelIndex(playerPos);

	// TODO: exit early if outside bounds
	return imageLoad(imgVoxelMask, voxelPos).r;
}
