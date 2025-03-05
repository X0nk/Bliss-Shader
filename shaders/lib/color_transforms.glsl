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
vec3 LinearTosRGB(in vec3 color){
	vec3 x = color * 12.92f;
	vec3 y = 1.055f * pow(clamp(color,0.0,1.0), vec3(1.0f / 2.4f)) - 0.055f;

	vec3 clr = color;
	clr.r = color.r < 0.0031308f ? x.r : y.r;
	clr.g = color.g < 0.0031308f ? x.g : y.g;
	clr.b = color.b < 0.0031308f ? x.b : y.b;

	return clr;
}

vec3 ToneMap_Hejl2015(in vec3 hdr){
    vec4 vh = vec4(hdr*0.85, 3.0); //0
    vec4 va = (1.75 * vh) + 0.05; //0.05
    vec4 vf = ((vh * va + 0.004f) / ((vh * (va + 0.55f) + 0.0491f))) - 0.0821f+0.000633604888; //((0+0.004)/((0*(0.05+0.55)+0.0491)))-0.0821
    return vf.xyz / vf.www;
}

vec3 HableTonemap(vec3 linearColor){
	// A = shoulder strength
	const float A = 0.6;
	// B = linear strength
	const float B = 0.5;
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

vec3 ACESFilm(vec3 x){
	x*=0.9;
	// slower rate to bright color
	float a = 2.51f;
	float b = 0.03f;
	float c = 2.43f;
	float d = 0.95f;
	float e = 0.12f;
	return (x*(a*x+b))/(x*(c*x+d)+e);
}

// From https://www.shadertoy.com/view/WdjSW3
vec3 Tonemap_Lottes(vec3 x){
	// Lottes 2016, "Advanced Techniques and Optimization of HDR Color Pipelines"
	const float a = 1.6;
	const float d = 0.977;
	const float hdrMax = 8.0;
	const float midIn = 0.23;
	const float midOut = 0.267;

	// Can be precomputed
	const float b = (-pow(midIn, a) + pow(hdrMax, a) * midOut) / ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
	const float c = (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) / ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

	return pow(x,vec3(a)) / (pow(x, vec3(a * d)) * b + c);
}

vec3 curve(vec3 x){
	return 1.0 - x/(1.0+x);
}

vec3 Tonemap_Uchimura_Modified(vec3 x, float P, float a, float m, float l, float c, float b){
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
vec3 Tonemap_Uchimura(vec3 x, float P, float a, float m, float l, float c, float b){
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

vec3 Tonemap_Uchimura(vec3 x){
	const float P = 1.0;  // max display brightness 1.0
	const float a = 1.0;  // contrast 1.0
	const float m = 0.12; // linear section start 0.22
	const float l = 0.22;  // linear section length 0.4
	const float c = 1.0; // black 1.33
	const float b = 0.0;  // pedestal 0.0
	return Tonemap_Uchimura_Modified(x, P, a, m, l, c, b);
}

vec3 Tonemap_Xonk(vec3 Color){
	Color = pow(Color,vec3(1.3));

	return Color / (0.333 + Color);
	// return pow(Color / (0.333 + Color), vec3(1.1));
}

vec3 Tonemap_Full_Reinhard(vec3 C){

	float whitepoint = 10.0;
	float lighten = 0.5;

	return (C * (1.0 + C / (whitepoint*whitepoint))) / (lighten + C);
}

vec3 Full_Reinhard_Edit(vec3 C){

	C = pow(C,vec3(1.2));
	float whitepoint = 10.0;
	float lighten = 0.333;

	return (C * (1.0 + C / (whitepoint*whitepoint))) / (lighten + C);
}

vec3 Tonemap_Ozius(vec3 C){
	const vec3 a = vec3(0.46, 0.46, 0.46);
	const vec3 b = vec3(0.60, 0.60, 0.60);

	C *= 1.6;

	vec3 cr = mix(vec3(dot(C, vec3(0.2722, 0.6741, 0.0537))), C, 0.5) + 1.0;

	C = pow(C / (1.0 + C), a);
	return pow(C * C * (-2.0 * C + 3.0), cr / b);
}

// from https://iolite-engine.com/blog_posts/minimal_agx_implementation
// MIT License
//
// Copyright (c) 2024 Missing Deadlines (Benjamin Wrensch)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// All values used to derive this implementation are sourced from Troy’s initial AgX implementation/OCIO config file available here:
// https://github.com/sobotka/AgX

// AND

/// from https://github.com/donmccurdy/three.js/blob/dev/src/renderers/shaders/ShaderChunk/tonemapping_pars_fragment.glsl.js
// AgX Tone Mapping implementation based on Filament, which in turn is based
// on Blender's implementation using rec 2020 primaries
// https://github.com/google/filament/pull/7236

// Inputs and outputs are encoded as Linear-sRGB.
// https://iolite-engine.com/blog_posts/minimal_agx_implementation
// Mean error^2: 3.6705141e-06
vec3 agxDefaultContrastApprox(vec3 x){
	return x*(+0.1241
		+x*(+0.2079
		+x*(-5.9293
		+x*(+30.3768
		+x*(-38.9015
		+x*(+15.1221))))));
}

#ifdef WF99_AGX_PRESET
	vec3 oContrast = vec3(1.175);
	float oSaturation = 0.99;
#else
	vec3 oContrast = vec3(1.0);
	float oSaturation = 1.25;
#endif

vec3 ToneMap_AgX(vec3 color){
	mat3 i = mat3(0.8566, 0.1373,  0.1119, 0.0951, 0.7612, 0.0768, 0.0483, 0.1014, 0.8113);

	// Log2 encoding
	color = (clamp(log2(i * color), -12.4739, 4.0261) +12.4739) / 16.5;

	// Apply sigmoid
	color = agxDefaultContrastApprox(color);

	// Apply AgX look
	color = mix(vec3(dot(color, vec3(0.2126,0.7152,0.0722))), pow(color, oContrast), oSaturation);

  	// Eotf
  	mat3 o = mat3(1.1271, -0.1413, -0.1413, -0.1106, 1.1578, -0.1106, -0.0165, -0.0165, 1.2519);

	// Linearize
	color = pow(max(vec3(0.0), o * color), vec3(2.2));

	// Gamut mapping. Simple clamp for now.  
	return clamp(color, 0.0, 1.0);
}

vec3 ToneMap_AgX_minimal(vec3 color) {
	mat3 i = mat3(0.8425, 0.0423, 0.0424, 0.0784, 0.8785, 0.0784, 0.0792, 0.0792, 0.8791);

	color = (clamp(log2(i * color), -12.4739, 4.0261) +12.4739) / 16.5;

	color = agxDefaultContrastApprox(color);

	color = mix(vec3(dot(color, vec3(0.2126,0.7152,0.0722))), pow(color, oContrast), oSaturation);

  	mat3 o = mat3(1.1969, -0.0529, -0.0530, -0.0980, 1.1519, -0.0980, -0.0990, -0.0990, 1.1511);
  
	color = pow(o * color, vec3(2.2));

	return clamp(color, 0.0, 1.0);
}