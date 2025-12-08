#include "/lib/util.glsl"

varying vec2 texcoord;
flat varying float tempOffsets;
uniform sampler2D colortex4;
uniform int frameCounter;

void main() {

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;

	tempOffsets = HaltonSeq2(frameCounter%10000);

	// #if TAA_MODE == 3
	// 	gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	// #endif
}
