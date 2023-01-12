#define TIME_MULT 1.0
#define TIME (frameTimeCounter * TIME_MULT)

const float PI 		= acos(-1.0);
const float TAU 	= PI * 2.0;
const float hPI 	= PI * 0.5;
const float rPI 	= 1.0 / PI;
const float rTAU 	= 1.0 / TAU;

const float PHI		= sqrt(5.0) * 0.5 + 0.5;
const float rLOG2	= 1.0 / log(2.0);

const float goldenAngle = TAU / PHI / PHI;

#define clamp01(x) clamp(x, 0.0, 1.0)
#define max0(x) max(x, 0.0)
#define min0(x) min(x, 0.0)
#define max3(a) max(max(a.x, a.y), a.z)
#define min3(a) min(min(a.x, a.y), a.z)
#define max4(a, b, c, d) max(max(a, b), max(c, d))
#define min4(a, b, c, d) min(min(a, b), min(c, d))

#define fsign(x) (clamp01(x * 1e35) * 2.0 - 1.0)
#define fstep(x,y) clamp01((y - x) * 1e35)

#define diagonal2(m) vec2((m)[0].x, (m)[1].y)
#define diagonal3(m) vec3(diagonal2(m), m[2].z)
#define diagonal4(m) vec4(diagonal3(m), m[2].w)

#define transMAD(mat, v) (mat3(mat) * (v) + (mat)[3].xyz)
#define projMAD(mat, v) (diagonal3(mat) * (v) + (mat)[3].xyz)

#define encodeColor(x) (x * 0.00005)
#define decodeColor(x) (x * 20000.0)

#define cubeSmooth(x) (x * x * (3.0 - 2.0 * x))

#define lumCoeff vec3(0.2125, 0.7154, 0.0721)

float facos(const float sx){
    float x = clamp(abs( sx ),0.,1.);
    float a = sqrt( 1. - x ) * ( -0.16882 * x + 1.56734 );
    return sx > 0. ? a : PI - a;
    //float c = clamp(-sx * 1e35, 0., 1.);
    //return c * pi + a * -(c * 2. - 1.); //no conditional version
}


vec2 sincos(float x){
    return vec2(sin(x), cos(x));
}

vec2 circlemap(float i, float n){
	return sincos(i * n * goldenAngle) * sqrt(i);
}

vec3 circlemapL(float i, float n){
	return vec3(sincos(i * n * goldenAngle), sqrt(i));
}

vec3 calculateRoughSpecular(const float i, const float alpha2, const int steps) {

    float x = (alpha2 * i) / (1.0 - i);
    float y = i * float(steps) * 64.0 * 64.0 * goldenAngle;

    float c = inversesqrt(x + 1.0);
    float s = sqrt(x) * c;

    return vec3(cos(y) * s, sin(y) * s, c);
}

vec3 clampNormal(vec3 n, vec3 v){
    float NoV = clamp( dot(n, -v), 0., 1. );
    return normalize( NoV * v + n );
}

vec3 srgbToLinear(vec3 srgb){
    return mix(
        srgb / 12.92,
        pow(.947867 * srgb + .0521327, vec3(2.4) ),
        step( .04045, srgb )
    );
}

vec3 linearToSRGB(vec3 linear){
    return mix(
        linear * 12.92,
        pow(linear, vec3(1./2.4) ) * 1.055 - .055,
        step( .0031308, linear )
    );
}



vec3 blackbody(float Temp)
{
    float t = pow(Temp, -1.5);
    float lt = log(Temp);

    vec3 col = vec3(0.0);
         col.x = 220000.0 * t + 0.58039215686;
         col.y = 0.39231372549 * lt - 2.44549019608;
         col.y = Temp > 6500. ? 138039.215686 * t + 0.72156862745 : col.y;
         col.z = 0.76078431372 * lt - 5.68078431373;
         col = clamp01(col);
         col = Temp < 1000. ? col * Temp * 0.001 : col;

    return srgbToLinear(col);
}

float calculateHardShadows(float shadowDepth, vec3 shadowPosition, float bias) {
    if(shadowPosition.z >= 1.0) return 1.0;

    return 1.0 - fstep(shadowDepth, shadowPosition.z - bias);
}

vec3 genUnitVector(vec2 xy) {
    xy.x *= TAU; xy.y = xy.y * 2.0 - 1.0;
    return vec3(sincos(xy.x) * sqrt(1.0 - xy.y * xy.y), xy.y);
}

vec2 rotate(vec2 x, float r){
    vec2 sc = sincos(r);
    return mat2(sc.x, -sc.y, sc.y, sc.x) * x;
}

vec3 cartToSphere(vec2 coord) {
	coord *= vec2(TAU, PI);
	vec2 lon = sincos(coord.x) * sin(coord.y);
	return vec3(lon.x, 2.0/PI*coord.y-1.0, lon.y);
}

vec2 sphereToCart(vec3 dir) {
    float lonlat = atan(-dir.x, -dir.z);
    return vec2(lonlat * rTAU +0.5,0.5*dir.y+0.5);
}

mat3 getRotMat(vec3 x,vec3 y){
    float d = dot(x,y);
    vec3 cr = cross(y,x);

    float s = length(cr);

    float id = 1.-d;

    vec3 m = cr/s;

    vec3 m2 = m*m*id+d;
    vec3 sm = s*m;

    vec3 w = (m.xy*id).xxy*m.yzz;

    return mat3(
        m2.x,     w.x-sm.z, w.y+sm.y,
        w.x+sm.z, m2.y,     w.z-sm.x,
        w.y-sm.y, w.z+sm.x, m2.z
    );
}

// No intersection if returned y component is < 0.0
vec2 rsi(vec3 position, vec3 direction, float radius) {
	float PoD = dot(position, direction);
	float radiusSquared = radius * radius;

	float delta = PoD * PoD + radiusSquared - dot(position, position);
	if (delta < 0.0) return vec2(-1.0);
	      delta = sqrt(delta);

	return -PoD + vec2(-delta, delta);
}
float HaltonSeq3(int index)
    {
        float r = 0.;
        float f = 1.;
        int i = index;
        while (i > 0)
        {
            f /= 3.0;
            r += f * (i % 3);
            i = int(i / 3.0);
        }
        return r;
    }
float HaltonSeq2(int index)
    {
        float r = 0.;
        float f = 1.;
        int i = index;
        while (i > 0)
        {
            f /= 2.0;
            r += f * (i % 2);
            i = int(i / 2.0);
        }
        return r;
    }
