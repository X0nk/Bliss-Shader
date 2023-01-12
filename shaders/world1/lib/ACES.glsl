#define log10(x) log(x) / log(10.0)

    struct ColorCorrection {
	float saturation;
	float vibrance;
	vec3 lum;
	float contrast;
	float contrastMidpoint;

	vec3 gain;
	vec3 lift;
	vec3 InvGamma;
} m;


float sigmoid_shaper(float x) { // Sigmoid function in the range 0 to 1 spanning -2 to +2.
	float t = max(1.0 - abs(0.5 * x), 0.0);
	float y = 1.0 + sign(x) * (1.0 - t * t);

	return 0.5 * y;
}

float rgb_2_saturation(vec3 rgb) {
	float minrgb = min(min(rgb.r, rgb.g), rgb.b);
	float maxrgb = max(max(rgb.r, rgb.g), rgb.b);

	return (max(maxrgb, 1e-10) - max(minrgb, 1e-10)) / max(maxrgb, 1e-2);
}

float rgb_2_yc(vec3 rgb) { // Converts RGB to a luminance proxy, here called YC. YC is ~ Y + K * Chroma.
	float ycRadiusWeight = 1.75;
	float r = rgb[0]; float g = rgb[1]; float b = rgb[2];
	float chroma = sqrt(b * (b - g) + g * (g - r) + r * (r - b));

	return (b + g + r + ycRadiusWeight * chroma) / 3.0;
}

float glow_fwd(float ycIn, float glowGainIn, float glowMid) {
	float glowGainOut;

	if (ycIn <= 2.0 / 3.0 * glowMid) {
		glowGainOut = glowGainIn;
	} else if ( ycIn >= 2.0 * glowMid) {
		glowGainOut = 0;
	} else {
		glowGainOut = glowGainIn * (glowMid / ycIn - 0.5);
	}

	return glowGainOut;
}

float rgb_2_hue(vec3 rgb) { // Returns a geometric hue angle in degrees (0-360) based on RGB values.
	float hue;
	if (rgb[0] == rgb[1] && rgb[1] == rgb[2]) { // For neutral colors, hue is undefined and the function will return a quiet NaN value.
		hue = 0;
	} else {
		hue = (180.0 / 3.1415) * atan(2.0 * rgb[0] - rgb[1] - rgb[2], sqrt(3.0) * (rgb[1] - rgb[2])); // flip due to opengl spec compared to hlsl
	}

	if (hue < 0.0)
		hue = hue + 360.0;

	return clamp(hue, 0.0, 360.0);
}

float center_hue(float hue, float centerH) {
	float hueCentered = hue - centerH;

	if (hueCentered < -180.0) {
		hueCentered += 360.0;
	} else if (hueCentered > 180.0) {
		hueCentered -= 360.0;
	}

	return hueCentered;
}

// Transformations between CIE XYZ tristimulus values and CIE x,y
// chromaticity coordinates
vec3 XYZ_2_xyY( vec3 XYZ ) {
	float divisor = max(XYZ[0] + XYZ[1] + XYZ[2], 1e-10);

	vec3 xyY    = XYZ.xyy;
	     xyY.rg = XYZ.rg / divisor;

	return xyY;
}

vec3 xyY_2_XYZ(vec3 xyY) {
	vec3 XYZ   = vec3(0.0);
	     XYZ.r = xyY.r * xyY.b / max(xyY.g, 1e-10);
	     XYZ.g = xyY.b;
	     XYZ.b = (1.0 - xyY.r - xyY.g) * xyY.b / max(xyY.g, 1e-10);

	return XYZ;
}

mat3 ChromaticAdaptation( vec2 src_xy, vec2 dst_xy ) {
	// Von Kries chromatic adaptation

	// Bradford
	const mat3 ConeResponse = mat3(
		 vec3(0.8951,  0.2664, -0.1614),
		vec3(-0.7502,  1.7135,  0.0367),
		 vec3(0.0389, -0.0685,  1.0296)
	);
	const mat3 InvConeResponse = mat3(
		vec3(0.9869929, -0.1470543,  0.1599627),
		vec3(0.4323053,  0.5183603,  0.0492912),
		vec3(-0.0085287,  0.0400428,  0.9684867)
	);

	vec3 src_XYZ = xyY_2_XYZ( vec3( src_xy, 1 ) );
	vec3 dst_XYZ = xyY_2_XYZ( vec3( dst_xy, 1 ) );

	vec3 src_coneResp = src_XYZ * ConeResponse;
	vec3 dst_coneResp = dst_XYZ *  ConeResponse;

	mat3 VonKriesMat = mat3(
		vec3(dst_coneResp[0] / src_coneResp[0], 0.0, 0.0),
		vec3(0.0, dst_coneResp[1] / src_coneResp[1], 0.0),
		vec3(0.0, 0.0, dst_coneResp[2] / src_coneResp[2])
	);

	return (ConeResponse * VonKriesMat) * InvConeResponse;
}

/*******************************************************************************
 - Color CorrectionUE4 Style
 ******************************************************************************/

 // Accurate for 1000K < Temp < 15000K
// [Krystek 1985, "An algorithm to calculate correlated colour temperature"]
vec2 PlanckianLocusChromaticity(float Temp) {
	float u = ( 0.860117757f + 1.54118254e-4f * Temp + 1.28641212e-7f * Temp*Temp ) / ( 1.0f + 8.42420235e-4f * Temp + 7.08145163e-7f * Temp*Temp );
	float v = ( 0.317398726f + 4.22806245e-5f * Temp + 4.20481691e-8f * Temp*Temp ) / ( 1.0f - 2.89741816e-5f * Temp + 1.61456053e-7f * Temp*Temp );

	float x = 3.0*u / ( 2.0*u - 8.0*v + 4.0 );
	float y = 2.0*v / ( 2.0*u - 8.0*v + 4.0 );

	return vec2(x, y);
}

 vec2 D_IlluminantChromaticity(float Temp) {
	// Accurate for 4000K < Temp < 25000K
	// in: correlated color temperature
	// out: CIE 1931 chromaticity
	// Correct for revision of Plank's law
	// This makes 6500 == D65
	Temp *= 1.4388 / 1.438;

	float x =	Temp <= 7000 ?
				0.244063 + ( 0.09911e3 + ( 2.9678e6 - 4.6070e9 / Temp ) / Temp ) / Temp :
				0.237040 + ( 0.24748e3 + ( 1.9018e6 - 2.0064e9 / Temp ) / Temp ) / Temp;

	float y = -3 * x*x + 2.87 * x - 0.275;

	return vec2(x,y);
}

vec2 PlanckianIsothermal( float Temp, float Tint ) {
	float u = ( 0.860117757f + 1.54118254e-4f * Temp + 1.28641212e-7f * Temp*Temp ) / ( 1.0f + 8.42420235e-4f * Temp + 7.08145163e-7f * Temp*Temp );
	float v = ( 0.317398726f + 4.22806245e-5f * Temp + 4.20481691e-8f * Temp*Temp ) / ( 1.0f - 2.89741816e-5f * Temp + 1.61456053e-7f * Temp*Temp );

	float ud = ( -1.13758118e9f - 1.91615621e6f * Temp - 1.53177f * Temp*Temp ) / pow( 1.41213984e6f + 1189.62f * Temp + Temp*Temp, 2.0 );
	float vd = (  1.97471536e9f - 705674.0f * Temp - 308.607f * Temp*Temp ) / pow( 6.19363586e6f - 179.456f * Temp + Temp*Temp , 2.0); //don't pow2 this

	vec2 uvd = normalize( vec2( u, v ) );

	// Correlated color temperature is meaningful within +/- 0.05
	u += -uvd.y * Tint * 0.05;
	v +=  uvd.x * Tint * 0.05;

	float x = 3*u / ( 2*u - 8*v + 4 );
	float y = 2*v / ( 2*u - 8*v + 4 );

	return vec2(x,y);
}

vec3 WhiteBalance(vec3 LinearColor) {
	const float WhiteTemp = float(WHITE_BALANCE);
	const float WhiteTint = 0.0;
	vec2 SrcWhiteDaylight = D_IlluminantChromaticity( WhiteTemp );
	vec2 SrcWhitePlankian = PlanckianLocusChromaticity( WhiteTemp );

	vec2 SrcWhite = WhiteTemp < 4000 ? SrcWhitePlankian : SrcWhiteDaylight;
	const vec2 D65White = vec2(0.31270,  0.32900);

	// Offset along isotherm
	vec2 Isothermal = PlanckianIsothermal( WhiteTemp, WhiteTint ) - SrcWhitePlankian;
	SrcWhite += Isothermal;

	mat3x3 WhiteBalanceMat = ChromaticAdaptation( SrcWhite, D65White );
	WhiteBalanceMat = (sRGB_2_XYZ_MAT * WhiteBalanceMat) * XYZ_2_sRGB_MAT;

	return LinearColor * WhiteBalanceMat * 1.0;
}

/*******************************************************************************
 - ACES Fimic Curve Approx.
 ******************************************************************************/

// ACES settings
const float FilmSlope = Film_Slope; //0.90
const float FilmToe = Film_Toe; //0.55
const float FilmShoulder = Film_Shoulder; //0.25
const float FilmBlackClip = Black_Clip;
const float FilmWhiteClip = White_Clip;
const float BlueCorrection = Blue_Correction;
const float ExpandGamut = Gamut_Expansion;

vec3 FilmToneMap(vec3 LinearColor) {
	const mat3 AP0_2_sRGB = (AP0_2_XYZ_MAT * D60_2_D65_CAT) * XYZ_2_sRGB_MAT;
	const mat3 AP1_2_sRGB = (AP1_2_XYZ_MAT * D60_2_D65_CAT) * XYZ_2_sRGB_MAT;

	const mat3 AP0_2_AP1 = AP0_2_XYZ_MAT * XYZ_2_AP1_MAT;
	const mat3 AP1_2_AP0 = AP1_2_XYZ_MAT * XYZ_2_AP0_MAT;

	vec3 ColorAP1 = LinearColor * AP0_2_AP1;
	float LumaAP1 = dot( ColorAP1, AP1_RGB2Y );

	vec3 ChromaAP1 = ColorAP1 / LumaAP1;

	float ChromaDistSqr = dot( ChromaAP1 - 1, ChromaAP1 - 1 );
	float ExpandAmount = ( 1 - exp2( -4 * ChromaDistSqr ) ) * ( 1 - exp2( -4 * ExpandGamut * LumaAP1*LumaAP1 ) );

	const mat3 Wide_2_XYZ_MAT = mat3(
		vec3(0.5441691,  0.2395926,  0.1666943),
		vec3(0.2394656,  0.7021530,  0.0583814),
		vec3(-0.0023439,  0.0361834,  1.0552183)
	);

	const mat3 Wide_2_AP1 = Wide_2_XYZ_MAT * XYZ_2_AP1_MAT;
	const mat3 ExpandMat = AP1_2_sRGB * Wide_2_AP1;

	vec3 ColorExpand = ColorAP1 * ExpandMat;
	ColorAP1 = mix(ColorAP1, ColorExpand, ExpandAmount);

	const mat3 BlueCorrect = mat3(
		vec3(0.9404372683, -0.0183068787, 0.0778696104),
		vec3(0.0083786969,  0.8286599939, 0.1629613092),
		vec3(0.0005471261, -0.0008833746, 1.0003362486)
	);
	const mat3 BlueCorrectInv = mat3(
		vec3(1.06318,     0.0233956, -0.0865726),
		vec3(-0.0106337,   1.20632,   -0.19569),
		vec3(-0.000590887, 0.00105248, 0.999538)
	);

	const mat3 BlueCorrectAP1    = (AP1_2_AP0 *  BlueCorrect) * AP0_2_AP1;
	const mat3 BlueCorrectInvAP1 = (AP1_2_AP0 * BlueCorrectInv) * AP0_2_AP1;

	// Blue correction
	ColorAP1 = mix(ColorAP1, ColorAP1 *  BlueCorrectAP1, BlueCorrection);

	vec3 ColorAP0 = LinearColor * AP1_2_AP0;

	// "Glow" module constants
	const float RRT_GLOW_GAIN = 0.05;
	const float RRT_GLOW_MID = 0.08;

	float saturation = rgb_2_saturation(ColorAP0);
	float ycIn = rgb_2_yc(ColorAP0);
	float s = sigmoid_shaper((saturation - 0.4) * 5.0);
	float addedGlow = 1.0 + glow_fwd(ycIn, RRT_GLOW_GAIN * s, RRT_GLOW_MID) * 3;
	ColorAP0 *= addedGlow;

	// --- Red modifier --- //
	const float RRT_RED_SCALE = 0.99;
	const float RRT_RED_PIVOT = 0.22;
	const float RRT_RED_HUE   = 0.15;
	const float RRT_RED_WIDTH = 135.0;
	float hue = rgb_2_hue(ColorAP0);
	float centeredHue = center_hue(hue, RRT_RED_HUE);
	float hueWeight = pow(smoothstep(0.0, 1.0, 1.0 - abs(2.0 * centeredHue / RRT_RED_WIDTH)), 2.0);

	ColorAP0.r += hueWeight * saturation * (RRT_RED_PIVOT - ColorAP0.r) * (1.0 - RRT_RED_SCALE);

	// Use ACEScg primaries as working space
	vec3 WorkingColor = ColorAP0 * AP0_2_AP1_MAT * 1.2;
	     WorkingColor = max(vec3(0.0), WorkingColor) * 1.1;
	     WorkingColor = mix(vec3(dot(WorkingColor, AP1_RGB2Y)), WorkingColor, 0.96); // Pre desaturate

	const float ToeScale      = 1.0 + FilmBlackClip - FilmToe;
	const float ShoulderScale = 1.0 + FilmWhiteClip - FilmShoulder;

	const float InMatch  = in_Match;
	const float OutMatch = Out_Match;

	float ToeMatch = 0.0;
	if(FilmToe > 0.8) {
		// 0.18 will be on straight segment
		ToeMatch = (1.0 - FilmToe - OutMatch) / FilmSlope + log10(InMatch);
	} else {
		// 0.18 will be on toe segment
		// Solve for ToeMatch such that input of InMatch gives output of OutMatch.
		const float bt = (OutMatch + FilmBlackClip) / ToeScale - 1.0;
		ToeMatch = log10(InMatch) - 0.5 * log((1.0 + bt) / (1.0 - bt)) * (ToeScale / FilmSlope);
	}

	float StraightMatch = (1.0 - FilmToe) / FilmSlope - ToeMatch;
	float ShoulderMatch = FilmShoulder / FilmSlope - StraightMatch;

	vec3 LogColor = log10(WorkingColor);
	vec3 StraightColor = FilmSlope * (LogColor + StraightMatch);

	vec3 ToeColor		= (-FilmBlackClip) + (2.0 * ToeScale) / (1.0 + exp((-2.0 * FilmSlope / ToeScale) * (LogColor - ToeMatch)));
	vec3 ShoulderColor	= (1.0 + FilmWhiteClip) - (2.0 * ShoulderScale) / (1.0 + exp(( 2.0 * FilmSlope / ShoulderScale) * (LogColor - ShoulderMatch)));

	for(int i = 0; i < 1; ++i) {
		ToeColor[i] = LogColor[i] < ToeMatch ? ToeColor[i] : StraightColor[i];
		ShoulderColor[i] = LogColor[i] > ShoulderMatch ? ShoulderColor[i] : StraightColor[i];
	}

	vec3 t = clamp((LogColor - ToeMatch) / (ShoulderMatch - ToeMatch), 0.0, 1.0);
	     t = ShoulderMatch < ToeMatch ? 1.0 - t : t;
	     t = (3.0 - 2.0 * t) * t * t;

	vec3 ToneColor = mix(ToeColor, ShoulderColor, t);
	     ToneColor = mix(vec3(dot(ToneColor, AP1_RGB2Y)), ToneColor, 0.93); // Post desaturate

	ToneColor = mix(ToneColor, ToneColor * BlueCorrectInvAP1, BlueCorrection);

	// Returning positive AP1 values
	return max(vec3(0.0), ToneColor * AP1_2_sRGB);
}

vec3 Saturation(vec3 color, ColorCorrection m) {
	float grey = dot(color, m.lum);
	return grey + m.saturation * (color - grey);
}

vec3 Vibrance(vec3 color, ColorCorrection m) {
	float maxColor = max(color.r, max(color.g, color.b));
	float minColor = min(color.r, min(color.g, color.b));

	float colorSaturation = maxColor - minColor;

	float grey = dot(color, m.lum);
	color = mix(vec3(grey), color, 1.0 + m.vibrance * (1.0 - sign(m.vibrance) * colorSaturation));

	return color;
}

vec3 LiftGammaGain(vec3 v, ColorCorrection m) {
	vec3 lerpV = clamp(pow(v, m.InvGamma), 0.0, 1.0);
	return m.gain * lerpV + m.lift * (1.0 - lerpV);
}

float LogContrast(float x, const float eps, float logMidpoint, float contrast) {
	float logX = log2(x + eps);
	float adjX = (logX - logMidpoint) / contrast + logMidpoint;

	return max(exp2(adjX) - eps, 0.0);
}

vec3 Contrast(vec3 color, ColorCorrection m) {
	const float contrastEpsilon = 1e-5;

	vec3 ret;
	     ret.x = LogContrast(color.x, contrastEpsilon, log2(0.18), m.contrast);
		 ret.y = LogContrast(color.y, contrastEpsilon, log2(0.18), m.contrast);
		 ret.z = LogContrast(color.z, contrastEpsilon, log2(0.18), m.contrast);

	return ret;
}

vec3 srgbToLinear(vec3 srgb) {
    return mix(
        srgb * 0.07739938080495356, // 1.0 / 12.92 = ~0.07739938080495356
        pow(0.947867 * srgb + 0.0521327, vec3(2.4)),
        step(0.04045, srgb)
    );
}

vec3 linearToSrgb(vec3 linear) {
    return mix(
        linear * 12.92,
        pow(linear, vec3(0.416666666667)) * 1.055 - 0.055, // 1.0 / 2.4 = ~0.416666666667
        step(0.0031308, linear)
    );
}
