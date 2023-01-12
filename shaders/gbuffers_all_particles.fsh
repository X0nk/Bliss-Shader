// #version 120
varying vec4 lmtexcoord;
varying vec4 color;

uniform sampler2D texture;
uniform sampler2DShadow shadow;
uniform sampler2D gaux1;
uniform sampler2D noisetex;
uniform vec3 sunVec;
flat varying vec3 WsunVec;
uniform float frameTimeCounter;
uniform ivec2 eyeBrightnessSmooth;

uniform vec2 texelSize;
uniform float rainStrength;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;

#include "lib/Shadow_Params.glsl"
#include "/lib/res_params.glsl"
#include "lib/sky_gradient.glsl"
#include "lib/volumetricClouds.glsl"

//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

uniform int framemod8;
const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);

float shadow2D_bicubic(sampler2DShadow tex, vec3 sc)
{
	vec2 uv = sc.xy*shadowMapResolution;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = vec2(iuv.x + h0x, iuv.y + h0y)/shadowMapResolution - 0.5/shadowMapResolution;
	vec2 p1 = vec2(iuv.x + h1x, iuv.y + h0y)/shadowMapResolution - 0.5/shadowMapResolution;
	vec2 p2 = vec2(iuv.x + h0x, iuv.y + h1y)/shadowMapResolution - 0.5/shadowMapResolution;
	vec2 p3 = vec2(iuv.x + h1x, iuv.y + h1y)/shadowMapResolution - 0.5/shadowMapResolution;

    return g0(fuv.y) * (g0x * shadow2D(tex, vec3(p0,sc.z)).x  +
                        g1x * shadow2D(tex, vec3(p1,sc.z)).x) +
           g1(fuv.y) * (g0x * shadow2D(tex, vec3(p2,sc.z)).x  +
                        g1x * shadow2D(tex, vec3(p3,sc.z)).x);
}
float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}
vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

float GetCloudShadow(vec3 eyePlayerPos){
	vec3 worldPos = (eyePlayerPos + cameraPosition) - Cloud_Height;
	vec3 cloudPos = worldPos*Cloud_Size + WsunVec/abs(WsunVec.y) * ((3250 - 3250*0.35) - worldPos.y*Cloud_Size) ;
	float shadow = getCloudDensity(cloudPos, 1);
	// float shadow = (getCloudDensity(cloudPos, 1) + HighAltitudeClouds(cloudPos)) / 2.0;

	shadow = clamp(exp(-shadow*15),0.0,1.0);

	return shadow ;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* DRAWBUFFERS:29 */
void main() {

	vec4 TEXTURE = texture2D(texture, lmtexcoord.xy)*color;
	
#ifndef WEATHER
	gl_FragData[0] = TEXTURE;
	vec2 tempOffset = offsets[framemod8];
	float avgBlockLum = luma(texture2DLod(texture, lmtexcoord.xy,128).rgb*color.rgb);
	gl_FragData[0].rgb = clamp((gl_FragData[0].rgb)*pow(avgBlockLum,-0.33)*0.85,0.0,1.0);
	vec3 albedo = toLinear(gl_FragData[0].rgb);

	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);

	vec3 DirectLightCol = texelFetch2D(gaux1,ivec2(6,37),0).rgb / 127.0;
	DirectLightCol *= GetCloudShadow(p3);

	vec3 AmbientLight = texture2D(gaux1,(lmtexcoord.zw*15.+0.5)*texelSize).rgb *  8.0/150.0/3.0;

	//compute shadows only if not backface
	float diffuseSun = 0.712;
	if (diffuseSun > 0.001) {
		vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
		vec3 projectedShadowPosition = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		//apply distortion
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;
		//do shadows only if on shadow map
		if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution){

			float diffthresh = 0.0002;

			projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);

			float shading = shadow2D_bicubic(shadow,vec3(projectedShadowPosition + vec3(0.0,0.0,-diffthresh*1.2)));
			DirectLightCol *= shading;
		}
	}

	float phase = phaseg(clamp(dot(np3, WsunVec),0.0,1.0), 0.7) + 0.05 ;
	float lightleakfix = clamp(eyeBrightnessSmooth.y/240.0,0.0,1.0);
	vec3 DirectLight = DirectLightCol * phase * lightleakfix;
	
	gl_FragData[0].rgb = (AmbientLight + DirectLight) * albedo;
#endif

	gl_FragData[1].a = TEXTURE.a; // for bloomy rain
	// gl_FragData[1].a = 1;
}