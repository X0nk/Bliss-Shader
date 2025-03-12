// LPV block brightness scale
const float LpvBlockBrightness = 1.0;


float lpvCurve(float values) {
    // return values;
    return pow(1.0 - sqrt(1.0-values), 2.0);
}

vec4 SampleLpvLinear(const in vec3 lpvPos) {
    vec3 texcoord = lpvPos / LpvSize3;

    vec4 lpvSample = (frameCounter % 2) == 0
        ? textureLod(texLpv1, texcoord, 0)
        : textureLod(texLpv2, texcoord, 0);

    vec3 hsv = RgbToHsv(lpvSample.rgb);
    hsv.z = lpvCurve(hsv.b) * LpvBlockSkyRange.x;
    lpvSample.rgb = HsvToRgb(hsv);

    return lpvSample;
}

vec3 GetLpvBlockLight(const in vec4 lpvSample) {
    return LpvBlockBrightness * lpvSample.rgb;
}

float GetLpvSkyLight(const in vec4 lpvSample) {
    float skyLight = saturate(lpvSample.a);
    return skyLight*skyLight;
}
