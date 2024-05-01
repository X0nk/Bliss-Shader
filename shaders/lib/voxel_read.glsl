uint GetVoxelBlock(const in ivec3 voxelPos) {
	// TODO: exit early if outside bounds
	return imageLoad(imgVoxelMask, voxelPos).r;
}

uint GetVoxelBlock(const in vec3 playerPos) {
	vec3 cameraOffset = fract(cameraPosition);
	ivec3 voxelPos = ivec3(floor(playerPos + cameraOffset + VoxelSize/2u));

	// TODO: exit early if outside bounds
	return imageLoad(imgVoxelMask, voxelPos).r;
}
