#include "/lib/settings.glsl"

#include "/lib/res_params.glsl"


flat varying vec4 exposure;
flat varying vec2 rodExposureDepth;
varying vec2 texcoord;

const bool colortex5MipmapEnabled = true;
// uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex3;
// uniform sampler2D colortex6;
uniform sampler2D colortex7;
// uniform sampler2D colortex8; // specular
uniform sampler2D colortex9; // specular
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform vec2 texelSize;

uniform ivec2 eyeBrightnessSmooth;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform int isEyeInWater;
uniform float near;
uniform float aspectRatio;
uniform float far;
uniform float rainStrength;
uniform float screenBrightness;
uniform vec4 Moon_Weather_properties; // R = cloud coverage 		G = fog density
uniform int hideGUI;

uniform int framemod8;
#include "/lib/TAA_jitter.glsl"


uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
vec4 Weather_properties = Moon_Weather_properties;

#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
// #include "/lib/biome_specifics.glsl"
#include "/lib/bokeh.glsl"

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}

// uniform float viewWidth;
// uniform float viewHeight;

// uniform sampler2D depthtex0;

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
#endif
uniform float dhNearPlane;
uniform float dhFarPlane;

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}

float bloomWeight(){
	
	float weights[7] = float[](     1.0,    1.0/2.0,    1.0/3.0,    1.0/5.5,    1.0/8.0,    1.0/10.0,   1.0/12.0    );
	// float weights[7] = float[](     0.7,    pow(0.5,2), pow(0.5,3),  pow(0.5,4),   pow(0.5,5),    pow(0.5,6), pow(0.5,7)	);

	float result = 0.0;

	for ( int i = 0; i < 7; i++) {
		result += weights[i];
	}

	return result;
}
vec3 invTonemap(vec3 col){
	return col/(1-luma(col));
}
#define linear_to_srgb(x) (pow(x, vec3(1.0/2.2)))

uniform sampler2D colortex6;


float w0(float a)
{
    return (1.0/6.0)*(a*(a*(-a + 3.0) - 3.0) + 1.0);
}

float w1(float a)
{
    return (1.0/6.0)*(a*a*(3.0*a - 6.0) + 4.0);
}

float w2(float a)
{
    return (1.0/6.0)*(a*(a*(-3.0*a + 3.0) + 3.0) + 1.0);
}

float w3(float a)
{
    return (1.0/6.0)*(a*a*a);
}

float g0(float a)
{
    return w0(a) + w1(a);
}

float g1(float a)
{
    return w2(a) + w3(a);
}

float h0(float a)
{
    return -1.0 + w1(a) / (w0(a) + w1(a));
}

float h1(float a)
{
    return 1.0 + w3(a) / (w2(a) + w3(a));
}

vec4 texture2D_bicubic(sampler2D tex, vec2 uv)
{
	vec4 texelSize = vec4(texelSize,1.0/texelSize);
	uv = uv*texelSize.zw;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) * texelSize.xy;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) * texelSize.xy;

    return g0(fuv.y) * (g0x * texture2D(tex, p0)  +
                        g1x * texture2D(tex, p1)) +
           g1(fuv.y) * (g0x * texture2D(tex, p2)  +
                        g1x * texture2D(tex, p3));
}

// vec3 lenseFlare(vec2 UV){
//   float noise = blueNoise();

//   float vignetteLength = 0.2;
//   float vignette =  0.5+length(texcoord-0.5);//min(max(length(texcoord-0.5) - vignetteLength,0.0) / (1.0/(1.0-vignetteLength)),1.0);

//   float aberrationStrength = vignette;//clamp(CHROMATIC_ABERRATION_STRENGTH * 0.01 * (1.0 - vignette),0.0,0.9) * vignette * 0.75;

//   vec2 centeredUV = texcoord - 0.5;

//   vec3 color = vec3(0.0);
//   color = texture2D(colortex7, texcoord).rgb;

//   vec2 distortedUV = (centeredUV -  (centeredUV ) * aberrationStrength) + 0.5;

//   color += texture2D(colortex7,  distortedUV).rgb;
//   // color.r = texture2D(colortex7, (centeredUV - (centeredUV + centeredUV*noise) * aberrationStrength) + 0.5).r;
//   // color.g = texture2D(colortex7, texcoord).g;
//   // color.b = texture2D(colortex7, (centeredUV + (centeredUV + centeredUV*noise) * aberrationStrength) + 0.5).b;

//   return color;
// }

void main() {
  /* DRAWBUFFERS:7 */
	float vignette = (1.5-dot(texcoord-0.5,texcoord-0.5)*2.);
	vec3 col = texture2D(colortex5,texcoord).rgb;

	#if DOF_QUALITY >= 0
		/*--------------------------------*/
		float z = ld(texture2D(depthtex1, texcoord.st*RENDER_SCALE).r)*far;
		#if MANUAL_FOCUS == -2
			float focus = rodExposureDepth.y*far;
		#elif MANUAL_FOCUS == -1
			float focus = mix(pow(512.0, screenBrightness), 512.0 * screenBrightness, 0.25);
		#elif MANUAL_FOCUS > 0
			float focus = MANUAL_FOCUS;
		#endif
		#if DOF_QUALITY < 5
		float pcoc = min(abs(aperture * (focal/100.0 * (z - focus)) / (z * (focus - focal/100.0))),texelSize.x*15.0);
		#ifdef FAR_BLUR_ONLY
			pcoc *= float(z > focus);
		#endif
		#ifdef REMOVE_HAND_BLUR
			pcoc *= float(z > 0.56);
		#endif
		// float noise = blueNoise()*6.28318530718;
		// mat2 noiseM = mat2( cos( noise ), -sin( noise ),
	    //                    sin( noise ), cos( noise )
	    //                      );
		vec3 bcolor = vec3(0.);
		float nb = 0.0;
		vec2 bcoord = vec2(0.0);
		/*--------------------------------*/
		float dofLodLevel = pcoc * 200.0;

		vec2 dispersion = (texcoord - 0.5) * pcoc * 200.0 * DOF_DISPERSION_MULT;

		for ( int i = 0; i < BOKEH_SAMPLES; i++) {
			// bcolor += texture2DLod(colortex5, texcoord.xy + bokeh_offsets[i]*pcoc*vec2(DOF_ANAMORPHIC_RATIO,aspectRatio), dofLodLevel).rgb;
			
			bcolor.r += texture2DLod(colortex5, texcoord.xy + (bokeh_offsets[i] + dispersion)*pcoc*vec2(DOF_ANAMORPHIC_RATIO,aspectRatio), dofLodLevel).r;
			bcolor.g += texture2DLod(colortex5, texcoord.xy + bokeh_offsets[i]*pcoc*vec2(DOF_ANAMORPHIC_RATIO,aspectRatio), dofLodLevel).g;
			bcolor.b += texture2DLod(colortex5, texcoord.xy + (bokeh_offsets[i] - dispersion)*pcoc*vec2(DOF_ANAMORPHIC_RATIO,aspectRatio), dofLodLevel).b;
		}
		col = bcolor/BOKEH_SAMPLES;
		#endif
	#endif

	vec2 clampedRes = max(vec2(viewWidth,viewHeight),vec2(1920.0,1080.));

	vec2 resScale = vec2(1920.,1080.)/clampedRes;
	vec2 bloomTileUV = (((gl_FragCoord.xy)*2.0 + 0.5)*texelSize/2.0) / clampedRes*vec2(1920.,1080.);

	vec3 bloomTile0 = texture2D_bicubic(colortex3, bloomTileUV/2.).rgb; //1/4 res
	vec3 bloomTile1 = texture2D_bicubic(colortex6, bloomTileUV/4.).rgb; //1/8 res
	vec3 bloomTile2 = texture2D_bicubic(colortex6, bloomTileUV/8.+vec2(0.25*resScale.x+2.5*texelSize.x,.0)).rgb;  //1/16 res
	vec3 bloomTile3 = texture2D_bicubic(colortex6, bloomTileUV/16.+vec2(0.375*resScale.x+4.5*texelSize.x,.0)).rgb; //1/32 res
	vec3 bloomTile4 = texture2D_bicubic(colortex6, bloomTileUV/32.+vec2(0.4375*resScale.x+6.5*texelSize.x,.0)).rgb; //1/64 res
	vec3 bloomTile5 = texture2D_bicubic(colortex6, bloomTileUV/64.+vec2(0.46875*resScale.x+8.5*texelSize.x,.0)).rgb; //1/128 res
	vec3 bloomTile6 = texture2D_bicubic(colortex6, bloomTileUV/128.+vec2(0.484375*resScale.x+10.5*texelSize.x,.0)).rgb; //1/256 res

	#ifdef OLD_BLOOM
		vec3 bloom = (bloomTile0 + bloomTile1 + bloomTile2 + bloomTile3 + bloomTile4 + bloomTile5 + bloomTile6) / 7.0;
		vec3 fogBloom = bloom;
		
		float lightScat = clamp((BLOOM_STRENGTH+3) * 0.05 * pow(exposure.a, 0.2)  ,0.0,1.0) * vignette;
	#else
		float weights[7] = float[](     1.0,    1.0/2.0,    1.0/3.0,    1.0/5.5,    1.0/8.0,    1.0/10.0,   1.0/12.0    );
		vec3 bloom = (bloomTile0*weights[0] + bloomTile1*weights[1] + bloomTile2*weights[2] + bloomTile3*weights[3] + bloomTile4*weights[4] + bloomTile5*weights[5] + bloomTile6*weights[6]) / bloomWeight();
		vec3 fogBloom = (bloomTile0 + bloomTile1 + bloomTile2 + bloomTile3 + bloomTile4 + bloomTile5 + bloomTile6) / 7.0;
		
		float lightScat = clamp(BLOOM_STRENGTH * 0.3,0.0,1.0) * vignette;
	#endif

	#ifdef AUTO_EXPOSURE
		float purkinje = clamp(exposure.a*exposure.a,0.0,1.0) * clamp(rodExposureDepth.x/(1.0+rodExposureDepth.x)*Purkinje_strength,0,1);
	#else
		float purkinje = clamp(rodExposureDepth.x/(1.0+rodExposureDepth.x)*Purkinje_strength,0,1);
	#endif	
	

 	float VL_abs = texture2D(colortex7, texcoord*RENDER_SCALE).r;

  	VL_abs = clamp((1.0-VL_abs)*BLOOMY_FOG*0.75*(1.0+rainStrength) * (1.0-purkinje*0.3),0.0,1.0)*clamp(1.0-pow(cdist(texcoord.xy),15.0),0.0,1.0);
	
	col = (mix(col, fogBloom, VL_abs) + bloom*lightScat) * exposure.rgb;
	
  	float lum = dot(col, vec3(0.15,0.3,0.55));
	float lum2 = dot(col, vec3(0.85,0.7,0.45));
	float rodLum = lum2*200.0;
	float rodCurve = clamp(mix(1.0, rodLum/(2.5+rodLum), purkinje),0.0,1.0);

	col = mix(lum * vec3(Purkinje_R, Purkinje_G, Purkinje_B) * Purkinje_Multiplier, col, rodCurve);

	#ifndef USE_ACES_COLORSPACE_APPROXIMATION
		col = LinearTosRGB(TONEMAP(col));
	#else
		col = col * ACESInputMat;
		col = TONEMAP(col);

		col = LinearTosRGB(clamp(col * ACESOutputMat, 0.0, 1.0));
	#endif

	gl_FragData[0].rgb = clamp(int8Dither(col,texcoord),0.0,1.0);
	
	#if DOF_QUALITY == 5
		#if FOCUS_LASER_COLOR == 0 // Red
		vec3 laserColor = vec3(25, 0, 0);
		#elif FOCUS_LASER_COLOR == 1 // Green
		vec3 laserColor = vec3(0, 25, 0);
		#elif FOCUS_LASER_COLOR == 2 // Blue
		vec3 laserColor = vec3(0, 0, 25);
		#elif FOCUS_LASER_COLOR == 3 // Pink
		vec3 laserColor = vec3(25, 10, 15);
		#elif FOCUS_LASER_COLOR == 4 // Yellow
		vec3 laserColor = vec3(25, 25, 0);
		#elif FOCUS_LASER_COLOR == 5 // White
		vec3 laserColor = vec3(25);
		#endif
		float depth = texture(depthtex0, texcoord).r;
		
		#ifdef DISTANT_HORIZONS
		float _near = near;
		float _far = far*4.0;

		if (depth >= 1.0) {
			depth = texture2D(dhDepthTex, texcoord).x;
			_near = dhNearPlane;
			_far = dhFarPlane;
		}

		depth = linearizeDepthFast(depth, _near, _far);
		#else
		depth = linearizeDepthFast(depth, near, far);
		#endif

		// focus = gl_FragCoord.x * 0.1;
		if( hideGUI < 1) gl_FragData[0].rgb += laserColor * pow( clamp( 	 1.0-abs(focus-abs(depth))		,0,1),25) ;
	#endif
}