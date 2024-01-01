#ifdef HQ_CLOUDS
	int maxIT_clouds = minRayMarchSteps;
	int maxIT = maxRayMarchSteps;
#else
	int maxIT_clouds = minRayMarchStepsLQ;
	int maxIT = maxRayMarchStepsLQ;
#endif

#ifdef HQ_CLOUDS
	const int cloudLoD = cloud_LevelOfDetail;
	const int cloudShadowLoD = cloud_ShadowLevelOfDetail;
#else
	const int cloudLoD = cloud_LevelOfDetailLQ;
	const int cloudShadowLoD = cloud_ShadowLevelOfDetailLQ;
#endif

// uniform float viewHeight;
// uniform float viewWidth;

uniform int worldTime;
#define WEATHERCLOUDS
#include "/lib/climate_settings.glsl"


float CumulusHeight = Cumulus_height;
float MaxCumulusHeight = CumulusHeight + 100;
float AltostratusHeight = Alto_height;


float rainCloudwetness = rainStrength;
// float cloud_movement = frameTimeCounter * Cloud_Speed ;
// float cloud_movement = abs((12000 - worldTime) * Cloud_Speed ) * 0.05;
float cloud_movement = (worldTime / 24.0) * Cloud_Speed;

//3D noise from 2d texture
float densityAtPos(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	
	//The y channel has an offset to avoid using two textures fetches
	vec2 xy = texture2D(noisetex, coord).yx;

	return mix(xy.r,xy.g, f.y);
}

float cloudCov(in vec3 pos, vec3 samplePos, float minHeight, float maxHeight){
	float FinalCloudCoverage = 0.0;
	vec2 SampleCoords0 = (samplePos.xz + cloud_movement) / 5000;
	vec2 SampleCoords1 = (samplePos.xz - cloud_movement) / 500;

	// float thedistance = 1.0-clamp(1.0-length((pos-cameraPosition).xz)/15000,0,1);

	// float heightRelativeToClouds = clamp(1.0 - max(cameraPosition.y - maxHeight,0.0) / 200.0 ,0.0,1.0);
	// thedistance = mix(0.0, thedistance, heightRelativeToClouds);
	
	/// when the coordinates reach a certain height, alter the sample coordinates
	if(max(pos.y - (maxHeight + 80),0.0) > 0.0){
		SampleCoords0 = -( (samplePos.zx + cloud_movement*2) / 15000);
		SampleCoords1 = -( (samplePos.zx - cloud_movement*2) / 1500);
	}
	
	float CloudSmall = texture2D(noisetex, SampleCoords1 ).r;
	float CloudLarge = texture2D(noisetex, SampleCoords0 ).b;


	float coverage = abs(CloudLarge*2.0 - 1.2)*0.5 - (1.0-CloudSmall);


	float FirstLayerCoverage = DailyWeather_Cumulus(coverage);

	/////// FIRST LAYER
	float layer0 = min(min(FirstLayerCoverage, clamp(maxHeight - pos.y,0,1)), 1.0 - clamp(minHeight - pos.y,0,1));
	
	float Topshape = max(pos.y - (maxHeight - 75),0.0) / 200.0;
	Topshape += max(pos.y - (maxHeight - 10),0.0) / 50.0;

	float Baseshape = max(minHeight + 12.5 - pos.y, 0.0) / 50.0;
	
	FinalCloudCoverage += max(layer0 - Topshape - Baseshape,0.0);

	/////// SECOND LAYER
	float layer1 = min(min(coverage+Cumulus2_coverage, clamp(maxHeight + 200 - pos.y,0,1)), 1.0 - clamp(minHeight + 200 - pos.y,0,1));
	
	Topshape = max(pos.y - (maxHeight - 75 + 200), 0.0) / 200;
	Topshape += max(pos.y - (maxHeight - 10 + 200), 0.0) / 50;
	Baseshape = max(minHeight + 12.5 + 200 - pos.y, 0.0) / 50.0;

	FinalCloudCoverage += max(layer1 - Topshape - Baseshape ,0.0);

	return FinalCloudCoverage ;
}

//Erode cloud with 3d Perlin-worley noise, actual cloud value
float cloudVol(in vec3 pos,in vec3 samplePos,in float cov, in int LoD, float minHeight, float maxHeight){
	float upperPlane = 1.0 - clamp(pos.y - (maxHeight + 80),0.0,1.0);

	float noise = 0.0 ;
	float totalWeights = 0.0;
	float pw =  log(fbmPower1);
	float pw2 = log(fbmPower2);

	samplePos.xz -= cloud_movement/4;

	// WIND
	samplePos.xz += pow( max(pos.y - (minHeight+20), 0.0) / 20.0,1.50) * upperPlane;

	noise += (1.0-densityAtPos(samplePos * mix(100.0,200.0,upperPlane)) ) * mix(2.0,1.0,upperPlane);

	if (LoD > 0) {
		float smallnoise = densityAtPos(samplePos * mix(450.0,600.0,upperPlane));
		noise += ((1-smallnoise) - max(0.15 - abs(smallnoise * 2.0 - 0.55) * 0.5,0.0)*1.5) * 0.6 * sqrt(noise);
	}

	noise *= (1.0-cov);


	noise = noise*noise  * (upperPlane*0.7+0.3);
	float cloud = max(cov - noise*noise*fbmAmount,0.0);

	return cloud;
}

float GetCumulusDensity(in vec3 pos, in int LoD, float minHeight, float maxHeight){

	vec3 samplePos =  pos*vec3(1.0,1./48.,1.0)/4;
	
	float coverageSP = cloudCov(pos,samplePos, minHeight, maxHeight);

	// return coverageSP;
	if (coverageSP > 0.001) {
		if (LoD < 0) return max(coverageSP - 0.27*fbmAmount,0.0);
		return cloudVol(pos,samplePos,coverageSP,LoD	,minHeight, maxHeight) ;
	} else return 0.0;
}

float GetAltostratusDensity(vec3 pos){

	float large = texture2D(noisetex, (pos.xz + cloud_movement)/100000. ).b;
	float small = texture2D(noisetex, (pos.xz - cloud_movement)/10000. - vec2(-large,1-large)/5).b;
	
	float shape = (small + pow((1.0-large),2.0))/2.0;

	float Coverage; float Density;
	DailyWeather_Alto(Coverage, Density);

	shape = pow(max(shape + Coverage - 0.5,0.0),2.0);
	shape *= Density;

	return shape;
}

#ifndef CLOUDSHADOWSONLY
uniform sampler2D colortex4; //Skybox


//Mie phase function
float phaseg(float x, float g){
    float gg = g * g;
    return (gg * -0.25 + 0.25) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5) / 3.14;
}


// random magic number bullshit go!
vec3 DoCloudLighting(
	float density,
	float densityFaded,
	
	vec3 skyLightCol,
	float skyScatter,

	float sunShadows,
	vec3 sunScatter,
	vec3 sunMultiScatter,
	float distantfog

){
	// float powder = 1.0 - exp((CloudShape*CloudShape) * -800);
	float powder = 1.0 - exp(densityFaded * -10);
	float lesspowder = powder*0.4+0.6;
	
	vec3 skyLight = skyLightCol;

	float skyLightShading = exp2((skyScatter*skyScatter) * densityFaded * -35.0) * lesspowder;

	skyLight *= mix(1.0, skyLightShading, distantfog);

	vec3 sunLight = exp(sunShadows * -15 + powder ) * sunScatter;
	sunLight +=  exp(sunShadows * -3) * sunMultiScatter * (powder*0.7+0.3);

	// return skyLight;
	// return sunLight;
	return skyLight + sunLight;
}

vec4 renderClouds(
	vec3 FragPosition,
	vec2 Dither,
	vec3 LightColor,
	vec3 SkyColor
){	

	#ifndef VOLUMETRIC_CLOUDS
		return vec4(0.0,0.0,0.0,1.0);
	#endif
	float total_extinction = 1.0;
	vec3 color = vec3(0.0);

	float heightRelativeToClouds = clamp(1.0 - max(cameraPosition.y - (Cumulus_height+150),0.0) / 200.0 ,0.0,1.0);
	
	bool isAlto = false;

//////////////////////////////////////////
////// lighting stuff 
//////////////////////////////////////////

	float shadowStep = 200.0;

	vec3 dV_Sun = WsunVec*shadowStep;
	float SdotV = dot(mat3(gbufferModelView)*WsunVec, normalize(FragPosition));

	float mieDay = phaseg(SdotV, 0.75);
	float mieDayMulti = (phaseg(SdotV, 0.35) + phaseg(-SdotV, 0.35) * 0.5) ;
	
	vec3 directScattering = LightColor * mieDay * 3.14;
	vec3 directMultiScattering = LightColor * mieDayMulti * 4.0;

	vec3 sunIndirectScattering = LightColor * phaseg(dot(mat3(gbufferModelView)*vec3(0,1,0),normalize(FragPosition)), 0.5) * 3.14;
	

//////////////////////////////////////////
////// Raymarching stuff 
//////////////////////////////////////////

	//project pixel position into projected shadowmap space
	vec4 viewPos = normalize(gbufferModelViewInverse * vec4(FragPosition,1.0) );
	// maxIT_clouds = int(clamp(maxIT_clouds / sqrt(exp2(viewPos.y)),0.0, maxIT));
	maxIT_clouds = int(clamp(maxIT_clouds / sqrt(exp2(viewPos.y)),0.0, maxIT));
	maxIT_clouds = 30;

	vec3 dV_view = normalize(viewPos.xyz);
	
	// this is the cloud curvature.
	dV_view.y += 0.05 * heightRelativeToClouds;

	vec3 dV_view_Alto = dV_view;
	dV_view_Alto *= 300/abs(dV_view_Alto.y)/30;
	

	dV_view *= 300/abs(dV_view.y)/maxIT_clouds;
	
	float mult = length(dV_view);
	
	
	// first cloud layer
	float MinHeight_0 = Cumulus_height;
	float MaxHeight_0 = 100 + MinHeight_0;

	// second cloud layer
	float MinHeight_1 = MaxHeight_0 + 50;
	float MaxHeight_1 = 100 + MinHeight_1;

	float startFlip = mix(max(cameraPosition.y - MaxHeight_0 - 200,0.0), max(MinHeight_0 - cameraPosition.y,0), clamp(dV_view.y,0,1));
	vec3 progress_view = dV_view*Dither.y + cameraPosition + dV_view/abs(dV_view.y) * startFlip;

	// use this to blend into the atmosphere's ground.
	vec3 forg = normalize(dV_view);
	float distantfog = max(1.0 - clamp(exp2(pow(abs(forg.y),1.5) * -35.0),0.0,1.0),0.0);

	// terrible fake rayleigh scattering
	vec3 rC = vec3(sky_coefficientRayleighR*1e-6, sky_coefficientRayleighG*1e-5, sky_coefficientRayleighB*1e-5)*3;
	float atmosphere =  exp(abs(forg.y) * -5.0);
	vec3 scatter = mix(vec3(1.0), exp(-10000.0 * rC * atmosphere) * distantfog, heightRelativeToClouds);

	directScattering *= scatter;
	directMultiScattering *= scatter;
	sunIndirectScattering *= scatter;

#ifdef Altostratus
		isAlto = true;

		float startFlip_alto = mix(max(cameraPosition.y - AltostratusHeight,0.0), max(AltostratusHeight - cameraPosition.y,0), clamp(dV_view.y,0,1));
		float signFlip = mix(-1.0, 1.0, clamp(cameraPosition.y - AltostratusHeight,0.0,1.0));
		bool is_alto_below_cumulus = AltostratusHeight < MinHeight_0;
		
		// blend alt clouds at different stages so it looks correct when flying above or below it, in relation to the cumulus clouds.
		float altostratus = 0; vec3 Lighting_alto = vec3(0);
		if(max(signFlip * normalize(dV_view).y,0.0) <= 0.0){ 

			vec3 progress_view_high = dV_view_Alto + cameraPosition + dV_view_Alto/abs(dV_view_Alto.y) * startFlip_alto; //max(AltostratusHeight-cameraPosition.y,0.0);
			altostratus = GetAltostratusDensity(progress_view_high);

			float directLight = 0.0;

			if(altostratus > 1e-5){
				for (int j = 0; j < 2; j++){
					vec3 shadowSamplePos_high = progress_view_high + dV_Sun * (0.1 + j + Dither.y);
					float shadow = GetAltostratusDensity(shadowSamplePos_high);
					directLight += shadow; /// (1+j);
				}
				float skyscatter_alto = sqrt(altostratus*0.05);
				Lighting_alto = DoCloudLighting(altostratus, 1.0, SkyColor, skyscatter_alto, directLight, directScattering, directMultiScattering, distantfog);
			}
		}

		// blend them to appear IN FRONT the cumulus clouds in conditions
		if((signFlip > 0 && !is_alto_below_cumulus) || (signFlip < 0 && is_alto_below_cumulus)){
			color += max(Lighting_alto - Lighting_alto*exp(-mult*altostratus),0.0) * total_extinction;
			total_extinction *= max(exp(-mult*altostratus),0.0);
		}

#endif // Altostratus

#ifdef Cumulus
		for(int i = 0; i < maxIT_clouds; i++) {
			// determine the base of each cloud layer
			bool isUpperLayer = max(progress_view.y - MinHeight_1,0.0) > 0.0;
			float CloudBaseHeights = isUpperLayer ? 200.0 + MaxHeight_0 : MaxHeight_0;
			
			float cumulus = GetCumulusDensity(progress_view, 1, MinHeight_0, MaxHeight_0);
			
			float fadedDensity = Cumulus_density * clamp(exp( (progress_view.y - (CloudBaseHeights - 75)) / 9.0	 ),0.0,1.0);

			if(cumulus > 1e-5){
				float muE =	cumulus*fadedDensity;

				float directLight = 0.0;
				for (int j=0; j < 3; j++){

					vec3 shadowSamplePos = progress_view + dV_Sun * (0.1 + j * (0.1 + Dither.x*0.05));
					float shadow = GetCumulusDensity(shadowSamplePos, 0, MinHeight_0, MaxHeight_0) * Cumulus_density;

					directLight += shadow;// / (1 + j);
				}

				if(max(progress_view.y - MaxHeight_1 + 50,0.0) < 1.0) directLight += Cumulus_density * 2.0 * GetCumulusDensity(progress_view + dV_Sun/abs(dV_Sun.y) * max((MaxHeight_1 - 30.0) - progress_view.y,0.0), 0, MinHeight_0, MaxHeight_0);

				#ifdef Altostratus
					// cast a shadow from higher clouds onto lower clouds
					vec3 HighAlt_shadowPos = progress_view + dV_Sun/abs(dV_Sun.y) * max(AltostratusHeight - progress_view.y,0.0);
					float HighAlt_shadow = 2.0 * GetAltostratusDensity(HighAlt_shadowPos) ;
					directLight += HighAlt_shadow;
				#endif

				float upperLayerOcclusion = !isUpperLayer ? Cumulus_density * 2.0 * GetCumulusDensity(progress_view + vec3(0.0,1.0,0.0) * max((MaxHeight_1 - 30.0) - progress_view.y,0.0), 0, MinHeight_0, MaxHeight_0) : 0.0;
				float skylightOcclusion = max(exp2((upperLayerOcclusion*upperLayerOcclusion) * -5), 0.75 + (1.0-distantfog)*0.25);
				
				float skyScatter = clamp((CloudBaseHeights - 20 - progress_view.y) / 275.0,0.0,1.0);
				vec3 Lighting = DoCloudLighting(muE, cumulus, SkyColor*skylightOcclusion, skyScatter, directLight, directScattering, directMultiScattering, distantfog);

				// a horrible approximation of direct light indirectly hitting the lower layer of clouds after scattering through/bouncing off the upper layer.
				Lighting += sunIndirectScattering * exp((skyScatter*skyScatter) * cumulus * -35.0) * upperLayerOcclusion * exp(-20.0 * pow(abs(upperLayerOcclusion - 0.3),2));



				color += max(Lighting - Lighting*exp(-mult*muE),0.0) * total_extinction;
				total_extinction *= max(exp(-mult*muE),0.0);

				if (total_extinction < 1e-5) break;
			}
			progress_view += dV_view;
		}
#endif // Cumulus

#ifdef Altostratus
	// blend them to appear BEHIND the cumulus clouds in conditions
	if((signFlip < 0 && !is_alto_below_cumulus) || (signFlip > 0 && is_alto_below_cumulus)){
		color += max(Lighting_alto - Lighting_alto*exp(-mult*altostratus),0.0) * total_extinction;
		total_extinction *= max(exp(-mult*altostratus),0.0);
	}
#endif // Altostratus

	return vec4(color, total_extinction);

}

#endif

float GetCloudShadow(vec3 feetPlayerPos){
#ifdef CLOUDS_SHADOWS
	float MinHeight_0 = Cumulus_height;
	float MaxHeight_0 = 100 + MinHeight_0;


	vec3 playerPos = feetPlayerPos + cameraPosition;

	float shadow = 0.0;

	// assume a flat layer of cloud, and stretch the sampled density along the sunvector, starting from some vertical layer in the cloud.
	#ifdef Cumulus
		vec3 lowShadowStart = playerPos + (WsunVec / max(abs(WsunVec.y),0.2)) * max((MaxCumulusHeight - 70) - playerPos.y,0.0) ;
		shadow += GetCumulusDensity(lowShadowStart, 1, MinHeight_0, MaxHeight_0)*Cumulus_density;
		
		vec3 higherShadowStart = playerPos + (WsunVec / max(abs(WsunVec.y),0.2)) * max((MaxCumulusHeight + 200 - 70) - playerPos.y,0.0) ;
		shadow += GetCumulusDensity(higherShadowStart, 0, MinHeight_0, MaxHeight_0)*Cumulus_density;
	#endif

	#ifdef Altostratus 
		vec3 highShadowStart = playerPos + (WsunVec / max(abs(WsunVec.y),0.2)) * max(AltostratusHeight - playerPos.y,0.0);
		shadow += GetAltostratusDensity(highShadowStart) * 0.5;
	#endif

	shadow = clamp(shadow,0.0,1.0);
	shadow *= shadow;

	shadow = exp2(shadow * -100.0);

	return shadow;
	
#else
	return 1.0;
#endif
}

float GetCloudShadow_VLFOG(vec3 WorldPos, vec3 WorldSpace_sunVec){
#ifdef CLOUDS_SHADOWS
	float MinHeight_0 = Cumulus_height;
	float MaxHeight_0 = 100 + MinHeight_0;

	float shadow = 0.0;
	// assume a flat layer of cloud, and stretch the sampled density along the sunvector, starting from some vertical layer in the cloud.
	#ifdef Cumulus
		vec3 lowShadowStart = WorldPos + (WorldSpace_sunVec / max(abs(WorldSpace_sunVec.y),0.2)) * max((MaxCumulusHeight - 60) - WorldPos.y,0.0)  ;
		shadow += max(GetCumulusDensity(lowShadowStart, 0,MinHeight_0,MaxHeight_0), 0.0)*Cumulus_density;

		
		vec3 higherShadowStart = WorldPos + (WorldSpace_sunVec / max(abs(WorldSpace_sunVec.y),0.2)) * max((MaxCumulusHeight + 200 - 60) - WorldPos.y,0.0)  ;
		shadow += max(GetCumulusDensity(higherShadowStart, 0,MinHeight_0,MaxHeight_0), 0.0)*Cumulus_density;

	#endif

	#ifdef Altostratus 
		vec3 highShadowStart = WorldPos + (WorldSpace_sunVec / max(abs(WorldSpace_sunVec.y),0.2)) * max(AltostratusHeight - WorldPos.y,0.0);
		shadow += GetAltostratusDensity(highShadowStart)*0.5;
	#endif

	shadow = clamp(shadow,0.0,1.0);
	shadow *= shadow;

	shadow = exp2(shadow * -150.0);

	return shadow;

#else
	return 1.0;
#endif
}
