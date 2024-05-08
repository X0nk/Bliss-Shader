#version 120
#extension GL_ARB_explicit_attrib_location: enable
#extension GL_ARB_shader_image_load_store: enable

#include "/lib/settings.glsl"

#define RENDER_SHADOW


/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

#ifdef IS_LPV_ENABLED
	attribute vec4 mc_Entity;
	attribute vec3 at_midBlock;
	attribute vec3 vaPosition;

	uniform mat4 shadowModelViewInverse;
	
	uniform int renderStage;
	uniform vec3 chunkOffset;
	uniform vec3 cameraPosition;
    uniform int currentRenderedItemId;
	uniform int blockEntityId;
	uniform int entityId;

	#include "/lib/blocks.glsl"
	#include "/lib/entities.glsl"
	#include "/lib/voxel_common.glsl"
	#include "/lib/voxel_write.glsl"
#endif


void main() {
	#if defined IS_LPV_ENABLED && defined MC_GL_EXT_shader_image_load_store
		#ifdef LPV_NOSHADOW_HACK
			vec3 playerpos = gl_Vertex.xyz;
		#else
			vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
			vec3 playerpos = mat3(shadowModelViewInverse) * position + shadowModelViewInverse[3].xyz;
		#endif

		if (
			renderStage == MC_RENDER_STAGE_TERRAIN_SOLID || renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT ||
			renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED
		) {
			vec3 originPos = playerpos + at_midBlock/64.0;

			uint voxelId = uint(mc_Entity.x + 0.5);
			if (voxelId == 0u) voxelId = 1u;

			SetVoxelBlock(originPos, voxelId);
		}
		
		#ifdef LPV_ENTITY_LIGHTS
			if (
				(currentRenderedItemId > 0 || entityId > 0) &&
				(renderStage == MC_RENDER_STAGE_BLOCK_ENTITIES || renderStage == MC_RENDER_STAGE_ENTITIES)
			) {
				uint voxelId = 0u;

				if (currentRenderedItemId > 0) {
					if (entityId != ENTITY_ITEM_FRAME && entityId != ENTITY_PLAYER)
						voxelId = uint(currentRenderedItemId);
				}
				else {
					switch (entityId) {
						case ENTITY_BLAZE:
						case ENTITY_END_CRYSTAL:
						// case ENTITY_FIREBALL_SMALL:
						case ENTITY_MAGMA_CUBE:
						case ENTITY_SPECTRAL_ARROW:
						case ENTITY_TNT:
							voxelId = uint(entityId);
							break;
					}
				}

				if (voxelId > 0u)
					SetVoxelBlock(playerpos, voxelId);
			}
		#endif
	#endif

	gl_Position = vec4(-1.0);
}
