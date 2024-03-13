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
// uniform sampler2D colortex9; // specular
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
const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);

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
uniform sampler2D dhDepthTex;
uniform float dhNearPlane;
uniform float dhFarPlane;

// uniform mat4 gbufferProjectionInverse;
uniform mat4 dhProjectionInverse;

vec3 getViewPos() {
    ivec2 uv = ivec2(gl_FragCoord.xy);
    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 texcoord = gl_FragCoord.xy / viewSize;

    vec4 viewPos = vec4(0.0);
    
    float depth = texelFetch(depthtex0, uv, 0).r;

    if (depth < 1.0) {
        vec4 ndcPos = vec4(texcoord, depth, 1.0) * 2.0 - 1.0;
        viewPos = gbufferProjectionInverse * ndcPos;
        viewPos.xyz /= viewPos.w;
    } else {
        depth = texelFetch(dhDepthTex, ivec2(gl_FragCoord.xy), 0).r;
    
        vec4 ndcPos = vec4(texcoord, depth, 1.0) * 2.0 - 1.0;
        viewPos = dhProjectionInverse * ndcPos;
        viewPos.xyz /= viewPos.w;
    }

    return viewPos.xyz;
}

vec3 ACESFilm2(vec3 x){
// float a = 2.51f;
// float b = 0.03f;
// float c = 2.43f;
// float d = 0.59f;
// float e = 0.14f;

	float a = 2.51f; // brightests
	float b = 0.53f; // lower midtones
	float c = 2.43f; // upper midtones
	float d = 0.59f; // upper midtones
	float e = 0.54f; // lowest tones
	return clamp((x*(a*x+b))/(x*(c*x+d)+e),0.0,1.0);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}

#define linear_to_srgb(x) (pow(x, vec3(1.0/2.2)))
void main() {
  /* DRAWBUFFERS:7 */
	float vignette = (1.5-dot(texcoord-0.5,texcoord-0.5)*2.);
	vec3 col = texture2D(colortex5,texcoord).rgb;

	#if DOF_QUALITY >= 0
		/*--------------------------------*/
		float z = ld(texture2D(depthtex0, texcoord.st*RENDER_SCALE).r)*far;
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
		float noise = blueNoise()*6.28318530718;
		mat2 noiseM = mat2( cos( noise ), -sin( noise ),
	                       sin( noise ), cos( noise )
	                         );
		vec3 bcolor = vec3(0.);
		float nb = 0.0;
		vec2 bcoord = vec2(0.0);
		/*--------------------------------*/
		float dofLodLevel = pcoc * 200.0;
		for ( int i = 0; i < BOKEH_SAMPLES; i++) {
			bcolor += texture2DLod(colortex5, texcoord.xy + bokeh_offsets[i]*pcoc*vec2(DOF_ANAMORPHIC_RATIO,aspectRatio), dofLodLevel).rgb;
		}
		col = bcolor/BOKEH_SAMPLES;
		#endif
	#endif

	vec2 clampedRes = max(vec2(viewWidth,viewHeight),vec2(1920.0,1080.));



	vec3 bloom = (texture2D(colortex3,texcoord/clampedRes*vec2(1920.,1080.)*BLOOM_QUALITY).rgb)/2./7.0;

	// vec3 bloom = texture2D(colortex3, texcoord/clampedRes*vec2(1920.,1080.)*BLOOM_QUALITY).rgb / 2.0 / 7.0;

	float lightScat = clamp(BLOOM_STRENGTH  * 0.05 * pow(exposure.a, 0.2)  ,0.0,1.0)*vignette;

 	float VL_abs = texture2D(colortex7,texcoord*RENDER_SCALE).r;


	#ifdef AUTO_EXPOSURE
		float purkinje = clamp(exposure.a*exposure.a,0.0,1.0) * clamp(rodExposureDepth.x/(1.0+rodExposureDepth.x)*Purkinje_strength,0,1);
	#else
		float purkinje = clamp(rodExposureDepth.x/(1.0+rodExposureDepth.x)*Purkinje_strength,0,1);
	#endif	

  	VL_abs = clamp((1.0-VL_abs)*BLOOMY_FOG*0.75*(1.0+rainStrength) * (1.0-purkinje*0.3),0.0,1.0)*clamp(1.0-pow(cdist(texcoord.xy),15.0),0.0,1.0);

	col = (mix(col, bloom, VL_abs) + bloom * lightScat) * exposure.rgb;
	
  	float lum = dot(col, vec3(0.15,0.3,0.55));
	float lum2 = dot(col, vec3(0.85,0.7,0.45));
	float rodLum = lum2*200.0;
	float rodCurve = clamp(mix(1.0, rodLum/(2.5+rodLum), purkinje),0.0,1.0);

	col = mix(lum * vec3(Purkinje_R, Purkinje_G, Purkinje_B) * Purkinje_Multiplier, col, rodCurve);



  	// gl_FragColor = vec4(getViewPos() * 0.001,1.0);
	// gl_FragColor.rgb = linear_to_srgb(gl_FragColor.rgb);


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