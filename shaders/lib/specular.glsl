
uniform sampler2D gaux1;
uniform int framemod8;

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);


// sun specular stuff
float square(float x){
  return x*x;
}
float g(float NdotL, float roughness){
    float alpha = square(max(roughness, 0.02));
    return 2.0 * NdotL / (NdotL + sqrt(square(alpha) + (1.0 - square(alpha)) * square(NdotL)));
}
float gSimple(float dp, float roughness){
  float k = roughness + 1;
  k *= k/8.0;
  return dp / (dp * (1.0-k) + k);
}
vec3 GGX2(vec3 n, vec3 v, vec3 l, float r, vec3 F0) {

  float roughness = r; // when roughness is zero it fucks up
  float alpha = square(roughness) + 1e-5;

  vec3 h = normalize(l + v) ;

  float dotLH = clamp(dot(h,l),0.,1.);
  float dotNH = clamp(dot(h,n),0.,1.);
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNV = clamp(dot(n,v),0.,1.);
  float dotVH = clamp(dot(h,v),0.,1.);


  float D = alpha / (3.141592653589793*square(square(dotNH) * (alpha - 1.0) + 1.0));
  float G = gSimple(dotNV, roughness) * gSimple(dotNL, roughness);
  vec3 F = F0 + (1. - F0) * exp2((-5.55473*dotVH-6.98316)*dotVH);

  return dotNL * F * (G * D / (4 * dotNV * dotNL + 1e-7));
}


// other shit
float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}
vec3 toClipSpace3(vec3 viewSpacePosition) {
    return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}
float linZ(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
	// l = (2*n)/(f+n-d(f-n))
	// f+n-d(f-n) = 2n/l
	// -d(f-n) = ((2n/l)-f-n)
	// d = -((2n/l)-f-n)/(f-n)

}
vec3 rayTrace_GI(vec3 dir,vec3 position,float dither, float quality){

    vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ? (-near -position.z) / dir.z : far*sqrt(3.);
    vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
    direction.xy = normalize(direction.xy);

    //get at which length the ray intersects with the edge of the screen
    vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
    float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);


    vec3 stepv = direction * mult / quality*vec3(RENDER_SCALE,1.0);
	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) + stepv*dither;

	float minZ = clipPosition.z+stepv.z;
	float maxZ = spos.z+stepv.z;
	spos.xy += TAA_Offset*texelSize*0.5/RENDER_SCALE;

	float dist = 1.0 + clamp(position.z*position.z/50.0,0,2); // shrink sample size as distance increases
    for (int i = 0; i <= int(quality); i++) {

		float sp = texelFetch2D(depthtex1,ivec2(spos.xy/texelSize),0).r;
        if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ)) return vec3(spos.xy/RENDER_SCALE,sp);

        spos += stepv;
		//small bias
		minZ = maxZ-(0.0001/dist)/ld(spos.z);
		maxZ += stepv.z;
    }

    return vec3(1.1);
}
// vec3 rayTrace_GI(vec3 dir,vec3 position,float dither, float quality){

// 	vec3 clipPosition = toClipSpace3(position);
// 	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
// 	                   (-near -position.z) / dir.z : far*sqrt(3.);
// 	vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
// 	direction.xy = normalize(direction.xy);

// 	//get at which length the ray intersects with the edge of the screen
// 	vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
// 	float mult = maxLengths.y;

// 	vec3 stepv = direction * mult / quality*vec3(RENDER_SCALE,1.0) * dither;
// 	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) ;

// 	spos.xy += TAA_Offset*texelSize*0.5/RENDER_SCALE;

// 	float biasdist =  clamp(position.z*position.z/50.0,1,2); // shrink sample size as distance increases

// 	for(int i = 0; i < int(quality); i++){
// 		spos += stepv;
// 		float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/texelSize/4),0).w/65000.0);
// 		float currZ = linZ(spos.z);

// 		if( sp < currZ) {
// 			float dist = abs(sp-currZ)/currZ;
// 			if (abs(dist) < biasdist*0.05) return vec3(spos.xy, invLinZ(sp))/vec3(RENDER_SCALE,1.0);
// 		}
// 		spos += stepv;
// 	}
//   return vec3(1.1);
// }

void frisvad(in vec3 n, out vec3 f, out vec3 r){
    if(n.z < -0.9) {
        f = vec3(0.,-1,0);
        r = vec3(-1, 0, 0);
    } else {
    	float a = 1./(1.+n.z);
    	float b = -n.x*n.y*a;
    	f = vec3(1. - n.x*n.x*a, b, -n.x) ;
    	r = vec3(b, 1. - n.y*n.y*a , -n.y);
    }
}
mat3 CoordBase(vec3 n){
	vec3 x,y;
    frisvad(n,x,y);
    return mat3(x,y,n);
}
float unpackRoughness(float x){
  float r = 1.0 - x;
  return clamp(r*r,0,1);
}
vec2 R2_samples_spec(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}

vec3 sampleGGXVNDF(vec3 V_, float roughness, float U1, float U2){
	// stretch view
	vec3 V = normalize(vec3(roughness * V_.x, roughness * V_.y, V_.z));
	// orthonormal basis
	vec3 T1 = (V.z < 0.9999) ? normalize(cross(V, vec3(0,0,1))) : vec3(1,0,0);
	vec3 T2 = cross(T1, V);
	// sample point with polar coordinates (r, phi)
	float a = 1.0 / (1.0 + V.z);
	float r = sqrt(U1*0.25);
	float phi = (U2<a) ? U2/a * 3.141592653589793 : 3.141592653589793 + (U2-a)/(1.0-a) * 3.141592653589793;
	float P1 = r*cos(phi);
	float P2 = r*sin(phi)*((U2<a) ? 1.0 : V.z);
	// compute normal
	vec3 N = P1*T1 + P2*T2 + sqrt(max(0.0, 1.0 - P1*P1 - P2*P2))*V;
	// unstretch
	N = normalize(vec3(roughness*N.x, roughness*N.y, N.z));
	return N;
}



vec3 rayTraceSpeculars(vec3 dir,vec3 position,float dither, float quality, bool hand){
	vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
	                   (-near -position.z) / dir.z : far*sqrt(3.);
	vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
	direction.xy = normalize(direction.xy);

	//get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
	float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);

	vec3 stepv = direction * mult / quality*vec3(RENDER_SCALE,1.0);

	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) + stepv*dither;

	float minZ = spos.z;
	float maxZ = spos.z;
	
	spos.xy += TAA_Offset*texelSize*0.5/RENDER_SCALE;

	float dist = 1.0 + clamp(position.z*position.z/50.0,0,2); // shrink sample size as distance increases
  	for (int i = 0; i <= int(quality); i++) {

		// decode depth buffer
		vec2 testthing = hand ? spos.xy*texelSize : spos.xy/texelSize/4.0; // fix for ssr on hand
		float sp = sqrt(texelFetch2D(gaux1,ivec2(testthing),0).w/65000.0);
		sp = invLinZ(sp);
		
		if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ) ) return vec3(spos.xy/RENDER_SCALE,sp);
		spos += stepv;
		
		//small bias
		float biasamount = 0.0002 / dist;
		if(hand) biasamount = 0.01;
		minZ = maxZ-biasamount / ld(spos.z);
		
		maxZ += stepv.z;
  	}
  return vec3(1.1);
}


vec3 mix_vec3(vec3 X, vec3 Y, float A){
	return X * (1.0 - A) + Y * A;
}
float mix_float(float X, float Y, float A){
	return X * (1.0 - A) + Y * A;
}


// pain
void MaterialReflections(
	vec2 texcoord,
	inout vec3 Output,
	float roughness, 
	vec3 f0,
	vec3 albedo,
    vec3 sunPos,
    vec3 sunCol,
    float diffuse,
    float lightmap,
	vec3 normal,
	vec3 np3,
	vec3 fragpos,
    vec3 noise,
    bool hand
){
	vec3 Reflections_Final = Output;

	float Outdoors = clamp((lightmap-0.6)*5.0, 0.0,1.0);
	// float Outdoors = clamp((lightmap-0.5) * , 0.0,1.0);
	
	roughness = unpackRoughness(roughness);
	f0 = f0.y == 0.0 ? vec3(0.04) : f0;

		// roughness = 0.2;
		// f0 = vec3(0.04);

	mat3 basis = CoordBase(normal);
	vec3 normSpaceView = -np3*basis ;

	// roughness stuff
	#ifdef Rough_reflections
		int seed = (frameCounter%40000);
		vec2  ij = fract(R2_samples_spec(seed) + noise.rg) ;

		vec3 H = sampleGGXVNDF(normSpaceView, roughness, ij.x, ij.y);
		if(hand) H = normalize(vec3(0.0,0.0,1.0));
	#else
		vec3 H = normalize(vec3(0.0,0.0,1.0));
	#endif
	
	vec3 Ln = reflect(-normSpaceView, H);
	vec3 L = basis * Ln;

	// fresnel stuff
	float fresnel = pow(clamp(1.0 + dot(-Ln, H),0.0,1.0),5.0);

		float fresnel2 = dot(-np3, H);

	// vec3 F = f0 + (1.0 - f0) * fresnel; 
	
	vec3 F = mix(f0, vec3(1.0), fresnel); 
	vec3 rayContrib = F;

			
	// float NdotV = clamp(normalize(dot(np3, L))*10000.,0.,1.);
    bool hasReflections = (f0.y * (1.0 - roughness * Roughness_Threshold)) > 0.01;

	if (Roughness_Threshold == 1.0){ hasReflections = roughness > -1; }

	if (!hasReflections  ) Outdoors = 0.0;


	
	// if(hand){
	// 	LOD_controller = 6;
	// 	// noise.b = 0.5; 
	// }

	// SSR, Sky, and Sun reflections
	vec4 Reflections = vec4(0.0);
	// vec3 SkyReflection = skyCloudsFromTex_Spec(L, colortex4,int(LOD_controller)).rgb / 150. * 5.;
	vec3 SkyReflection = skyCloudsFromTex(L, colortex4).rgb / 150. * 5.;

	vec3 SunReflection = diffuse * GGX2(normal, -np3,  sunPos, roughness, f0) * 8./150./3. * sunCol * Sun_specular_Strength;

	#ifndef Sky_reflection
		SkyReflection = Reflections_Final;
	#endif

	


	#ifdef Screen_Space_Reflections
		if ( hasReflections	) { // Skip SSR if ray contribution is low


			#ifdef SCREENSHOT_MODE
				float rayQuality = reflection_quality; 
			#else
				float rayQuality = mix_float(reflection_quality,0.0,dot(rayContrib,vec3(0.33))); // Scale quality with ray contribution
			#endif

			vec3 rtPos = rayTraceSpeculars( mat3(gbufferModelView) * L,fragpos.xyz,  noise.b, reflection_quality, hand);

			// float test = dot(vec2(-rtPos.x,-rtPos.y), vec2(rtPos.x,rtPos.y));
			// float LOD_controller =  clamp((1-pow(test*0.5+1.0,25))	* 10,0.0,6.0) ;

			// LOD_controller = 0;

			if (rtPos.z < 1. ){ // Reproject on previous frame
				vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rtPos) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
				previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
				previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
				if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
					Reflections.a = 1.0;
					Reflections.rgb = texture2DLod(colortex5,previousPosition.xy,0).rgb;
				}
			}
		}
	#endif

	// check if the f0 is within the metal ranges, then tint by albedo if it's true.
	vec3 Metals = f0.y > 229.5/255.0 ? clamp(albedo + fresnel,0.0,1.0) : vec3(1.0);

	Reflections.rgb *= Metals;
	SunReflection *= Metals;
	#ifdef Sky_reflection
		SkyReflection *= Metals;
	#endif
	float lumaRayContrib = pow(luma(rayContrib),1.0);
	float oneminus_lumaRayContrib = pow(1.0-luma(rayContrib),1.0);
	// darken albedos, and stop darkening where the sky gets occluded indoors
	Reflections_Final *= mix_float(1.0 - (Reflections.a*lumaRayContrib), oneminus_lumaRayContrib, Outdoors);
	
	// apply all reflections to the lighting
	Reflections_Final += Reflections.rgb * lumaRayContrib;
	Reflections_Final += SkyReflection * lumaRayContrib * (1.0-Reflections.a) * Outdoors ;

	float visibilityFactor = clamp(exp2((pow(roughness,3.0) / f0.y) * -4),0,1);
	
	#ifdef Rough_reflections
		Output = hand ? mix_vec3(Output,  Reflections_Final, visibilityFactor) : Reflections_Final;
	#else
		Output = mix_vec3(Output,  Reflections_Final, visibilityFactor);
	#endif

	Output += SunReflection ;
	// float aaaa = dot(vec2(-rtPos.x,-rtPos.y), vec2(rtPos.x,rtPos.y));
	// test = pow(test*0.5+1.0,2);
	// Output = vec3(0,test,0)  ;
}