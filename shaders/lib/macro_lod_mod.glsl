#if defined DISTANT_HORIZONS || defined VOXY
    #define USING_LOD_MOD
#endif

#ifdef DISTANT_HORIZONS
    #define LOD_DEPTHTEX0 dhDepthTex0 
    #define LOD_DEPTHTEX1 dhDepthTex1
    #define LOD_PROJECTION dhProjection
    #define LOD_PROJECTION_INVERSE dhProjectionInverse
    #define LOD_PROJECTION_PREV dhPreviousProjection
#endif

#ifdef VOXY
    #define LOD_DEPTHTEX0 vxDepthTexTrans
    #define LOD_DEPTHTEX1 vxDepthTexOpaque
    #define LOD_PROJECTION vxProj
    #define LOD_PROJECTION_INVERSE vxProjInv
    #define LOD_PROJECTION_PREV vxProjPrev
#endif

uniform sampler2D LOD_DEPTHTEX0;
uniform sampler2D LOD_DEPTHTEX1;

// the rest are custom uniforms that swap in shaders.properties
uniform float LOD_NEARPLANE;
uniform float LOD_FARPLANE;
uniform int LOD_RENDERDISTANCE;
uniform mat4 LOD_PROJECTION;
uniform mat4 LOD_PROJECTION_INVERSE;
uniform mat4 LOD_PROJECTION_PREV;