uniform float far;
uniform int dhRenderDistance;

const float k = 1.8;
const float d0 = 0.04  + max(64.0 - shadowDistance, 0.0)/64.0  * 0.26;
const float d1 = 0.61;
float a = exp(d0);
float b = (exp(d1)-a)*150./128.0;

// thank you Espen
// #ifdef DISTANT_HORIZONS_SHADOWMAP
//   float b = (exp(d1)-a)*min(dhRenderDistance, shadowDistance)/shadowDistance;
// #else
//   float b = (exp(d1)-a)*min(far+16.0*3.5, shadowDistance)/shadowDistance;
// #endif

vec4 BiasShadowProjection(in vec4 projectedShadowSpacePosition) {
  
  float distortFactor = log(length(projectedShadowSpacePosition.xy)*b+a)*k;
  projectedShadowSpacePosition.xy /= distortFactor;
  return projectedShadowSpacePosition;
}

float calcDistort(vec2 worldpos){
  return 1.0/(log(length(worldpos)*b+a)*k);
}