//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

const mat3 ACESInputMat =
mat3(0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
const mat3 ACESOutputMat =
mat3( 1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);
vec3 LinearTosRGB(in vec3 color)
{
    vec3 x = color * 12.92f;
    vec3 y = 1.055f * pow(clamp(color,0.0,1.0), vec3(1.0f / 2.4f)) - 0.055f;

    vec3 clr = color;
    clr.r = color.r < 0.0031308f ? x.r : y.r;
    clr.g = color.g < 0.0031308f ? x.g : y.g;
    clr.b = color.b < 0.0031308f ? x.b : y.b;

    return clr;
}
vec3 ToneMap_Hejl2015(in vec3 hdr)
{
    vec4 vh = vec4(hdr*0.85, 3.0);	//0
    vec4 va = (1.75 * vh) + 0.05;	//0.05
    vec4 vf = ((vh * va + 0.004f) / ((vh * (va + 0.55f) + 0.0491f))) - 0.0821f+0.000633604888;	//((0+0.004)/((0*(0.05+0.55)+0.0491)))-0.0821
    return vf.xyz / vf.www;
}
vec3 HableTonemap(vec3 linearColor) {
	// A = shoulder strength
	const float A = 0.45;
	// B = linear strength
	const float B = 0.28;
	// C = linear angle
	const float C = 0.1;
	// D = toe strength
	const float D = 0.5;
	// E = toe numerator
	const float E = 0.01;
	// F = toe denominator
	const float F = 0.3;
	// Note: E / F = toe angle
	// linearWhite = linear white point value

	vec3 x = linearColor*2.0;
	vec3 color = ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;

	const float W = 11.0;
	const float white = ((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F;

	return color / white;
}

vec3 reinhard(vec3 x){
x *= 1.66;
return x/(1.0+x);
}
vec3 ACESFilm( vec3 x )
{
		x*=0.9;
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
		return (x*(a*x+b))/(x*(c*x+d)+e);
}

// From https://www.shadertoy.com/view/WdjSW3
vec3 Tonemap_Lottes(vec3 x) {
    // Lottes 2016, "Advanced Techniques and Optimization of HDR Color Pipelines"
		const float a = 1.6;
    const float d = 0.977;
    const float hdrMax = 8.0;
    const float midIn = 0.23;
    const float midOut = 0.267;

    // Can be precomputed
    const float b =
        (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
    const float c =
        (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

    return pow(x,vec3(a)) / (pow(x, vec3(a * d)) * b + c);
}
vec3 curve(vec3 x){
    return 1.0 - x/(1.0+x);
}
vec3 Tonemap_Uchimura_Modified(vec3 x, float P, float a, float m, float l, float c, float b) {
    // Uchimura 2017, "HDR theory and practice"
    // Math: https://www.desmos.com/calculator/gslcdxvipg
    // Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = C2 / P;

    vec3 w0 = 1.0 - smoothstep(x, vec3(0.0), vec3(m));
    vec3 w2 = step(m + l0, x);
    vec3 w1 = 1.0 - w0 - w2;

    vec3 T = m * pow(x / m, vec3(c)) + b;
    vec3 S = P - (P - S1) * curve(CP * (x - S0));
    vec3 L = m + a * (x - m);

    return clamp(T * w0 + L * w1 + S * w2,0.0,1.0);
}
// From https://www.shadertoy.com/view/WdjSW3
vec3 Tonemap_Uchimura(vec3 x, float P, float a, float m, float l, float c, float b) {
    // Uchimura 2017, "HDR theory and practice"
    // Math: https://www.desmos.com/calculator/gslcdxvipg
    // Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;

    vec3 w0 = 1.0 - smoothstep(x, vec3(0.0), vec3(m));
    vec3 w2 = step(m + l0, x);
    vec3 w1 = 1.0 - w0 - w2;

    vec3 T = m * pow(x / m, vec3(c)) + b;
    vec3 S = P - (P - S1) * exp(CP * (x - S0));
    vec3 L = m + a * (x - m);

    return clamp(T * w0 + L * w1 + S * w2,0.0,1.0);
}

vec3 Tonemap_Uchimura(vec3 x) {
	const float P = 1.0;  // max display brightness 1.0
	const float a = 1.0;  // contrast 1.0
	const float m = 0.12; // linear section start 0.22
	const float l = 0.22;  // linear section length 0.4
	const float c = 1.5; // black 1.33
	const float b = 0.0;  // pedestal 0.0
    return Tonemap_Uchimura_Modified(x, P, a, m, l, c, b);
}
