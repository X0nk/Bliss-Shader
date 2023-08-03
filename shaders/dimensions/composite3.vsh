#include "/lib/util.glsl"

varying vec2 texcoord;
flat varying float exposureA;
flat varying float tempOffsets;
uniform sampler2D colortex4;
uniform int frameCounter;



void main() {

	tempOffsets = HaltonSeq2(frameCounter%10000);
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
	exposureA = texelFetch2D(colortex4,ivec2(10,37),0).r;
}
