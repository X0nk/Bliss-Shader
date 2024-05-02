vec4 SampleLpvNearest(const in ivec3 lpvPos) {
    vec4 lpvSample = (frameCounter % 2) == 0
        ? imageLoad(imgLpv1, lpvPos)
        : imageLoad(imgLpv2, lpvPos);

    lpvSample.b = pow(lpvSample.b, 4) * LpvBlockSkyRange.x;
    lpvSample.rgb = HsvToRgb(lpvSample.rgb);

    return lpvSample;
}

vec4 SampleLpvLinear(const in vec3 lpvPos) {
    vec3 pos = lpvPos - 0.5;
    ivec3 lpvCoord = ivec3(floor(pos));
    vec3 lpvF = fract(pos);

    vec4 sample_x1y1z1 = SampleLpvNearest(lpvCoord + ivec3(0, 0, 0));
    vec4 sample_x2y1z1 = SampleLpvNearest(lpvCoord + ivec3(1, 0, 0));
    vec4 sample_x1y2z1 = SampleLpvNearest(lpvCoord + ivec3(0, 1, 0));
    vec4 sample_x2y2z1 = SampleLpvNearest(lpvCoord + ivec3(1, 1, 0));

    vec4 sample_x1y1z2 = SampleLpvNearest(lpvCoord + ivec3(0, 0, 1));
    vec4 sample_x2y1z2 = SampleLpvNearest(lpvCoord + ivec3(1, 0, 1));
    vec4 sample_x1y2z2 = SampleLpvNearest(lpvCoord + ivec3(0, 1, 1));
    vec4 sample_x2y2z2 = SampleLpvNearest(lpvCoord + ivec3(1, 1, 1));

    vec4 sample_y1z1 = mix(sample_x1y1z1, sample_x2y1z1, lpvF.x);
    vec4 sample_y2z1 = mix(sample_x1y2z1, sample_x2y2z1, lpvF.x);

    vec4 sample_y1z2 = mix(sample_x1y1z2, sample_x2y1z2, lpvF.x);
    vec4 sample_y2z2 = mix(sample_x1y2z2, sample_x2y2z2, lpvF.x);

    vec4 sample_z1 = mix(sample_y1z1, sample_y2z1, lpvF.y);
    vec4 sample_z2 = mix(sample_y1z2, sample_y2z2, lpvF.y);

    return mix(sample_z1, sample_z2, lpvF.z);
}

vec3 GetLpvBlockLight(const in vec4 lpvSample) {
    return 3.0 * lpvSample.rgb;
}

float GetLpvSkyLight(const in vec4 lpvSample) {
    float skyLight = saturate(lpvSample.a);
    return skyLight*skyLight;
}
