#version 120
#include "/lib/settings.glsl"
#ifdef IS_LPV_ENABLED
	#extension GL_ARB_explicit_attrib_location: enable
	#extension GL_ARB_shader_image_load_store: enable
	#extension GL_ARB_shading_language_packing : enable
#endif

#define RENDER_SHADOW


/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

#ifdef IS_LPV_ENABLED
	attribute vec4 mc_Entity;
	#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
		attribute vec4 at_midBlock;
	#else
		attribute vec3 at_midBlock;
	#endif
	attribute vec3 vaPosition;

	#ifdef LPV_ENTITY_LIGHTS
		uniform usampler1D texBlockData;
	#endif

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

		PopulateShadowVoxel(playerpos);
	#endif

	gl_Position = vec4(-1.0);
}
