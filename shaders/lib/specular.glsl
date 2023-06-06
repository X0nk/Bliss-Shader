
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



vec3 mix_vec3(vec3 X, vec3 Y, float A){
	return X * (1.0 - A) + Y * A;
}
float mix_float(float X, float Y, float A){
	return X * (1.0 - A) + Y * A;
}
float square(float x){
  return x*x;
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

vec3 rayTrace_GI(vec3 dir,vec3 position,float dither, float quality){

	vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
	                   (-near -position.z) / dir.z : far*sqrt(3.);
	vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
	direction.xy = normalize(direction.xy);

	//get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
	float mult = maxLengths.y;

	vec3 stepv = direction * mult / quality*vec3(RENDER_SCALE,1.0) * dither;
	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) ;

	spos.xy += TAA_Offset*texelSize*0.5/RENDER_SCALE;

	float biasdist =  clamp(position.z*position.z/50.0,1,2); // shrink sample size as distance increases

	for(int i = 0; i < int(quality); i++){
		spos += stepv;
		float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/texelSize/4),0).w/65000.0);
		float currZ = linZ(spos.z);

		if( sp < currZ) {
			float dist = abs(sp-currZ)/currZ;
			if (abs(dist) < biasdist*0.05) return vec3(spos.xy, invLinZ(sp))/vec3(RENDER_SCALE,1.0);
		}
		spos += stepv;
	}
  return vec3(1.1);
}

vec3 rayTraceSpeculars(vec3 dir,vec3 position,float dither, float quality, bool hand, inout float reflectLength){

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

		vec2 testthing = hand ? spos.xy*texelSize : spos.xy/texelSize/4.0; // fix for ssr on hand
		float sp = sqrt((texelFetch2D(colortex4,ivec2(testthing),0).a+0.1)/65000.0);
		sp = invLinZ(sp);

		if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ) ) return vec3(spos.xy/RENDER_SCALE,sp);
		spos += stepv;
		
		//small bias
		float biasamount = 0.0002 / dist;
		if(hand) biasamount = 0.01;
		minZ = maxZ-biasamount / ld(spos.z);
		maxZ += stepv.z;

		reflectLength += 1.0 / quality; // for shit
  	}


  return vec3(1.1);
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

vec3 GGX (vec3 n, vec3 v, vec3 l, float r, vec3 F0) {
  r = pow(r,2.5);
//   r*=r;

  vec3 h = l + v;
  float hn = inversesqrt(dot(h, h));

  float dotLH = clamp(dot(h,l)*hn,0.,1.);
  float dotNH = clamp(dot(h,n)*hn,0.,1.) ;
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNHsq = dotNH*dotNH;

  float denom = dotNHsq * r - dotNHsq + 1.;
  float D = r / (3.141592653589793 * denom * denom);
  vec3 F = F0 + (1. - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
  float k2 = .25 * r;

  return dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
}

// pain
void MaterialReflections(
	inout vec3 Output,
	float roughness, 
	vec3 f0,
	vec3 albedo,
    vec3 sunPos,
	vec3 directlighting,
    float lightmap,
	vec3 normal,
	vec3 np3,
	vec3 fragpos,
    vec3 noise,
    bool hand,
	bool isEntities
){
	vec3 Reflections_Final = Output;
	vec3 SkyReflection = Output;
	vec3 SunReflection = vec3(0.0);
	vec4 Reflections = vec4(0.0);

	float reflectLength;
	float Outdoors = clamp((lightmap-0.6)*5.0, 0.0,1.0);
	
	roughness = unpackRoughness(roughness);
	f0 = f0.y == 0.0 ? vec3(0.02) : f0;


	// f0 = vec3(0.0);
	// roughness = 0.0;

	mat3 basis = CoordBase(normal);
	vec3 normSpaceView = -np3*basis ;

	// roughness stuff
	#ifdef Rough_reflections
		int seed = frameCounter%40000;
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
	vec3 F = mix_vec3(f0, vec3(1.0), fresnel); 
	vec3 rayContrib = F;

	float VisibilityFactor = rayContrib.x * pow(1.0-roughness,3.0);

    bool hasReflections = Roughness_Threshold == 1.0 ? true : (f0.y * (1.0 - roughness * Roughness_Threshold)) > 0.01;
    float hasReflections2 = max(1.0 - roughness*1.75,0.0);


	// // if (!hasReflections) Outdoors = 0.0;
	
	// SunReflection = directlighting *  SunGGX(normal, -np3, sunPos, roughness, f0.y) / 5.0; 
	SunReflection = directlighting *  GGX(normal, -np3, sunPos, roughness, vec3(f0.y));
// 
	if (hasReflections) { // Skip sky reflection and SSR if its just not very visible anyway
		#ifdef Sky_reflection
			SkyReflection = ( skyCloudsFromTex(L, colortex4).rgb / 150. ) * 5.;
		#endif

		#ifdef Screen_Space_Reflections
			// #ifdef SCREENSHOT_MODEFconst
			// 	float rayQuality = reflection_quality; 
			// #else
				float rayQuality = mix_float(reflection_quality,4.0,luma(rayContrib)); // Scale quality with ray contribution
			// #endif
			// float rayQuality = reflection_quality; 
	

			vec3 rtPos = rayTraceSpeculars(mat3(gbufferModelView) * L, fragpos.xyz,  noise.b, reflection_quality, hand, reflectLength);

			float LOD = clamp(reflectLength * 6.0, 0.0,6.0);

			if(hand || isEntities) LOD = 6.0;

			if (rtPos.z < 1.) { // Reproject on previous frame
				vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rtPos) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
				previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
				previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
				if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
					Reflections.a = 1.0;
					Reflections.rgb = texture2DLod(colortex5,previousPosition.xy,LOD).rgb;
				}
			}
		#endif
	}

	// check if the f0 is within the metal ranges, then tint by albedo if it's true.
	vec3 Metals = f0.y > 229.5/255.0 ? clamp(albedo + fresnel,0.0,1.0) : vec3(1.0);

	SunReflection *= Metals;
	
	#ifdef Sky_reflection
		SkyReflection *= Metals;
	#endif
	#ifdef Screen_Space_Reflections
		Reflections.rgb *= Metals;
	#endif

	// background reflections
	SkyReflection = mix_vec3(Output, SkyReflection, Outdoors); 

	// composite background and SSR.
	Reflections.rgb = mix_vec3(SkyReflection, Reflections.rgb, Reflections.a); 

	// put reflections onto the scene
	#ifdef Rough_reflections
		Output = hand ? mix_vec3(Output,  Reflections.rgb, VisibilityFactor) : mix_vec3(Output,  Reflections.rgb, luma(rayContrib));
	#else
		Output = mix_vec3(Output,  Reflections.rgb, VisibilityFactor);
	#endif
	
	Output += SunReflection;
}

void MaterialReflections_N(
	inout vec3 Output,
	float roughness, 
	vec3 f0,
	vec3 albedo,
	vec3 normal,
	vec3 np3,
	vec3 fragpos,
    vec3 noise,
    bool hand
){
	vec3 Reflections_Final = Output;
	float reflectLength = 0.0;
	
	roughness = unpackRoughness(roughness);
	f0 = f0.y == 0.0 ? vec3(0.02) : f0;

	// roughness = 0.0;
	// f0 = vec3(0.9);

	float visibilityFactor = clamp(exp2((pow(roughness,3.0) / f0.y) * -4),0,1);

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
	vec3 F = mix(f0, vec3(1.0), fresnel); 
	vec3 rayContrib = F;

	// float NdotV = clamp(normalize(dot(np3, L))*10000.,0.,1.);
    bool hasReflections = (f0.y * (1.0 - roughness * Roughness_Threshold)) >= 0.0;
	if (Roughness_Threshold == 1.0){ hasReflections = true; }


	// SSR, Sky, and Sun reflections
	vec4 Reflections = vec4(0.0);
	vec3 FogReflection = vec3(0.0);
	#ifdef Screen_Space_Reflections
		if ( hasReflections	) { // Skip SSR if ray contribution is low

			float rayQuality = reflection_quality; 
			vec3 rtPos = rayTraceSpeculars( mat3(gbufferModelView) * L,fragpos.xyz,  noise.b, reflection_quality, hand, reflectLength);
			
			float LOD = clamp( reflectLength * 6.0 ,0.0,6.0);

			if (rtPos.z < 1. ){ // Reproject on previous frame
				vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rtPos) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
				previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
				previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
				if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
					Reflections.a = 1.0;
					Reflections.rgb = texture2DLod(colortex5,previousPosition.xy,LOD).rgb;
				}
			}
		}
	#endif


	// check if the f0 is within the metal ranges, then tint by albedo if it's true.
	vec3 Metals = f0.y > 229.5/255.0 ? clamp(albedo + fresnel,0.0,1.0) : vec3(1.0);
	Reflections.rgb *= Metals;

	#ifdef Sky_reflection
		// reflect nether fog color instead of a sky.
		FogReflection = gl_Fog.color.rgb * 0.5 * NetherFog_brightness;
		FogReflection *= 1.0 + sqrt(roughness) * 15.0; // brighten rough spots for some highlights that look neat
		FogReflection *= Metals;

		FogReflection = mix(Output, FogReflection, pow(fresnel, 0.2)+0.1); // make sure the background contains the fog reflection.
	#else
		FogReflection = Output;
	#endif

	Reflections.rgb = mix(FogReflection, Reflections.rgb, Reflections.a); // make background only where ssr is not.
	Reflections_Final = mix(Output, Reflections.rgb, luma(rayContrib)); // apply reflections to final scene color.

	#ifdef Rough_reflections
		Output = hand ? mix_vec3(Output,  Reflections_Final, visibilityFactor) : Reflections_Final;
	#else
		Output = mix_vec3(Output,  Reflections_Final, visibilityFactor);
	#endif

	// Output = vec3(reflectLength);
}

void MaterialReflections_E(
	inout vec3 Output,
	float roughness, 
	vec3 f0,
	vec3 albedo,
	vec3 normal,
	vec3 np3,
	vec3 fragpos,
    vec3 noise,
    bool hand,
	vec3 lightCol,
	vec3 lightDir,
	bool isEntities
){
	vec3 Reflections_Final = Output;
	float reflectLength = 0.0;
	
	roughness = unpackRoughness(roughness);
	f0 = f0.y == 0.0 ? vec3(0.02) : f0;

	// roughness = 0.0;
	// f0 = vec3(0.9);

	float visibilityFactor = clamp(exp2((pow(roughness,3.0) / f0.y) * -4),0,1);

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
	vec3 F = mix(f0, vec3(1.0), fresnel); 
	vec3 rayContrib = F;

	// float NdotV = clamp(normalize(dot(np3, L))*10000.,0.,1.);
    bool hasReflections = (f0.y * (1.0 - roughness * Roughness_Threshold)) >= 0.0;
	if (Roughness_Threshold == 1.0){ hasReflections = true; }


	vec3 Ln_2 = reflect(-normSpaceView, normalize(vec3(0.0,0.0,1.0)));
	vec3 L_2 = basis * Ln_2;

	vec3 FogReflection = skyCloudsFromTexLOD(L_2, colortex4, sqrt(roughness) * 9.0).rgb / 150.0;
	FogReflection = mix(FogReflection, lightCol * 2 * clamp(dot(L_2, lightDir),0,1), roughness);
	
	
	FogReflection *= 1.0 + roughness * 2.0;
	vec4 Reflections = vec4(0.0);
	
	#ifdef Screen_Space_Reflections
		if ( hasReflections	) { // Skip SSR if ray contribution is low

			float rayQuality = reflection_quality; 
			vec3 rtPos = rayTraceSpeculars( mat3(gbufferModelView) * L,fragpos.xyz,  noise.b, reflection_quality, hand, reflectLength);
			
			float LOD = clamp( reflectLength * 6.0 ,0.0,6.0);

			if(hand) LOD = 6.0;
			if(isEntities) LOD = 4.0;

			if (rtPos.z < 1. ){ // Reproject on previous frame
				vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rtPos) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
				previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
				previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
				if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
					Reflections.a = 1.0;
					Reflections.rgb = texture2DLod(colortex5,previousPosition.xy,LOD).rgb;
				}
			}
		}
	#endif


	// check if the f0 is within the metal ranges, then tint by albedo if it's true.
	vec3 Metals = f0.y > 229.5/255.0 ? clamp(albedo + fresnel,0.0,1.0) : vec3(1.0);
	Reflections.rgb *= Metals;
	FogReflection *= Metals;

	Reflections.rgb = mix(FogReflection, Reflections.rgb, Reflections.a); // make background only where ssr is not.
	Reflections_Final = mix(Output, Reflections.rgb, luma(rayContrib)); // apply reflections to final scene color.

	#ifdef Rough_reflections
		Output = hand ? mix_vec3(Output,  Reflections_Final, visibilityFactor) : Reflections_Final;
	#else
		Output = mix_vec3(Output,  Reflections_Final, visibilityFactor);
	#endif
}