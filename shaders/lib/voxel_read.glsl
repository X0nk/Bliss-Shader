uint GetVoxelBlock(const in ivec3 voxelPos) {
	if (clamp(voxelPos, ivec3(0), ivec3(VoxelSize3-1u)) != voxelPos)
		return BLOCK_EMPTY;
	
	return imageLoad(imgVoxelMask, voxelPos).r;
}
