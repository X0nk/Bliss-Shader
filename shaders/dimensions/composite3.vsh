varying vec2 texcoord;
flat varying vec3 zMults;
uniform float far;
uniform float near;

flat varying vec2 TAA_Offset;
uniform int framemod8;
const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {


	TAA_Offset = offsets[framemod8];

	zMults = vec3(1.0/(far * near),far+near,far-near);
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;

}
