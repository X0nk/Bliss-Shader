#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

varying vec4 pos;
varying vec4 gcolor;
	
varying vec4 normals_and_materials;
varying vec2 lightmapCoords;
flat varying int isWater;


uniform sampler2D colortex4;
flat varying vec3 averageSkyCol_Clouds;
flat varying vec4 lightCol;

varying mat4 normalmatrix;

uniform mat4 gbufferModelViewInverse;

flat varying vec3 WsunVec;
flat varying vec3 WsunVec2;

uniform vec3 sunPosition;
uniform float sunElevation;

uniform vec2 texelSize;
uniform int framemod8;

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);
                            
void main() {
    gl_Position = ftransform();

    isWater = 0;
	if (dhMaterialId == DH_BLOCK_WATER){
	    isWater = 1;
		gl_Position.y -= 6.0/16.0;
    	gl_Position.z -= 1e-4;
	}

	normals_and_materials = vec4(normalize(gl_Normal), 1.0);

    gcolor = gl_Color;
	lightmapCoords = gl_MultiTexCoord1.xy;




	lightCol.rgb = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
	lightCol.a = float(sunElevation > 1e-5)*2.0 - 1.0;

	averageSkyCol_Clouds = texelFetch2D(colortex4,ivec2(0,37),0).rgb;

	WsunVec = lightCol.a * normalize(mat3(gbufferModelViewInverse) * sunPosition);
	WsunVec2 = lightCol.a * normalize(sunPosition);
	





	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
    #ifdef TAA
		gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
	#endif

    pos = gl_ModelViewMatrix * gl_Vertex;
}