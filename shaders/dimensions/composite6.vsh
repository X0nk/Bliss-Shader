#include "/lib/util.glsl"

varying vec2 texcoord;
flat varying float tempOffsets;
uniform int frameCounter;

void main() {

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
	tempOffsets = HaltonSeq2(frameCounter%10000);
}
