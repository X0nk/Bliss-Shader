#version 120
//Horizontal bilateral blur for volumetric fog + Forward rendered objects + Draw volumetric fog
#extension GL_EXT_gpu_shader4 : enable



varying vec2 texcoord;
flat varying vec3 zMults;
uniform sampler2D depthtex0;
uniform sampler2D colortex3;
uniform sampler2D colortex2;
uniform sampler2D colortex0;

uniform int frameCounter;
uniform float far;
uniform float near;
uniform int isEyeInWater;

uniform vec2 texelSize;
float ld(float depth) {
    return 1.0 / (zMults.y - depth * zMults.z);		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}


void main() {
/* DRAWBUFFERS:3 */
  vec3 color = texture2D(colortex3,texcoord).rgb;
  vec4 transparencies = texture2D(colortex2,texcoord);
  color = color*(1.0-transparencies.a)+transparencies.rgb*10.;

  vec4 vl = texture2D(colortex0,texcoord);

  color *= vl.a;
  color += vl.rgb;

	gl_FragData[0].rgb = clamp(color,6.11*1e-5,65000.0);
}
