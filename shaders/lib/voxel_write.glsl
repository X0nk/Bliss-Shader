ivec3 GetVoxelIndex(const in vec3 playerPos) {
	vec3 cameraOffset = fract(cameraPosition);
	return ivec3(floor(playerPos + cameraOffset) + VoxelSize3/2u);
}

void SetVoxelBlock(const in vec3 playerPos, const in uint blockId) {
	ivec3 voxelPos = GetVoxelIndex(playerPos);
	if (clamp(voxelPos, ivec3(0), ivec3(VoxelSize-1u)) != voxelPos) return;

	imageStore(imgVoxelMask, voxelPos, uvec4(blockId));
}

void PopulateShadowVoxel(const in vec3 playerPos) {
	uint voxelId = 0u;
	vec3 originPos = playerPos;

	if (
		renderStage == MC_RENDER_STAGE_TERRAIN_SOLID || renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT ||
		renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED
	) {
		voxelId = uint(mc_Entity.x + 0.5);

		#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
			if (voxelId == 0u && at_midBlock.w > 0) voxelId = uint(BLOCK_LIGHT_1 + at_midBlock.w - 1);
		#endif

		if (voxelId == 0u) voxelId = 1u;

		originPos += at_midBlock.xyz/64.0;
	}
	
	#ifdef LPV_ENTITY_LIGHTS
		if (
			((renderStage == MC_RENDER_STAGE_ENTITIES && (currentRenderedItemId > 0 || entityId > 0)) || renderStage == MC_RENDER_STAGE_BLOCK_ENTITIES)
		) {
			if (renderStage == MC_RENDER_STAGE_BLOCK_ENTITIES) {
				if (blockEntityId > 0 && blockEntityId < 500)
					voxelId = uint(blockEntityId);
			}
			else if (currentRenderedItemId > 0 && currentRenderedItemId < 1200) {
				if (entityId != ENTITY_ITEM_FRAME && entityId != ENTITY_PLAYER) {
		            uint blockDataR = texelFetch(texBlockData, currentRenderedItemId, 0).r;
		            float lightRange = unpackUnorm4x8(blockDataR).a * 255.0;

		            if (lightRange > 0.0)
						voxelId = uint(currentRenderedItemId);
				}
			}
			else {
				switch (entityId) {
					case ENTITY_BLAZE:
					case ENTITY_END_CRYSTAL:
					// case ENTITY_FIREBALL_SMALL:
					case ENTITY_GLOW_SQUID:
					case ENTITY_MAGMA_CUBE:
					case ENTITY_SPECTRAL_ARROW:
					case ENTITY_TNT:
						voxelId = uint(entityId);
						break;
				}
			}
		}
	#endif

	if (voxelId > 0u)
		SetVoxelBlock(originPos, voxelId);
}