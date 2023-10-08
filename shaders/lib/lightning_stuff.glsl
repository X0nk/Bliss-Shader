uniform vec3 lightningEffect;
#ifdef IS_IRIS
    uniform vec4 lightningBoltPosition;
#else
    vec4 lightningBoltPosition = vec4(0.0, 100.0, 0.0, lightningEffect.x);
#endif

vec3 Iris_Lightningflash(vec3 feetPlayerPos, vec3 lightningBoltPos, vec3 WorldSpace_normal, inout float Phase){
if(lightningBoltPosition.w > 0.0){
	vec3 LightningPos = feetPlayerPos - vec3(lightningBoltPosition.x, clamp(feetPlayerPos.y, lightningBoltPosition.y+16, lightningBoltPosition.y+116.0),lightningBoltPosition.z);

	// point light, max distance is ~500 blocks (the maximim entity render distance)
	float lightDistance = 300.0 ;
	float lightningLight = max(1.0 - length(LightningPos) / lightDistance, 0.0);

	// the light above ^^^ is a linear curve. me no likey. here's an exponential one instead.
	lightningLight = exp((1.0 - lightningLight) * -10.0);

	// a phase for subsurface scattering.
	vec3 PhasePos = normalize(feetPlayerPos) + vec3(lightningBoltPosition.x, lightningBoltPosition.y + 60, lightningBoltPosition.z);
	float PhaseOrigin = 1.0 - clamp(dot(normalize(feetPlayerPos), normalize(PhasePos)),0.0,1.0);
	Phase = exp(sqrt(PhaseOrigin) * -2.0) * 5.0 * lightningLight;

	// good old NdotL. only normals facing towards the lightning bolt origin rise to 1.0
	float NdotL = clamp(dot(LightningPos, -WorldSpace_normal), 0.0, 1.0);

	return lightningEffect * lightningLight * NdotL;
}else return vec3(0.0);
}

vec3 Iris_Lightningflash_VLcloud(vec3 feetPlayerPos, vec3 lightningBoltPos){
if(lightningBoltPosition.w > 0.0){
	vec3 LightningPos = feetPlayerPos - vec3(lightningBoltPosition.x, clamp(feetPlayerPos.y, lightningBoltPosition.y, lightningBoltPosition.y+116.0),lightningBoltPosition.z);

	float lightDistance = 400.0;
	float lightningLight = max(1.0 - length(LightningPos) / lightDistance, 0.0);

	lightningLight = exp((1.0 - lightningLight) * -10.0);

	return lightningEffect * lightningLight;
}else return vec3(0.0);
}

vec3 Iris_Lightningflash_VLfog(vec3 feetPlayerPos, vec3 lightningBoltPos){
if(lightningBoltPosition.w > 0.0){
    if(lightningBoltPosition.w < 1.0) return vec3(0.0);

	vec3 LightningPos = feetPlayerPos - vec3(lightningBoltPosition.x, clamp(feetPlayerPos.y, lightningBoltPosition.y, lightningBoltPosition.y+116.0),lightningBoltPosition.z);

	#ifdef TEST
		float lightningLight = max(1.0 - length(LightningPos) / 50, 0.0);
		lightningLight = exp((1.0 - lightningLight) * -15.0) ;
	#else
        float lightDistance = 300.0;
		float lightningLight = max(1.0 - length(LightningPos) / lightDistance, 0.0) ;

		lightningLight = exp((1.0 - lightningLight) * -15.0) ;
	#endif

	return lightningEffect * lightningLight;
}else return vec3(0.0);
}
