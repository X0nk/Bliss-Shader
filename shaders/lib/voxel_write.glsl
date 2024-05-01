void SetVoxelBlock(const in vec3 playerPos, const in uint blockId) {
	vec3 cameraOffset = fract(cameraPosition);
	ivec3 voxelPos = ivec3(floor(playerPos + cameraOffset + VoxelSize/2u));

	// TODO: exit early if outside bounds
	imageStore(imgVoxelMask, voxelPos, uvec4(blockId));
}
