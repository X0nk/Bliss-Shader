#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

uniform sampler2D depthtex0;
uniform sampler2D colortex1;
uniform sampler2D colortex5;
uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;

vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}

float maxof3(vec3 color) {
  return max(color.x, max(color.y, color.z));
}

float thercp(float color){
  return 1.0 / color;
}

vec3 tonemap(vec3 c) {
  return c * thercp(maxof3(c) + 1.0);
}

// vec3 invTonemap(vec3 c) { 
//   return c * thercp(1.0 - maxof3(c));
// }

vec4 invTonemap(vec4 c) {
    c.rgb /= 65000.0;
  return vec4(c.rgb * thercp(1.0 - maxof3(c.rgb)),0.0);
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

/* RENDERTARGETS:3 */
void main() {

vec2 resScale = max(vec2(viewWidth,viewHeight),vec2(1920.0,1080.))/vec2(1920.,1080.);
vec2 quarterResTC = gl_FragCoord.xy*2.0*resScale*texelSize;

//0.5
gl_FragData[0] =  (invTonemap(texture(colortex5,quarterResTC-1.0*vec2(texelSize.x,texelSize.y))         ))/4.*0.5;
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC+1.0*vec2(texelSize.x,texelSize.y))         ))/4.*0.5;
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC+vec2(-1.0*texelSize.x,1.0*texelSize.y))    ))/4.*0.5;
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC+vec2(1.0*texelSize.x,-1.0*texelSize.y))    ))/4.*0.5;
//0.25*65000.0
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC-2.0*vec2(texelSize.x,0.0))                 ))/2.*0.125;
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC+2.0*vec2(0.0,texelSize.y))                 ))/2.*0.125;
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC+2.0*vec2(0,-texelSize.y))                  ))/2*0.125;
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC+2.0*vec2(-texelSize.x,0.0))                ))/2*0.125;
//0.125*65000.0
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC-2.0*vec2(texelSize.x,texelSize.y))         ))/4.*0.125;
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC+2.0*vec2(texelSize.x,texelSize.y))         ))/4.*0.125;
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC+vec2(-2.0*texelSize.x,2.0*texelSize.y))    ))/4.*0.125;
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC+vec2(2.0*texelSize.x,-2.0*texelSize.y))    ))/4.*0.125;
//0.125
gl_FragData[0] += (invTonemap(texture(colortex5,quarterResTC))/65000.0)       *0.125;

gl_FragData[0].rgb = clamp(gl_FragData[0].rgb,0.0,65000.);

if (quarterResTC.x > 1.0 - 3.5*texelSize.x || quarterResTC.y > 1.0 -3.5*texelSize.y || quarterResTC.x < 3.5*texelSize.x || quarterResTC.y < 3.5*texelSize.y) gl_FragData[0].rgb = vec3(0.0);
}