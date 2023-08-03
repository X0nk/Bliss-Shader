// #version 120
varying vec4 lmtexcoord;
varying vec4 color;

flat varying vec3 averageSkyCol_Clouds;
// flat varying vec3 averageSkyCol;

flat varying vec4 lightCol; //main light source color (rgb),used light source(1=sun,-1=moon)
// flat varying vec3 sunColor;
// flat varying vec3 moonColor;

uniform vec3 sunVec;
flat varying vec3 WsunVec;

uniform sampler2D texture;
uniform sampler2DShadow shadow;
uniform sampler2D gaux1;
uniform sampler2D noisetex;
uniform float frameTimeCounter;
uniform ivec2 eyeBrightnessSmooth;

uniform float far;
uniform float near;
uniform vec2 texelSize;
uniform float rainStrength;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;


#include "/lib/settings.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/res_params.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/volumetricClouds.glsl"

#define OVERWORLD_SHADER
#include "/lib/diffuse_lighting.glsl"

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

vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* DRAWBUFFERS:29 */
void main() {

	vec4 TEXTURE = texture2D(texture, lmtexcoord.xy) * color;

	vec2 tempOffset = offsets[framemod8];
	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);

	float cloudOcclusion = 0.0;

	if(TEXTURE.a > 0.0) cloudOcclusion = 1.0 - GetCloudSkyOcclusion(p3 + cameraPosition)*0.8;
	gl_FragData[1].a = TEXTURE.a * cloudOcclusion ; // for bloomy rain and stuff

#ifndef WEATHER
	gl_FragData[1].a = 1.0 - TEXTURE.a;
	
	#ifdef LIT
		gl_FragData[1].a = 0.0;
	#endif
	
	gl_FragData[0].a = TEXTURE.a;
	
	vec3 Albedo = toLinear(TEXTURE.rgb);

	// do the maths only if the pixels exist....
	if(TEXTURE.a > 0.0){

		float Shadows = 1.0;
		
		vec3 p3_shadow = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
		vec3 projectedShadowPosition = mat3(shadowModelView) * p3_shadow + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		//apply distortion
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;
		int shadowmapindicator = 0;
		//do shadows only if on shadow map
		if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution){

			projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);

			Shadows = shadow2D_bicubic(shadow,vec3(projectedShadowPosition + vec3(0.0,0.0,0.0)));
			
			shadowmapindicator = 1;
		}
		
		if(shadowmapindicator < 1) Shadows = clamp((lmtexcoord.w-0.8) * 5,0,1);

		#ifdef CLOUDS_SHADOWS
			Shadows *= GetCloudShadow(p3);
		#endif

		vec3 AmbientLightColor = averageSkyCol_Clouds;
		vec3 DirectLightColor = lightCol.rgb/80.0;

		AmbientLightColor += (lightningEffect * 10) * pow(lmtexcoord.w,2);

		float lightleakfix = clamp(eyeBrightnessSmooth.y/240.0,0.0,1.0);
		float phase = phaseg(clamp(dot(np3, WsunVec),0.0,1.0),(1.0-gl_FragData[0].a) * 0.8 + 0.1) + 1.0 ;
		vec3 Direct_lighting = DoDirectLighting(DirectLightColor, Shadows, 1.0, 0.0) * phase * lightleakfix;
		vec3 Torch_Color = vec3(TORCH_R,TORCH_G,TORCH_B);

		#ifdef LIT
			Torch_Color *= LIT_PARTICLE_BRIGHTNESS;
		#endif

		vec3 Indirect_lighting = DoAmbientLighting(AmbientLightColor, Torch_Color, clamp(lmtexcoord.zw,0.0,1.0), 5.0);
		
		// gl_FragData[0].a = TEXTURE.a;

		gl_FragData[0].rgb = (Direct_lighting + Indirect_lighting) * Albedo;

	}
#endif
}