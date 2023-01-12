
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
