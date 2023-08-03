uniform float viewWidth;
uniform float viewHeight;
varying vec2 texcoord;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	vec2 clampedRes = max(vec2(viewWidth,viewHeight),vec2(1920.0,1080.0));
	gl_Position = ftransform();
	//0-0.25
	gl_Position.y = (gl_Position.y*0.5+0.5)*0.25/clampedRes.y*1080.0*2.0-1.0;
	//0-0.5
	gl_Position.x = (gl_Position.x*0.5+0.5)*0.5/clampedRes.x*1920.0*2.0-1.0;
	texcoord = gl_MultiTexCoord0.xy/clampedRes*vec2(1920.,1080.);

}
