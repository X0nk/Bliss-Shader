#version 120
//Vignetting, applies bloom, applies exposure and tonemaps the final image
//#extension GL_EXT_gpu_shader4 : enable

#include "/lib/settings.glsl"

#ifdef DOF
	//hexagon pattern
	const vec2 hex_offsets[60] = vec2[60] (	vec2(  0.2165,  0.1250 ),
											vec2(  0.0000,  0.2500 ),
											vec2( -0.2165,  0.1250 ),
											vec2( -0.2165, -0.1250 ),
											vec2( -0.0000, -0.2500 ),
											vec2(  0.2165, -0.1250 ),
											vec2(  0.4330,  0.2500 ),
											vec2(  0.0000,  0.5000 ),
											vec2( -0.4330,  0.2500 ),
											vec2( -0.4330, -0.2500 ),
											vec2( -0.0000, -0.5000 ),
											vec2(  0.4330, -0.2500 ),
											vec2(  0.6495,  0.3750 ),
											vec2(  0.0000,  0.7500 ),
											vec2( -0.6495,  0.3750 ),
											vec2( -0.6495, -0.3750 ),
											vec2( -0.0000, -0.7500 ),
											vec2(  0.6495, -0.3750 ),
											vec2(  0.8660,  0.5000 ),
											vec2(  0.0000,  1.0000 ),
											vec2( -0.8660,  0.5000 ),
											vec2( -0.8660, -0.5000 ),
											vec2( -0.0000, -1.0000 ),
											vec2(  0.8660, -0.5000 ),
											vec2(  0.2163,  0.3754 ),
											vec2( -0.2170,  0.3750 ),
											vec2( -0.4333, -0.0004 ),
											vec2( -0.2163, -0.3754 ),
											vec2(  0.2170, -0.3750 ),
											vec2(  0.4333,  0.0004 ),
											vec2(  0.4328,  0.5004 ),
											vec2( -0.2170,  0.6250 ),
											vec2( -0.6498,  0.1246 ),
											vec2( -0.4328, -0.5004 ),
											vec2(  0.2170, -0.6250 ),
											vec2(  0.6498, -0.1246 ),
											vec2(  0.6493,  0.6254 ),
											vec2( -0.2170,  0.8750 ),
											vec2( -0.8663,  0.2496 ),
											vec2( -0.6493, -0.6254 ),
											vec2(  0.2170, -0.8750 ),
											vec2(  0.8663, -0.2496 ),
											vec2(  0.2160,  0.6259 ),
											vec2( -0.4340,  0.5000 ),
											vec2( -0.6500, -0.1259 ),
											vec2( -0.2160, -0.6259 ),
											vec2(  0.4340, -0.5000 ),
											vec2(  0.6500,  0.1259 ),
											vec2(  0.4325,  0.7509 ),
											vec2( -0.4340,  0.7500 ),
											vec2( -0.8665, -0.0009 ),
											vec2( -0.4325, -0.7509 ),
											vec2(  0.4340, -0.7500 ),
											vec2(  0.8665,  0.0009 ),
											vec2(  0.2158,  0.8763 ),
											vec2( -0.6510,  0.6250 ),
											vec2( -0.8668, -0.2513 ),
											vec2( -0.2158, -0.8763 ),
											vec2(  0.6510, -0.6250 ),
											vec2(  0.8668,  0.2513 ));

	const vec2 offsets[60] = vec2[60]  (  vec2( 0.0000, 0.2500 ),
									vec2( -0.2165, 0.1250 ),
									vec2( -0.2165, -0.1250 ),
									vec2( -0.0000, -0.2500 ),
									vec2( 0.2165, -0.1250 ),
									vec2( 0.2165, 0.1250 ),
									vec2( 0.0000, 0.5000 ),
									vec2( -0.2500, 0.4330 ),
									vec2( -0.4330, 0.2500 ),
									vec2( -0.5000, 0.0000 ),
									vec2( -0.4330, -0.2500 ),
									vec2( -0.2500, -0.4330 ),
									vec2( -0.0000, -0.5000 ),
									vec2( 0.2500, -0.4330 ),
									vec2( 0.4330, -0.2500 ),
									vec2( 0.5000, -0.0000 ),
									vec2( 0.4330, 0.2500 ),
									vec2( 0.2500, 0.4330 ),
									vec2( 0.0000, 0.7500 ),
									vec2( -0.2565, 0.7048 ),
									vec2( -0.4821, 0.5745 ),
									vec2( -0.6495, 0.3750 ),
									vec2( -0.7386, 0.1302 ),
									vec2( -0.7386, -0.1302 ),
									vec2( -0.6495, -0.3750 ),
									vec2( -0.4821, -0.5745 ),
									vec2( -0.2565, -0.7048 ),
									vec2( -0.0000, -0.7500 ),
									vec2( 0.2565, -0.7048 ),
									vec2( 0.4821, -0.5745 ),
									vec2( 0.6495, -0.3750 ),
									vec2( 0.7386, -0.1302 ),
									vec2( 0.7386, 0.1302 ),
									vec2( 0.6495, 0.3750 ),
									vec2( 0.4821, 0.5745 ),
									vec2( 0.2565, 0.7048 ),
									vec2( 0.0000, 1.0000 ),
									vec2( -0.2588, 0.9659 ),
									vec2( -0.5000, 0.8660 ),
									vec2( -0.7071, 0.7071 ),
									vec2( -0.8660, 0.5000 ),
									vec2( -0.9659, 0.2588 ),
									vec2( -1.0000, 0.0000 ),
									vec2( -0.9659, -0.2588 ),
									vec2( -0.8660, -0.5000 ),
									vec2( -0.7071, -0.7071 ),
									vec2( -0.5000, -0.8660 ),
									vec2( -0.2588, -0.9659 ),
									vec2( -0.0000, -1.0000 ),
									vec2( 0.2588, -0.9659 ),
									vec2( 0.5000, -0.8660 ),
									vec2( 0.7071, -0.7071 ),
									vec2( 0.8660, -0.5000 ),
									vec2( 0.9659, -0.2588 ),
									vec2( 1.0000, -0.0000 ),
									vec2( 0.9659, 0.2588 ),
									vec2( 0.8660, 0.5000 ),
									vec2( 0.7071, 0.7071 ),
									vec2( 0.5000, 0.8660 ),
									vec2( 0.2588, 0.9659 ));

const vec2 shadow_offsets[209] = vec2[209](vec2(0.8886414f , 0.07936136f),
vec2(0.8190064f , 0.1900164f),
vec2(0.8614115f , -0.06991258f),
vec2(0.7685533f , 0.03792081f),
vec2(0.9970094f , 0.02585129f),
vec2(0.9686818f , 0.1570935f),
vec2(0.9854341f , -0.09172997f),
vec2(0.9330608f , 0.3326486f),
vec2(0.8329557f , -0.2438523f),
vec2(0.664771f , -0.0837701f),
vec2(0.7429124f , -0.1530652f),
vec2(0.9506453f , -0.2174281f),
vec2(0.8192949f , 0.3485171f),
vec2(0.6851269f , 0.2711877f),
vec2(0.7665657f , 0.5014166f),
vec2(0.673241f , 0.3793408f),
vec2(0.6981376f , 0.1465924f),
vec2(0.6521665f , -0.2384985f),
vec2(0.5145761f , -0.05752508f),
vec2(0.5641244f , -0.169443f),
vec2(0.5916035f , 0.06004957f),
vec2(0.57079f , 0.234188f),
vec2(0.509311f , 0.1523665f),
vec2(0.4204576f , 0.05759521f),
vec2(0.8200846f , -0.3601041f),
vec2(0.6893264f , -0.3473432f),
vec2(0.4775535f , -0.3062558f),
vec2(0.438106f , -0.1796866f),
vec2(0.4056528f , -0.08251233f),
vec2(0.5771964f , 0.5502692f),
vec2(0.5094061f , 0.4025192f),
vec2(0.6908483f , 0.572951f),
vec2(0.5379036f , -0.4542191f),
vec2(0.8167359f , -0.4793735f),
vec2(0.6829269f , -0.4557574f),
vec2(0.5725697f , -0.3477072f),
vec2(0.5767449f , -0.5782524f),
vec2(0.3979413f , -0.4172934f),
vec2(0.4282598f , -0.5145645f),
vec2(0.938814f , -0.3239739f),
vec2(0.702452f , -0.5662871f),
vec2(0.2832307f , -0.1285671f),
vec2(0.3230537f , -0.2691054f),
vec2(0.2921676f , -0.3734582f),
vec2(0.2534037f , -0.4906001f),
vec2(0.4343273f , 0.5223463f),
vec2(0.3605334f , 0.3151571f),
vec2(0.3498518f , 0.451428f),
vec2(0.3230703f , 0.00287089f),
vec2(0.1049206f , -0.1476725f),
vec2(0.2063161f , -0.2608192f),
vec2(0.7266634f , 0.6725333f),
vec2(0.4027067f , -0.6185485f),
vec2(0.2655533f , -0.5912259f),
vec2(0.4947965f , 0.3025357f),
vec2(0.5760762f , 0.68844f),
vec2(0.4909205f , -0.6975324f),
vec2(0.8609334f , 0.4559f),
vec2(0.1836646f , 0.03724086f),
vec2(0.2878554f , 0.178938f),
vec2(0.3948484f , 0.1618928f),
vec2(0.3519658f , -0.7628763f),
vec2(0.6338583f , -0.673193f),
vec2(0.5511802f , -0.8283072f),
vec2(0.4090595f , -0.8717521f),
vec2(0.1482169f , -0.374728f),
vec2(0.1050598f , -0.2613987f),
vec2(0.4210334f , 0.6578422f),
vec2(0.2430464f , 0.4383665f),
vec2(0.3329675f , 0.5512741f),
vec2(0.2147711f , 0.3245511f),
vec2(0.1227196f , 0.2529026f),
vec2(-0.03937457f , 0.156439f),
vec2(0.05618772f , 0.06690486f),
vec2(0.06519571f , 0.3974038f),
vec2(0.1360903f , 0.1466078f),
vec2(-0.00170609f , 0.3089452f),
vec2(0.1357622f , -0.5088975f),
vec2(0.1604694f , -0.7453476f),
vec2(0.1245694f , -0.6337074f),
vec2(0.02542936f , -0.3728781f),
vec2(0.02222222f , -0.649554f),
vec2(0.09870815f , 0.5357338f),
vec2(0.2073958f , 0.5452989f),
vec2(0.216654f , -0.8935689f),
vec2(0.2422334f , 0.665805f),
vec2(0.0574713f , 0.6742729f),
vec2(0.2021346f , 0.8144029f),
vec2(0.3086587f , 0.7504997f),
vec2(0.02122174f , -0.7498575f),
vec2(-0.1551729f , 0.1809731f),
vec2(-0.1947583f , 0.06246066f),
vec2(-0.05754202f , -0.03901273f),
vec2(-0.1083095f , 0.2952235f),
vec2(-0.03259534f , -0.492394f),
vec2(-0.02488567f , -0.2081116f),
vec2(-0.1820729f , -0.1829884f),
vec2(-0.1674413f , -0.04529009f),
vec2(0.04342153f , -0.0368562f),
vec2(0.801399f , -0.5845526f),
vec2(0.3158276f , -0.9124843f),
vec2(-0.05945269f , 0.6727523f),
vec2(0.07701834f , 0.8579889f),
vec2(-0.05778154f , 0.5699022f),
vec2(0.1191713f , 0.7542591f),
vec2(-0.2578296f , 0.3630984f),
vec2(-0.1428598f , 0.4557526f),
vec2(-0.3304029f , 0.5055485f),
vec2(-0.3227198f , 0.1847367f),
vec2(-0.4183801f , 0.3412776f),
vec2(0.2538475f , 0.9317476f),
vec2(0.406249f , 0.8423664f),
vec2(0.4718862f , 0.7592828f),
vec2(0.168472f , -0.06605823f),
vec2(0.2632498f , -0.7084918f),
vec2(-0.2816192f , -0.1023492f),
vec2(-0.3161443f , 0.02489911f),
vec2(-0.4677814f , 0.08450397f),
vec2(-0.4156994f , 0.2408664f),
vec2(-0.237449f , 0.2605326f),
vec2(-0.0912179f , 0.06491816f),
vec2(0.01475127f , 0.7670643f),
vec2(0.1216858f , -0.9368939f),
vec2(0.07010741f , -0.841011f),
vec2(-0.1708607f , -0.4152923f),
vec2(-0.1345006f , -0.5842513f),
vec2(-0.09419055f , -0.3213732f),
vec2(-0.2149337f , 0.730642f),
vec2(-0.1102187f , 0.8425013f),
vec2(-0.1808572f , 0.6244397f),
vec2(-0.2414505f , -0.7063725f),
vec2(-0.2410318f , -0.537854f),
vec2(-0.1005938f , -0.7635075f),
vec2(0.1053517f , 0.9678772f),
vec2(-0.3340288f , 0.6926677f),
vec2(-0.2363931f , 0.8464488f),
vec2(-0.4057773f , 0.7786722f),
vec2(-0.5484858f , 0.1686208f),
vec2(-0.64842f , 0.02256887f),
vec2(-0.5544513f , -0.02348978f),
vec2(-0.492855f , -0.1083694f),
vec2(-0.4248196f , 0.4674786f),
vec2(-0.5873146f , 0.4072608f),
vec2(-0.6439911f , 0.3038489f),
vec2(-0.6419188f , 0.1293737f),
vec2(-0.005880734f , 0.4699725f),
vec2(-0.4239455f , 0.6250131f),
vec2(-0.1701273f , 0.9506347f),
vec2(7.665656E-05f , 0.9941212f),
vec2(-0.7070159f , 0.4426281f),
vec2(-0.7481344f , 0.3139496f),
vec2(-0.8330062f , 0.2472693f),
vec2(-0.7271438f , 0.2024286f),
vec2(-0.5179888f , 0.3149576f),
vec2(-0.8258062f , 0.3779382f),
vec2(-0.8063191f , 0.1262931f),
vec2(-0.2690676f , -0.4360798f),
vec2(-0.3714577f , -0.5887412f),
vec2(-0.3736085f , -0.4018324f),
vec2(-0.3228985f , -0.2063406f),
vec2(-0.2414576f , -0.2875458f),
vec2(-0.4720859f , -0.3823904f),
vec2(-0.4937642f , -0.2686005f),
vec2(-0.01500604f , -0.9587054f),
vec2(-0.08535925f , -0.8820614f),
vec2(-0.6436375f , -0.3157263f),
vec2(-0.5736347f , -0.4224878f),
vec2(-0.5026127f , -0.5516239f),
vec2(-0.8200902f , 0.5370023f),
vec2(-0.7196413f , 0.57133f),
vec2(-0.5849072f , 0.5917885f),
vec2(-0.1598758f , -0.9739854f),
vec2(-0.4230629f , -0.01858409f),
vec2(-0.9403627f , 0.2213769f),
vec2(-0.685889f , -0.2192711f),
vec2(-0.6693704f , -0.4884708f),
vec2(-0.7967147f , -0.3078234f),
vec2(-0.596441f , -0.1686891f),
vec2(-0.7366468f , -0.3939891f),
vec2(-0.7963406f , 0.02246814f),
vec2(-0.9177913f , 0.0929693f),
vec2(-0.9284672f , 0.3329005f),
vec2(-0.6497722f , 0.6851863f),
vec2(-0.496019f , 0.7013303f),
vec2(-0.3930301f , -0.6892192f),
vec2(-0.2122009f , -0.8777389f),
vec2(-0.3660335f , -0.801644f),
vec2(-0.386839f , -0.1191898f),
vec2(-0.7020127f , -0.0776734f),
vec2(-0.7760845f , -0.1566844f),
vec2(-0.5444778f , -0.6516482f),
vec2(-0.5331346f , 0.4946506f),
vec2(-0.3288236f , 0.9408244f),
vec2(0.5819826f , 0.8101937f),
vec2(-0.4894184f , -0.8290837f),
vec2(-0.5183194f , 0.8454953f),
vec2(-0.7665774f , -0.5223897f),
vec2(-0.6703191f , -0.6217513f),
vec2(-0.8902924f , -0.2446688f),
vec2(-0.8574848f , -0.09174173f),
vec2(-0.3544409f , -0.9239591f),
vec2(-0.969833f , -0.1172272f),
vec2(-0.8968207f , -0.4079512f),
vec2(-0.5891477f , 0.7724466f),
vec2(-0.2146262f , 0.5286855f),
vec2(-0.3762444f , -0.3014335f),
vec2(-0.9466863f , -0.008970681f),
vec2(-0.596356f , -0.7976127f),
vec2(-0.8877738f , 0.4569088f));
#endif
flat varying vec4 exposure;
flat varying float rodExposure;
varying vec2 texcoord;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex3;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;
uniform vec2 texelSize;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform int isEyeInWater;
uniform float near;
uniform float aspectRatio;
uniform float far;


#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"



float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}
vec3 closestToCamera3x3()
{
	vec2 du = vec2(texelSize.x, 0.0);
	vec2 dv = vec2(0.0, texelSize.y);

	vec3 dtl = vec3(texcoord,0.) + vec3(-texelSize, texture2D(depthtex0, texcoord - dv - du).x);
	vec3 dtc = vec3(texcoord,0.) + vec3( 0.0, -texelSize.y, texture2D(depthtex0, texcoord - dv).x);
	vec3 dtr = vec3(texcoord,0.) +  vec3( texelSize.x, -texelSize.y, texture2D(depthtex0, texcoord - dv + du).x);

	vec3 dml = vec3(texcoord,0.) +  vec3(-texelSize.x, 0.0, texture2D(depthtex0, texcoord - du).x);
	vec3 dmc = vec3(texcoord,0.) + vec3( 0.0, 0.0, texture2D(depthtex0, texcoord).x);
	vec3 dmr = vec3(texcoord,0.) + vec3( texelSize.x, 0.0, texture2D(depthtex0, texcoord + du).x);

	vec3 dbl = vec3(texcoord,0.) + vec3(-texelSize.x, texelSize.y, texture2D(depthtex0, texcoord + dv - du).x);
	vec3 dbc = vec3(texcoord,0.) + vec3( 0.0, texelSize.y, texture2D(depthtex0, texcoord + dv).x);
	vec3 dbr = vec3(texcoord,0.) + vec3( texelSize.x, texelSize.y, texture2D(depthtex0, texcoord + dv + du).x);

	vec3 dmin = dmc;

	dmin = dmin.z > dtc.z? dtc : dmin;
	dmin = dmin.z > dtr.z? dtr : dmin;

	dmin = dmin.z > dml.z? dml : dmin;
	dmin = dmin.z > dtl.z? dtl : dmin;
	dmin = dmin.z > dmr.z? dmr : dmin;

	dmin = dmin.z > dbl.z? dbl : dmin;
	dmin = dmin.z > dbc.z? dbc : dmin;
	dmin = dmin.z > dbr.z? dbr : dmin;

	return dmin;
}
void main() {
  /* DRAWBUFFERS:7 */
  float vignette = (1.5-dot(texcoord-0.5,texcoord-0.5)*2.5);
	vec3 col = texture2D(colortex5,texcoord).rgb;
	#ifdef DOF
		/*--------------------------------*/
		float z = ld(texture2D(depthtex0, texcoord.st).r)*far;
		#ifdef AUTOFOCUS
			float focus = ld(texture2D(depthtex0, vec2(0.5)).r)*far;
		#else
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
		#ifndef HQ_DOF
		bcolor = col;
		#ifdef HEXAGONAL_BOKEH
			for ( int i = 0; i < 60; i++) {
				bcolor += texture2D(colortex5, texcoord.xy + hex_offsets[i]*pcoc*vec2(1.0,aspectRatio)).rgb;
			}
			col = bcolor/61.0;
		#else
			for ( int i = 0; i < 60; i++) {
				bcolor += texture2D(colortex5, texcoord.xy + offsets[i]*pcoc*vec2(1.0,aspectRatio)).rgb;
			}
		/*--------------------------------*/
	col = bcolor/61.0;
		#endif
		#endif
		#ifdef HQ_DOF
			for ( int i = 0; i < 209; i++) {
				bcolor += texture2D(colortex5, texcoord.xy + noiseM*shadow_offsets[i]*pcoc*vec2(1.0,aspectRatio)).rgb;
			}
			col = bcolor/209.0;
		#endif
#endif
	vec2 clampedRes = max(vec2(viewWidth,viewHeight),vec2(1920.0,1080.));

	vec3 bloom = texture2D(colortex3,texcoord/clampedRes*vec2(1920.,1080.)*0.5).rgb/2./7.0;

	float lightScat = clamp(BLOOM_STRENGTH  * 0.05 * pow(exposure.a ,0.2)  ,0.0,1.0)*vignette;

  	float VL_abs = texture2D(colortex7,texcoord).r;
  	VL_abs = clamp((1.0-VL_abs*1.05)*BLOOMY_FOG*0.5,0.0,1.0)*clamp(1.0-pow(cdist(texcoord.xy),15.0),0.0,1.0);

	col = ( mix(col, bloom, VL_abs) + bloom*lightScat) * exposure.rgb;
/*
	//Purkinje Effect
  float lum = dot(col,vec3(0.15,0.3,0.55));
	float lum2 = dot(col,vec3(0.85,0.7,0.45))/2;
	float rodLum = lum2*300.0;
	float rodCurve = mix(1.0, rodLum/(2.5+rodLum), rodExposure/2.0*Purkinje_strength);
	col = mix(lum*Purkinje_Multiplier*vec3(Purkinje_R, Purkinje_G, Purkinje_B)+0.001, col, rodCurve);
*/
	#ifndef USE_ACES_COLORSPACE_APPROXIMATION
  	col = LinearTosRGB(TONEMAP(col));
	#else
		col = col * ACESInputMat;
		col = TONEMAP(col);
		col = LinearTosRGB(clamp(col * ACESOutputMat, 0.0, 1.0));
	#endif
	//col = ACESFitted(texture2D(colortex4,texcoord/3.).rgb/500.);
	gl_FragData[0].rgb = clamp(int8Dither(col,texcoord),0.0,1.0);
	//if (nightMode < 0.99 && texcoord.x < 0.5)	gl_FragData[0].rgb =vec3(0.0,1.0,0.0);

}
