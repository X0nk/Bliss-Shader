bool getLightData(in uint data, out float dist, out ivec3 pos, out uint id) {
	if (data == 4294967295u) {
		return false;
	} else {
		dist = float((data & 0xFC000000u) >> 26) * 0.25;
		pos = ivec3((data & 0x03E00000u) >> 21,
			(data & 0x001F0000u) >> 16,
			(data & 0x0000F800u) >> 11);
		id =   (data & 0x000007FFu);
		return true;
	}
}