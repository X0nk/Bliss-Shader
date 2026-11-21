#ifdef RENDER_SHADOW
	layout(r16ui) uniform uimage3D imgVoxelMask;
	#if defined FLOODFILL_VERTEX_COLOR_FALLBACK
	layout(r32ui) uniform uimage3D imgVoxelColor;
	#endif
#else
	layout(r16ui) uniform readonly uimage3D imgVoxelMask;
	#if defined FLOODFILL_VERTEX_COLOR_FALLBACK
	layout(r32ui) uniform uimage3D imgVoxelColor;
	#endif
#endif
