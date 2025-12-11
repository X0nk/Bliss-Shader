// --- CONFIGURATION ---
#define LPV_AO_CONTROL  // True / False
#define LPV_AO_STRENGTH 0.0  // 0.0 -> 2.0
#define LPV_AO_CONTROL_EDGE_SMOOTHNESS 2  // [-1 0 1 2]
// #define LPV_AO_CONTROL_LEAK_FIX_TRADEOFF  // True / False
#define LPV_VANILLA_LIGHMAP_MASK_STRENGTH 1.0  // 0.0 -> 1.0
// #define LPV_AO_VANILLA_AO_BRIGHTENING  // Requires less than 1.0 AO
#define LPV_AO_VANILLA_AO_BRIGHTENING_MULTIPLAYER 1.0  // 0.0 -> 10.0


// LPV block brightness scale. just 1.0/15.0
const float LpvBlockBrightness = 0.066666;


float lpvCurve(float values) {
    #ifdef VANILLA_LIGHTMAP_MASK
        // No idea why but power of 4 works very nicely
        return mix(values*values, sqrt(values), pow(LPV_VANILLA_LIGHMAP_MASK_STRENGTH, 4.0));
    #else
        return values*values;
    #endif
}

vec4 getRawLpv(sampler3D tex, ivec3 coord) {
    return texelFetch(tex, coord, 0);
}

vec4 SampleLpvSmart(sampler3D tex, vec3 lpvPos) {
    // Move lpvPos to block center
    vec3 texPos = lpvPos - 0.5; 
    
    ivec3 p0 = ivec3(texPos);
    ivec3 p1 = p0 + 1;
    vec3 w = fract(texPos); 


    // Fetch all 8 neighbors
    vec4 c000 = getRawLpv(tex, ivec3(p0.x, p0.y, p0.z));
    vec4 c100 = getRawLpv(tex, ivec3(p1.x, p0.y, p0.z));
    vec4 c010 = getRawLpv(tex, ivec3(p0.x, p1.y, p0.z));
    vec4 c110 = getRawLpv(tex, ivec3(p1.x, p1.y, p0.z));
    vec4 c001 = getRawLpv(tex, ivec3(p0.x, p0.y, p1.z));
    vec4 c101 = getRawLpv(tex, ivec3(p1.x, p0.y, p1.z));
    vec4 c011 = getRawLpv(tex, ivec3(p0.x, p1.y, p1.z));
    vec4 c111 = getRawLpv(tex, ivec3(p1.x, p1.y, p1.z));


    // 1. STANDARD TRILINEAR INTERPOLATION
    // Calculate standard trilinear weights
    float w000 = (1.0 - w.x) * (1.0 - w.y) * (1.0 - w.z);
    float w100 = (w.x)       * (1.0 - w.y) * (1.0 - w.z);
    float w010 = (1.0 - w.x) * (w.y)       * (1.0 - w.z);
    float w110 = (w.x)       * (w.y)       * (1.0 - w.z);
    float w001 = (1.0 - w.x) * (1.0 - w.y) * (w.z);
    float w101 = (w.x)       * (1.0 - w.y) * (w.z);
    float w011 = (1.0 - w.x) * (w.y)       * (w.z);
    float w111 = (w.x)       * (w.y)       * (w.z);
    // Do the standard trilinear interpolation
    vec4 standardResult = 
        c000 * w000 + c100 * w100 + c010 * w010 + c110 * w110 +
        c001 * w001 + c101 * w101 + c011 * w011 + c111 * w111;


    // 2. CLAMPED NO AO INTERPOLATION
    // Sum up the weights ONLY for neighbors that have any light.
    float validWeight = 0.0;
    
    // We check brightness once to save performance
    float b000 = max(c000.r, max(c000.g, c000.b));
    float b100 = max(c100.r, max(c100.g, c100.b));
    float b010 = max(c010.r, max(c010.g, c010.b));
    float b110 = max(c110.r, max(c110.g, c110.b));
    float b001 = max(c001.r, max(c001.g, c001.b));
    float b101 = max(c101.r, max(c101.g, c101.b));
    float b011 = max(c011.r, max(c011.g, c011.b));
    float b111 = max(c111.r, max(c111.g, c111.b));

    // Threshold for considering a neighbor "Lit"
    float threshold = 0.001;

    if (b000 > threshold) validWeight += w000;
    if (b100 > threshold) validWeight += w100;
    if (b010 > threshold) validWeight += w010;
    if (b110 > threshold) validWeight += w110;
    if (b001 > threshold) validWeight += w001;
    if (b101 > threshold) validWeight += w101;
    if (b011 > threshold) validWeight += w011;
    if (b111 > threshold) validWeight += w111;

    // Prevent division by zero + edge smoothing
    validWeight = max(validWeight, threshold*pow(10, LPV_AO_CONTROL_EDGE_SMOOTHNESS));

    // No AO interpolated result
    vec4 fixedResult = standardResult / validWeight;


    // 3. MIX BOTH VERSION FOR ARTISTIC CONTROL
    #ifdef LPV_AO_CONTROL_LEAK_FIX_TRADEOFF
        return mix(standardResult, fixedResult, (1.0-LPV_AO_STRENGTH)*validWeight);
    #else
        return mix(standardResult, fixedResult, 1.0-LPV_AO_STRENGTH);
    #endif
}

vec4 SampleLpvLinear(const in vec3 lpvPos) {
    vec3 texcoord = lpvPos / LpvSize3;

    vec4 lpvSample = (frameCounter % 2) == 0
        ? textureLod(texLpv1, texcoord, 0)
        : textureLod(texLpv2, texcoord, 0);

    // Apply brightness curve
    vec3 hsv = RgbToHsv(lpvSample.rgb);
    hsv.z = lpvCurve(hsv.b) * LpvBlockSkyRange.x;
    lpvSample.rgb = HsvToRgb(hsv);
    
    lpvSample.rgb = clamp(lpvSample.rgb/15.0,0.0,1.0);
    // Isn't `lpvSample.rgb = lpvSample.rgb / 15.0` enough?

    return lpvSample;
}

vec4 SampleLpv(const in vec3 lpvPos) {
    #ifdef LPV_AO_CONTROL
        // Smart software interpolation
        vec4 lpvSample = (frameCounter % 2) == 0
            ? SampleLpvSmart(texLpv1, lpvPos)
            : SampleLpvSmart(texLpv2, lpvPos);
    #else
        // Linear hardware interpolation
        vec3 texcoord = lpvPos / LpvSize3;

        vec4 lpvSample = (frameCounter % 2) == 0
            ? textureLod(texLpv1, texcoord, 0)
            : textureLod(texLpv2, texcoord, 0);
    #endif

    // Apply brightness curve
    vec3 hsv = RgbToHsv(lpvSample.rgb);
    hsv.z = lpvCurve(hsv.b) * LpvBlockSkyRange.x;
    lpvSample.rgb = HsvToRgb(hsv);

    lpvSample.rgb = clamp(lpvSample.rgb / 15.0, 0.0, 1.0);
    // Isn't `lpvSample.rgb = lpvSample.rgb / 15.0` enough?
    
    return lpvSample;
}

vec3 GetLpvBlockLight(const in vec4 lpvSample) {
    return LpvBlockBrightness * lpvSample.rgb;
}

float GetLpvSkyLight(const in vec4 lpvSample) {
    float skyLight = saturate(lpvSample.a);
    return skyLight*skyLight;
}
