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

// #define SHADOW_MAP_BIAS 0.5
// const float PI = 3.1415927;
// varying vec2 texcoord;
// uniform mat4 shadowProjectionInverse;
// uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
// uniform mat4 shadowModelView;
// uniform mat4 gbufferModelView;
// uniform mat4 gbufferModelViewInverse;
// uniform mat4 gbufferProjection;
// uniform mat4 gbufferProjectionInverse;
// uniform int hideGUI;
uniform vec3 cameraPosition;
// uniform float frameTimeCounter;
// uniform int frameCounter;
// uniform float screenBrightness;
// uniform vec3 sunVec;
// uniform float aspectRatio;
// uniform float sunElevation;
// uniform vec3 sunPosition;
// uniform float lightSign;
// uniform float cosFov;
// uniform vec3 shadowViewDir;
// uniform vec3 shadowCamera;
// uniform vec3 shadowLightVec;
// uniform float shadowMaxProj;
// attribute vec4 mc_midTexCoord;
// varying vec4 color;

#ifdef IS_LPV_ENABLED
	attribute vec4 mc_Entity;
	attribute vec3 at_midBlock;
	
	uniform int renderStage;
    uniform int currentRenderedItemId;
	uniform int blockEntityId;
	uniform int entityId;

	// #include "/lib/Shadow_Params.glsl"
	// #include "/lib/bokeh.glsl"


	#include "/lib/blocks.glsl"
	#include "/lib/entities.glsl"
	#include "/lib/voxel_common.glsl"
	#include "/lib/voxel_write.glsl"
#endif


void main() {
	#if defined IS_LPV_ENABLED && defined MC_GL_EXT_shader_image_load_store
		vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;

		int blockId = int(mc_Entity.x + 0.5);

		#if defined IS_LPV_ENABLED || defined WAVY_PLANTS
			vec3 playerpos = mat3(shadowModelViewInverse) * position + shadowModelViewInverse[3].xyz;
		#endif

		if (
			renderStage == MC_RENDER_STAGE_TERRAIN_SOLID || renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT ||
			renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED
		) {
			uint voxelId = uint(blockId);
			if (voxelId == 0u) voxelId = 1u;

			vec3 originPos = playerpos + at_midBlock/64.0;

			SetVoxelBlock(originPos, voxelId);
		}
		
		#ifdef LPV_ENTITY_LIGHTS
			if (
				(currentRenderedItemId > 0 || entityId > 0) &&
				(renderStage == MC_RENDER_STAGE_BLOCK_ENTITIES || renderStage == MC_RENDER_STAGE_ENTITIES)
			) {
				uint voxelId = 0u;

				if (currentRenderedItemId > 0) {
					if (entityId == ENTITY_PLAYER) {
						// TODO: remove once hand-light is added
						if (currentRenderedItemId < 1000)
							voxelId = uint(currentRenderedItemId);
					}
					else if (entityId != ENTITY_ITEM_FRAME)
						voxelId = uint(currentRenderedItemId);
				}
				else {
					switch (entityId) {
						case ENTITY_SPECTRAL_ARROW:
							voxelId = uint(BLOCK_TORCH);
							break;

						// TODO: blaze, magma_cube
					}
				}

				if (voxelId > 0u)
					SetVoxelBlock(playerpos, voxelId);
			}
		#endif
	#endif

	gl_Position = vec4(-1.0);
}