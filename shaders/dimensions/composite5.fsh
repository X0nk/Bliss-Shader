uniform sampler2D colortex3;
uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

/* DRAWBUFFERS:6 */
vec2 resScale = max(vec2(viewWidth,viewHeight),vec2(1920.0,1080.))/vec2(1920.,1080.);
vec2 quarterResTC = gl_FragCoord.xy*2.*texelSize;

		//0.5
		gl_FragData[0] = texture2D(colortex3,quarterResTC-1.0*vec2(texelSize.x,texelSize.y))/4.*0.5;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+1.0*vec2(texelSize.x,texelSize.y))/4.*0.5;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(-1.0*texelSize.x,1.0*texelSize.y))/4.*0.5;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(1.0*texelSize.x,-1.0*texelSize.y))/4.*0.5;

		//0.25
		gl_FragData[0] += texture2D(colortex3,quarterResTC-2.0*vec2(texelSize.x,0.0))/2.*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+2.0*vec2(0.0,texelSize.y))/2.*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+2.0*vec2(0,-texelSize.y))/2*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+2.0*vec2(-texelSize.x,0.0))/2*0.125;

		//0.125
		gl_FragData[0] += texture2D(colortex3,quarterResTC-2.0*vec2(texelSize.x,texelSize.y))/4.*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+2.0*vec2(texelSize.x,texelSize.y))/4.*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(-2.0*texelSize.x,2.0*texelSize.y))/4.*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(2.0*texelSize.x,-2.0*texelSize.y))/4.*0.125;

		//0.125
		gl_FragData[0] += texture2D(colortex3,quarterResTC)*0.125;

		gl_FragData[0].rgb = clamp(gl_FragData[0].rgb,0.0,65000.);



}
