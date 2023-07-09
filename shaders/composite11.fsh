#version 120
//Vignetting, applies bloom, applies exposure and tonemaps the final image
//#extension GL_EXT_gpu_shader4 : disable

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

void main() {
  /* DRAWBUFFERS:7 */
	float vignette = (1.5-dot(texcoord-0.5,texcoord-0.5)*2.);
	vec3 col = texture2D(colortex5,texcoord).rgb;

	#if DOF_QUALITY >= 0 && DOF_QUALITY < 5
		/*--------------------------------*/
		float z = ld(texture2D(depthtex0, texcoord.st*RENDER_SCALE).r)*far;
		#if MANUAL_FOCUS == -2
			float focus = rodExposureDepth.y*far;
		#elif MANUAL_FOCUS == -1
			float focus = mix(pow(512.0, screenBrightness), 512.0 * screenBrightness, 0.25);
		#elif MANUAL_FOCUS > 0
			float focus = MANUAL_FOCUS;
		#endif
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

	vec2 clampedRes = max(vec2(viewWidth,viewHeight),vec2(1920.0,1080.));



	vec3 bloom = texture2D(colortex3,texcoord/clampedRes*vec2(1920.,1080.)*0.5*BLOOM_QUALITY).rgb/2./7.0;

	float lightScat = clamp(BLOOM_STRENGTH  * 0.05 * pow(exposure.a ,0.2)  ,0.0,1.0)*vignette;

 	float VL_abs = texture2D(colortex7,texcoord*RENDER_SCALE).r;
	float purkinje = rodExposureDepth.x/(1.0+rodExposureDepth.x)*Purkinje_strength;

 	VL_abs = clamp( (1.0-VL_abs)*BLOOMY_FOG*0.75*(1.0-purkinje),0.0,1.0)*clamp(1.0-pow(cdist(texcoord.xy),15.0),0.0,1.0);

	float lightleakfix = clamp(eyeBrightnessSmooth.y/240.0,0.0,1.0);

	col = (mix(col,bloom,VL_abs)+bloom * lightScat)*	mix(exposure.rgb,min(exposure.rgb,0.01), 0);

	//Purkinje Effect
  	float lum = dot(col,vec3(0.15,0.3,0.55));
	float lum2 = dot(col,vec3(0.85,0.7,0.45))/2;
	float rodLum = lum2*400.;
	float rodCurve = mix(1.0, rodLum/(2.5+rodLum), purkinje);
	col = mix(clamp(lum,0.0,0.05)*Purkinje_Multiplier*vec3(Purkinje_R, Purkinje_G, Purkinje_B)+1.5e-3, col, rodCurve);

	#ifndef USE_ACES_COLORSPACE_APPROXIMATION
  		col = LinearTosRGB(TONEMAP(col));
	#else
		col = col * ACESInputMat;
		col = TONEMAP(col);

		col = LinearTosRGB(clamp(col * ACESOutputMat, 0.0, 1.0));
	#endif


	gl_FragData[0].rgb = clamp(int8Dither(col,texcoord),0.0,1.0);
}