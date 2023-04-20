#version 120
//downsample 1st pass (half res) for bloom

uniform sampler2D colortex5;
uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

/* DRAWBUFFERS:3 */
vec2 resScale = max(vec2(viewWidth,viewHeight),vec2(1920.0,1080.))/vec2(1920.,1080.);
vec2 quarterResTC = gl_FragCoord.xy*2.*resScale*texelSize;

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
		if (quarterResTC.x > 1.0 - 3.5*texelSize.x || quarterResTC.y > 1.0 -3.5*texelSize.y || quarterResTC.x < 3.5*texelSize.x || quarterResTC.y < 3.5*texelSize.y) gl_FragData[0].rgb = vec3(0.0);


}
