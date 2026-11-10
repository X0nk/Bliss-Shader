#ifdef RENDER_SHADOW
	layout(r16ui) uniform uimage3D imgVoxelMask;
#else
	layout(r16ui) uniform readonly uimage3D imgVoxelMask;
#endif
