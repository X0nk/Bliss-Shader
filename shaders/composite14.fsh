#version 120
//Merge and upsample the blurs into a 1/4 res bloom buffer
#include "lib/res_params.glsl"
uniform sampler2D colortex3;
uniform sampler2D colortex6;

uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;

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

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
/* DRAWBUFFERS:3 */
vec2 resScale = vec2(1920.,1080.)/(max(vec2(viewWidth,viewHeight),vec2(1920.0,1080.))/BLOOM_QUALITY);
vec2 texcoord = ((gl_FragCoord.xy)*2.+0.5)*texelSize;
vec3 bloom = texture2D_bicubic(colortex3,texcoord/2.0).rgb;	//1/4 res

bloom += texture2D_bicubic(colortex6,texcoord/4.).rgb; //1/8 res

bloom += texture2D_bicubic(colortex6,texcoord/8.+vec2(0.25*resScale.x+2.5*texelSize.x,.0)).rgb;  //1/16 res

bloom += texture2D_bicubic(colortex6,texcoord/16.+vec2(0.375*resScale.x+4.5*texelSize.x,.0)).rgb; //1/32 res

bloom += texture2D_bicubic(colortex6,texcoord/32.+vec2(0.4375*resScale.x+6.5*texelSize.x,.0)).rgb*1.0; //1/64 res
bloom += texture2D_bicubic(colortex6,texcoord/64.+vec2(0.46875*resScale.x+8.5*texelSize.x,.0)).rgb*1.0; //1/128 res
bloom += texture2D_bicubic(colortex6,texcoord/128.+vec2(0.484375*resScale.x+10.5*texelSize.x,.0)).rgb*1.0; //1/256 res

//bloom = texture2D_bicubic(colortex6,texcoord).rgb*6.; //1/8 res

gl_FragData[0].rgb = bloom*2.;

gl_FragData[0].rgb = clamp(gl_FragData[0].rgb,0.0,65000.);
}
