#ifdef RENDER_SHADOWCOMP
	layout(rgba8) uniform restrict image3D imgLpv1;
	layout(rgba8) uniform restrict image3D imgLpv2;
#else
	layout(rgba8) uniform readonly image3D imgLpv1;
	layout(rgba8) uniform readonly image3D imgLpv2;
#endif
