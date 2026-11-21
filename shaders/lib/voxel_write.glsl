


void SetVoxelBlock(const in vec3 playerPos, const in uint blockId) {
	ivec3 voxelPos = ivec3(floor(GetVoxelPosition(playerPos)));
	if (!InVoxelBounds(voxelPos)) return;

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
				if (entityId != ENTITY_ITEM_FRAME && entityId != ENTITY_PLAYER)
					voxelId = uint(currentRenderedItemId);
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

#if defined FLOODFILL_VERTEX_COLOR_FALLBACK
    uniform sampler2D gtexture;
	uniform usampler1D texBlockData;
    mat4 GetSaturationMatrix(const in float saturation) {
        const vec3 luminance = vec3(0.3086, 0.6094, 0.0820);
        
        vec3 lumSat = luminance * (1.0 - saturation);
        vec2 satZero = vec2(saturation, 0.0);
        
        return mat4(
            vec4(lumSat.r + satZero.xyy, 0.0),
            vec4(lumSat.g + satZero.yxy, 0.0),
            vec4(lumSat.b + satZero.yyx, 0.0),
            vec4(0.0, 0.0, 0.0, 1.0));
    }
	void setVoxelBlockFallback(const in vec3 playerPos,in vec3 vertexColor, const in uint blockId) {
		ivec3 voxelPos = ivec3(floor(GetVoxelPosition(playerPos)));
		uint packedVoxelData = texelFetch(texBlockData,int(blockId),0).r;
		if (!InVoxelBounds(voxelPos)) return;
		vec3 storedColor = vec3(1.0);
		float lightRange = 0.0;
		if(blockId == BLOCK_EMISSIVE_FALLBACK) {
			vec3 lightColor = texture(gtexure,mc_midTexCoord.xy).xyz * vertexColor;
			lightRange = 15.0;
			storedColor = (GetSaturationMatrix(LPV_SATURATION / 100.0) * vec4(lightColor,1.0)).xyz;
			packedVoxelData.x = packUnorm4x8(vec4(storedColor,lightRange/255.0));
		}
		imageAtomicMax(imgVoxelColor,voxelPos,packedVoxelData);
		imageStore(imgVoxelMask, voxelPos, uvec4(blockId));
	}
	void PopulateShadowVoxelVertexColor(const in vec3 playerPos,in vec3 vertexColor) {
		uint voxelId = 0u;
		vec3 originPos = playerPos;

		if (
			renderStage == MC_RENDER_STAGE_TERRAIN_SOLID || renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT ||
			renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED
		) {
			voxelId = uint(mc_Entity.x + 0.5);

			#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
				if (voxelId == 0u && at_midBlock.w > 0) voxelId = BLOCK_EMISSIVE_FALLBACK;
			#endif
	   		 float block_length =abs(length(at_midBlock.xyz) - 55.);
			 if(block_length > 0.5 && voxelId == 0) voxelId = BLOCK_LPV_MIN;
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
					if (entityId != ENTITY_ITEM_FRAME && entityId != ENTITY_PLAYER)
						voxelId = uint(currentRenderedItemId);
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

		if (voxelId > 0u )
			setVoxelBlockFallback(originPos,vertexColor,voxelId);
	}

#endif