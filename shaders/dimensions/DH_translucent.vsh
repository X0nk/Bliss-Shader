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
uniform mat4 gbufferModelView;

flat varying vec3 WsunVec;
flat varying vec3 WsunVec2;
uniform mat4 dhProjection;
uniform vec3 sunPosition;
uniform float sunElevation;

uniform vec2 texelSize;
uniform int framemod8;

#if DOF_QUALITY == 5
uniform int hideGUI;
uniform int frameCounter;
uniform float aspectRatio;
uniform float screenBrightness;
uniform float far;
#include "/lib/bokeh.glsl"
#endif


const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);


uniform vec3 cameraPosition;
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(dhProjection, viewSpacePosition),-viewSpacePosition.z);
}
                     
void main() {
    gl_Position = ftransform();
    
	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
	
	pos = gl_ModelViewMatrix * gl_Vertex;
	

    isWater = 0;
	if (dhMaterialId == DH_BLOCK_WATER){
	    isWater = 1;
		
		// offset water to not look like a full cube
    	vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz ;
		worldpos.y -= 1.8/16.0;
    	position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;

	}

	gl_Position = toClipSpace3(position);

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

	#if DOF_QUALITY == 5
		vec2 jitter = clamp(jitter_offsets[frameCounter % 64], -1.0, 1.0);
		jitter = rotate(radians(float(frameCounter))) * jitter;
		jitter.y *= aspectRatio;
		jitter.x *= DOF_ANAMORPHIC_RATIO;

		#if MANUAL_FOCUS == -2
		float focusMul = 0;
		#elif MANUAL_FOCUS == -1
		float focusMul = gl_Position.z + (far / 3.0) - mix(pow(512.0, screenBrightness), 512.0 * screenBrightness, 0.25);
		#else
		float focusMul = gl_Position.z + (far / 3.0) - MANUAL_FOCUS;
		#endif

		vec2 totalOffset = (jitter * JITTER_STRENGTH) * focusMul * 1e-2;
		gl_Position.xy += hideGUI >= 1 ? totalOffset : vec2(0);
	#endif

}