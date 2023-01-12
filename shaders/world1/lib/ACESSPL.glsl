#define log10(x) log(x) / log(10.0)


struct SegmentedSplineParams_c5 {
	float coefsLow[6];    // coefs for B-spline between minPoint and midPoint (units of log luminance)
	float coefsHigh[6];   // coefs for B-spline between midPoint and maxPoint (units of log luminance)
	vec2 minPoint; // {luminance, luminance} linear extension below this
	vec2 midPoint; // {luminance, luminance} 
	vec2 maxPoint; // {luminance, luminance} linear extension above this
	float slopeLow;       // log-log slope of low linear extension
	float slopeHigh;      // log-log slope of high linear extension
};

struct SegmentedSplineParams_c9 {
	float coefsLow[10];    // coefs for B-spline between minPoint and midPoint (units of log luminance)
	float coefsHigh[10];   // coefs for B-spline between midPoint and maxPoint (units of log luminance)
	float slopeLow;       // log-log slope of low linear extension
	float slopeHigh;      // log-log slope of high linear extension
};

const mat3 M = mat3(
	 0.5, -1.0,  0.5,
	-1.0,  1.0,  0.5,
	 0.5,  0.0,  0.0
);

float segmented_spline_c5_fwd(float x) {
	const SegmentedSplineParams_c5 C = SegmentedSplineParams_c5(
		float[6] ( -4.0000000000, -4.0000000000, -3.1573765773, -0.4852499958, 1.8477324706, 1.8477324706 ),
		float[6] ( -0.7185482425, 2.0810307172, 3.6681241237, 4.0000000000, 4.0000000000, 4.0000000000 ),
		vec2(0.18*exp2(-15.0), 0.0001),
		vec2(0.18,              4.8),
		vec2(0.18*exp2(18.0),  10000.),
		0.0,
		0.0
	);

	const int N_KNOTS_LOW = 4;
	const int N_KNOTS_HIGH = 4;

	// Check for negatives or zero before taking the log. If negative or zero,
	// set to ACESMIN.1
	float xCheck = x <= 0 ? exp2(-14.0) : x;

	float logx = log10( xCheck);
	float logy;

	if (logx <= log10(C.minPoint.x)) {
		logy = logx * C.slopeLow + (log10(C.minPoint.y) - C.slopeLow * log10(C.minPoint.x));
	} else if ((logx > log10(C.minPoint.x)) && (logx < log10(C.midPoint.x))) {
		float knot_coord = (N_KNOTS_LOW-1) * (logx-log10(C.minPoint.x))/(log10(C.midPoint.x)-log10(C.minPoint.x));
		int j = int(knot_coord);
		float t = knot_coord - float(j);

		vec3 cf = vec3( C.coefsLow[ j], C.coefsLow[ j + 1], C.coefsLow[ j + 2]);
    
		vec3 monomials = vec3(t * t, t, 1.0);
		logy = dot( monomials, M * cf);
	} else if ((logx >= log10(C.midPoint.x)) && (logx < log10(C.maxPoint.x))) {
		float knot_coord = (N_KNOTS_HIGH - 1) * (logx - log10(C.midPoint.x)) / (log10(C.maxPoint.x) - log10(C.midPoint.x));
		int j = int(knot_coord);
		float t = knot_coord - float(j);

		vec3 cf = vec3(C.coefsHigh[j], C.coefsHigh[j + 1], C.coefsHigh[j + 2]);
		vec3 monomials = vec3(t * t, t, 1.0);
		
		logy = dot(monomials, M * cf);
	} else {
		logy = logx * C.slopeHigh + (log10(C.maxPoint.y) - C.slopeHigh * log10(C.maxPoint.x));
	}

	return pow(10.0, logy);
}

float segmented_spline_c9_fwd( float x, const SegmentedSplineParams_c9 C, const mat3x2 toningPoints) {
	const int N_KNOTS_LOW = 8;
	const int N_KNOTS_HIGH = 8;

	// Check for negatives or zero before taking the log. If negative or zero,
	// set to OCESMIN.
	float xCheck = x <= 0 ? 1e-4 : x;

	vec2 minPoint = toningPoints[0];
	vec2 midPoint = toningPoints[1];
	vec2 maxPoint = toningPoints[2];

	float logx = log10(xCheck);
	float logy;

	if (logx <= log10(minPoint.x)) {
		logy = logx * C.slopeLow + (log10(minPoint.y) - C.slopeLow * log10(minPoint.x));
	} else if ((logx > log10(minPoint.x)) && (logx < log10(midPoint.x))) {
		float knot_coord = (N_KNOTS_LOW - 1) * (logx - log10(minPoint.x)) / (log10(midPoint.x) - log10(minPoint.x));
		int j = int(knot_coord);
		float t = knot_coord - float(j);

		vec3 cf = vec3(C.coefsLow[j], C.coefsLow[j + 1], C.coefsLow[j + 2]);
		vec3 monomials = vec3(t * t, t, 1.0);
		
		logy = dot(monomials, M * cf);
	} else if ((logx >= log10(midPoint.x)) && (logx < log10(maxPoint.x))) {
		float knot_coord = (N_KNOTS_HIGH - 1) * (logx - log10(midPoint.x)) / (log10(maxPoint.x) - log10(midPoint.x));
		int j = int(knot_coord);
		float t = knot_coord - float(j);

		vec3 cf = vec3(C.coefsHigh[j], C.coefsHigh[j + 1], C.coefsHigh[j + 2]);
		vec3 monomials = vec3(t * t, t, 1.0);
		
		logy = dot(monomials, M * cf);
	} else {
		logy = logx * C.slopeHigh + (log10(maxPoint.y) - C.slopeHigh * log10(maxPoint.x));
	}

	return pow(10.0, logy);
}