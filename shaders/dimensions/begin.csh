#define RENDER_SHADOWCOMP

layout (local_size_x = 9, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#ifdef IS_LPV_ENABLED
	#ifdef LPV_SHADOWS
		layout(r32ui) uniform restrict writeonly uimage1D imgCloseLights;
		layout(r32ui) uniform restrict readonly uimage3D imgSortLights;
	#endif
#endif

////////////////////////////// VOID MAIN //////////////////////////////

void main() {
	#ifdef IS_LPV_ENABLED
		#ifdef LPV_SHADOWS
			for (int i = 0; i < 10; i++) {
				imageStore(imgCloseLights, i, uvec4(imageLoad(imgSortLights, ivec3(0,0,i))));
			}
		#endif
	#endif
}