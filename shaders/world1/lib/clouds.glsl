vec3 cloud2D(vec3 fragpos,vec3 col){
	vec3 wpos = fragpos;
	float wind = frameTimeCounter/200.;
	vec2 intersection = ((2000.0-cameraPosition.y)*wpos.xz*inversesqrt(wpos.y+cameraPosition.y/512.-50./512.) + cameraPosition.xz+wind)/40000.;
	
	
	float phase = pow(clamp(dot(fragpos,sunVec),0.,1.),2.)*0.5+0.5;
	
	float fbm = clamp((texture2D(noisetex,intersection*vec2(1.,1.5)).a + texture2D(noisetex,intersection*vec2(2.,7.)+wind*0.4).a/2.)-0.5*(1.0-rainStrength),0.,1.) ;

		
	

	return mix(col,6.*(vec3(0.9,1.2,1.5)*skyIntensityNight*0.02*(1.0-rainStrength*0.9)+17.*phase*nsunColor*skyIntensity*0.7*(1.0-rainStrength*0.9)),0.0*(fbm*fbm)*(fbm*fbm)*(fbm*clamp(wpos.y*0.9,0.,1.)));
	
}