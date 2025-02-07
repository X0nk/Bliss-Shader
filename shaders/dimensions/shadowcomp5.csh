#define RENDER_SHADOWCOMP

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#ifdef IS_LPV_ENABLED
	#ifdef LPV_SHADOWS
		layout(r32ui) restrict uniform uimage3D imgSortLights;
	#endif
#endif

void main() {
	#ifdef IS_LPV_ENABLED
		#ifdef LPV_SHADOWS
			// total coverage of 1

			uint[LPV_SHADOWS_LIGHT_COUNT] allData;
			for(int i = 0; i < LPV_SHADOWS_LIGHT_COUNT; i++) {
				allData[i] = 4294967295u;
			}

			for (int x = 0; x < 32; x++) {
				for (int z = 0; z < LPV_SHADOWS_LIGHT_COUNT; z++) {
					ivec3 pos = ivec3(x, 0, z);
					uint data = imageLoad(imgSortLights, pos).r;
					// insert
					for (int i = 0; i < LPV_SHADOWS_LIGHT_COUNT; i++) {
						uint minData = min(allData[i], data);
						if (minData == data) data = allData[i];
						allData[i] = minData;
						if (minData == 4294967295u) break;
					}
					/*uint minData = min(allData[z], data);
					if (minData == data) data = allData[z];
					allData[z] = minData;
					if (minData == 4294967295u) break;*/
				}
			}
			for (int i = 0; i < LPV_SHADOWS_LIGHT_COUNT; i++) {
				imageStore(imgSortLights, ivec3(0, 0, i), uvec4(allData[i]));
			}
		#endif
	#endif
}