const float k = 1.8;
const float d0 = 0.04;
const float d1 = 0.61;
float a = exp(d0);
float b = (exp(d1)-a)*150./128.0;

vec4 BiasShadowProjection(in vec4 projectedShadowSpacePosition) {
  
  float distortFactor = log(length(projectedShadowSpacePosition.xy)*b+a)*k;
  projectedShadowSpacePosition.xy /= distortFactor;
  return projectedShadowSpacePosition;
}

float calcDistort(vec2 worldpos){
  return 1.0/(log(length(worldpos)*b+a)*k);
}

uniform float far;

/*
mat4 BuildOrthoProjectionMatrix(const in float width, const in float height, const in float zNear, const in float zFar) {
    return mat4(
        vec4(2.0 / width, 0.0, 0.0, 0.0),
        vec4(0.0, 2.0 / height, 0.0, 0.0),
        vec4(0.0, 0.0, -2.0 / (zFar - zNear), 0.0),
        vec4(0.0, 0.0, -(zFar + zNear)/(zFar - zNear), 1.0));
}

mat4 BuildTranslationMatrix(const in vec3 delta) {
    return mat4(
        vec4(1.0, 0.0, 0.0, 0.0),
        vec4(0.0, 1.0, 0.0, 0.0),
        vec4(0.0, 0.0, 1.0, 0.0),
        vec4(delta, 1.0));
}

uniform vec3 CamPos; 

// vec3 LightDir = vec3(1.0, 0.5, 1.0);

float rate = frameTimeCounter;
vec3 LightDir = vec3(sin(rate), 0.3, cos(rate));
// vec3 LightDir = vec3(cos(rate),sin(rate),cos(rate));

const float shadowIntervalSize = 2.0f;  
vec3 GetShadowIntervalOffset() {
  return fract(CamPos / shadowIntervalSize) * shadowIntervalSize - vec3(3,0,1);
}

mat4 BuildShadowViewMatrix(const in vec3 localLightDir) {
  const vec3 worldUp = vec3(1, 0, 0);

  vec3 zaxis = localLightDir;

  // float check = localLightDir.y;
  // if(check < 0.0) zaxis.y = -zaxis.y;

  vec3 xaxis = normalize(cross(worldUp, zaxis));
  vec3 yaxis = normalize(cross(zaxis, xaxis));

  mat4 shadowModelViewEx = mat4(1.0);
  shadowModelViewEx[0].xyz = vec3(xaxis.x, yaxis.x, zaxis.x);
  shadowModelViewEx[1].xyz = vec3(xaxis.y, yaxis.y, zaxis.y);
  shadowModelViewEx[2].xyz = vec3(xaxis.z, yaxis.z, zaxis.z);

  vec3 intervalOffset = GetShadowIntervalOffset();
  mat4 translation = BuildTranslationMatrix(intervalOffset);
  
  return shadowModelViewEx * translation;
}

mat4 BuildShadowProjectionMatrix() {
    float maxDist = min(shadowDistance, far);
    return BuildOrthoProjectionMatrix(maxDist, maxDist, -far, far);
}

// mat4 Custom_ViewMatrix = BuildShadowViewMatrix(LightDir);
// mat4 Custom_ProjectionMatrix = BuildShadowProjectionMatrix();
*/