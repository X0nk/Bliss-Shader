uniform sampler2D depthtex1;
uniform sampler2D colortex1;
uniform sampler2D colortex5;
uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;

vec3 decode (vec2 encn){
    vec3 n = vec3(0.0);
    encn = encn * 2.0 - 1.0;
    n.xy = abs(encn);
    n.z = 1.0 - n.x - n.y;
    n.xy = n.z <= 0.0 ? (1.0 - n.yx) * sign(encn) : encn;
    return clamp(normalize(n.xyz),-1.0,1.0);
}
vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

/* DRAWBUFFERS:3 */

vec2 resScale = max(vec2(viewWidth,viewHeight),vec2(1920.0,1080.))/vec2(1920.,1080.);
vec2 quarterResTC = gl_FragCoord.xy*2.*resScale*texelSize;

vec4 data = texture2D(colortex1,quarterResTC);
vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w));
float depth = texture2D(depthtex1,quarterResTC).x;
bool hand = abs(dataUnpacked1.w-0.75) < 0.01 && depth < 1.0;

		//0.5
		gl_FragData[0] = texture2D(colortex5,quarterResTC-1.0*vec2(texelSize.x,texelSize.y))/4.*0.5;
		gl_FragData[0] += texture2D(colortex5,quarterResTC+1.0*vec2(texelSize.x,texelSize.y))/4.*0.5;
		gl_FragData[0] += texture2D(colortex5,quarterResTC+vec2(-1.0*texelSize.x,1.0*texelSize.y))/4.*0.5;
		gl_FragData[0] += texture2D(colortex5,quarterResTC+vec2(1.0*texelSize.x,-1.0*texelSize.y))/4.*0.5;

		//0.25
		gl_FragData[0] += texture2D(colortex5,quarterResTC-2.0*vec2(texelSize.x,0.0))/2.*0.125;
		gl_FragData[0] += texture2D(colortex5,quarterResTC+2.0*vec2(0.0,texelSize.y))/2.*0.125;
		gl_FragData[0] += texture2D(colortex5,quarterResTC+2.0*vec2(0,-texelSize.y))/2*0.125;
		gl_FragData[0] += texture2D(colortex5,quarterResTC+2.0*vec2(-texelSize.x,0.0))/2*0.125;

		//0.125
		gl_FragData[0] += texture2D(colortex5,quarterResTC-2.0*vec2(texelSize.x,texelSize.y))/4.*0.125;
		gl_FragData[0] += texture2D(colortex5,quarterResTC+2.0*vec2(texelSize.x,texelSize.y))/4.*0.125;
		gl_FragData[0] += texture2D(colortex5,quarterResTC+vec2(-2.0*texelSize.x,2.0*texelSize.y))/4.*0.125;
		gl_FragData[0] += texture2D(colortex5,quarterResTC+vec2(2.0*texelSize.x,-2.0*texelSize.y))/4.*0.125;

		//0.125
		gl_FragData[0] += texture2D(colortex5,quarterResTC)*0.125;

		gl_FragData[0].rgb = clamp(gl_FragData[0].rgb,0.0,65000.);
		if (hand || quarterResTC.x > 1.0 - 3.5*texelSize.x || quarterResTC.y > 1.0 -3.5*texelSize.y || quarterResTC.x < 3.5*texelSize.x || quarterResTC.y < 3.5*texelSize.y) gl_FragData[0].rgb = vec3(0.0);


}
