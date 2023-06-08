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

uniform float viewHeight;
uniform float viewWidth;
uniform sampler2D colortex4;//Skybox

#define WEATHERCLOUDS
#include "/lib/climate_settings.glsl"

float CumulusHeight = Cumulus_height;
float MaxCumulusHeight = CumulusHeight + 100;

float AltostratusHeight = 2000;

float rainCloudwetness = rainStrength;
float cloud_movement = frameTimeCounter * Cloud_Speed;

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

float cloudCov(in vec3 pos,vec3 samplePos){

	float CloudLarge = texture2D(noisetex, (samplePos.xz  + cloud_movement) / 5000 ).b;
	float CloudSmall = texture2D(noisetex, (samplePos.xz   - cloud_movement) / 500 ).r;

	float Topshape = max(pos.y - (MaxCumulusHeight - 75), 0.0) / 200;
	Topshape += max(exp((pos.y - MaxCumulusHeight) / 10.0 ), 0.0) ;

	float coverage =  abs(pow(CloudLarge,1)*2.0 - 1.2)*0.5 - (1.0-CloudSmall);
	float FinalShape = DailyWeather_Cumulus(coverage) - Topshape;

	// cap the top and bottom for reasons
	float capbase = sqrt(max((CumulusHeight+12.5)  - pos.y, 0.0)/50) ;
	float captop = max(pos.y - MaxCumulusHeight, 0.0);
	
	FinalShape = max(FinalShape - capbase - captop, 0.0);

	return FinalShape;
}

//Erode cloud with 3d Perlin-worley noise, actual cloud value
float cloudVol(in vec3 pos,in vec3 samplePos,in float cov, in int LoD){
	float noise = 0.0 ;
	float totalWeights = 0.0;
	float pw =  log(fbmPower1);
	float pw2 = log(fbmPower2);

	samplePos.xz -= cloud_movement/4;
	samplePos.xz += pow( max(pos.y - (CumulusHeight+20), 0.0) / 20.0,1.50);

	noise += 1.0-densityAtPos(samplePos * 200.) ;
	
	float smallnoise = densityAtPos(samplePos * 600.);
	if (LoD > 0) noise += ((1-smallnoise) - max(0.15 - abs(smallnoise * 2.0 - 0.55) * 0.5,0.0)*1.5) * 0.5;

	noise *= 1.0-cov;

	noise = noise*noise;
	float cloud = max(cov - noise*noise*fbmAmount,0.0);

	return cloud;
}


float GetCumulusDensity(in vec3 pos, in int LoD){

	vec3 samplePos =  pos*vec3(1.0,1./48.,1.0)/4;

	float coverageSP = cloudCov(pos,samplePos);


	if (coverageSP > 0.001) {
		if (LoD < 0) return max(coverageSP - 0.27*fbmAmount,0.0);
		return cloudVol(pos,samplePos,coverageSP,LoD);
	} else return 0.0;
}

float GetAltostratusDensity(vec3 pos){

	float large = texture2D(noisetex, (pos.xz + cloud_movement)/100000. ).b;
	float small = texture2D(noisetex, (pos.xz - cloud_movement)/10000. - vec2(-large,1-large)/5).b;

	float shape = (small + pow((1.0-large),2.0))/2.0;
	
	float Coverage; float Density;
	DailyWeather_Alto(Coverage,Density);

	shape = pow(max(shape + Coverage - 0.5,0.0),2.0);
	shape *= Density;

	return shape;
}



// random magic number bullshit go!
vec3 Cloud_lighting(
	float CloudShape,
	float SkyShadowing,
	float SunShadowing,
	float MoonShadowing,
	vec3 SkyColors,
	vec3 sunContribution,
	vec3 sunContributionMulti,
	vec3 moonContribution,
	float AmbientShadow,
	int cloudType,
	vec3 pos
){
	float coeeff = -30;
	// float powder = 1.0 - exp((CloudShape*CloudShape) * -800);
	float powder = 1.0 - exp(CloudShape * coeeff/3);
	float lesspowder = powder*0.4+0.6;
	
	
	vec3 skyLighting = SkyColors;

	#ifdef Altostratus
		float Coverage = 0.0; float Density = 0.0;
		DailyWeather_Alto(Coverage,Density);
		skyLighting += sunContributionMulti * exp(-SunShadowing)  * clamp((1.0 - abs(pow(Density*4.0 - 1.1,4.0))) * Coverage,0,1) ;
	#endif

	skyLighting *= exp(SkyShadowing * AmbientShadow * coeeff/2 ) * lesspowder ;


	if(cloudType == 1){
		coeeff = -10;
		skyLighting = SkyColors * exp(SkyShadowing * coeeff/15) * lesspowder;
	}

	vec3 sunLighting = exp(SunShadowing * coeeff  + powder) * sunContribution;
	sunLighting +=  exp(SunShadowing * coeeff/4 + powder*2) * sunContributionMulti;

	vec3 moonLighting = exp(MoonShadowing * coeeff / 3) * moonContribution * powder;

	return skyLighting + moonLighting  + sunLighting ;
	// return skyLighting;
}


//Mie phase function
float phaseg(float x, float g){
    float gg = g * g;
    return (gg * -0.25 + 0.25) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5) / 3.14;
}

float CustomPhase(float LightPos, float S_1, float S_2){
	float SCALE = S_2 + 0.001; // remember the epislons 0.001 is fine.
	float N = S_1;
	float N2 = N / SCALE;

	float R = 1;
	float A = pow(1.0 - pow(max(R-LightPos,0.0), N2 ),N);

	return A;
}

float PhaseHG(float cosTheta, float g) {
    float denom = 1 + g * g + 2 * g * cosTheta;
	const float Inv4Pi  = 0.07957747154594766788;

    return Inv4Pi * (1 - g * g) / (denom * sqrt(denom));
}

vec4 renderClouds(
	vec3 FragPosition,
	vec2 Dither,
	vec3 SunColor,
	vec3 MoonColor,
	vec3 SkyColor
){
	#ifndef VOLUMETRIC_CLOUDS
		return vec4(0.0,0.0,0.0,1.0);
	#endif
	float total_extinction = 1.0;
	vec3 color = vec3(0.0);

	//project pixel position into projected shadowmap space
	vec4 fragpos = normalize(gbufferModelViewInverse*vec4(FragPosition,1.0));

	maxIT_clouds = int(clamp( maxIT_clouds / sqrt(exp2(fragpos.y)),0.0, maxIT));

	vec3 dV_view = normalize(fragpos.xyz);

	dV_view.y += 0.05;

	vec3 dV_view2 = dV_view;
	float mult2 = length(dV_view2);
	
	//setup ray to start at the start of the cloud plane and end at the end of the cloud plane
	dV_view *= max(MaxCumulusHeight - CumulusHeight, 0.0)/abs(dV_view.y)/maxIT_clouds;
	float mult = length(dV_view);

	// i want the samples to stay at one point in the world, but as the height coordinates go negative everything goes insideout, so this is a work around....
	float startFlip = mix(max(cameraPosition.y - MaxCumulusHeight,0.0), max(CumulusHeight-cameraPosition.y,0), clamp(dV_view.y,0,1));
	// vec3 progress_view = dV_view*Dither.x + cameraPosition + (dV_view/abs(dV_view.y))*startFlip;
	vec3 progress_view = dV_view*Dither.x + cameraPosition + (dV_view/abs(dV_view.y))*startFlip;

	

	// thank you emin for this world interseciton thing
    // float lViewPosM = length(FragPosition) < far * 1.5 ? length(FragPosition) - 1.0 : 1000000000.0;
	// bool IntersecTerrain = false;

	////// lighitng stuff 
	float shadowStep = 200.;
	vec3 dV_Sun = normalize(mat3(gbufferModelViewInverse)*sunVec)*shadowStep;
	vec3 dV_Sun_small = dV_Sun/shadowStep;

	float SdotV = dot(sunVec,normalize(FragPosition));

	SkyColor *= clamp(abs(dV_Sun.y)/100.,0.75,1.0);
	SunColor =  SunColor * clamp(dV_Sun.y ,0.0,1.0);
	MoonColor *=  clamp(-dV_Sun.y,0.0,1.0);

	if(dV_Sun.y/shadowStep < -0.1) dV_Sun = -dV_Sun;
	
	float mieDay = phaseg(SdotV, 0.75) * 3.14;
	float mieDayMulti = phaseg(SdotV, 0.35) * 2;

	vec3 sunContribution = SunColor * mieDay;
	vec3 sunContributionMulti = SunColor * mieDayMulti ;

	float mieNight = (phaseg(-SdotV,0.8) + phaseg(-SdotV, 0.35)*4) * 6.0;
	vec3 moonContribution = MoonColor * mieNight;
	

	#ifdef Cumulus
		for(int i=0;i<maxIT_clouds;i++) {

			// IntersecTerrain = length(progress_view - cameraPosition) > lViewPosM;
			// if(IntersecTerrain) break;
			float cumulus = GetCumulusDensity(progress_view, cloudLoD);
			
			float alteredDensity = Cumulus_density * clamp(exp( (progress_view.y - (MaxCumulusHeight - 75)) / 9.0	 ),0.0,1.0);

			if(cumulus > 1e-5){
				float muE =	cumulus*alteredDensity;

				float Sunlight = 0.0;
				float MoonLight = 0.0;

				for (int j=0; j < 3; j++){

					vec3 shadowSamplePos = progress_view + (dV_Sun * 0.15) * (1 + Dither.y/2 + j);

					float shadow = GetCumulusDensity(shadowSamplePos, 0) * Cumulus_density;

					Sunlight += shadow / (1 + j);
					MoonLight += shadow;

				}

				#ifdef Altostratus
					// cast a shadow from higher clouds onto lower clouds
					vec3 HighAlt_shadowPos = progress_view + dV_Sun/abs(dV_Sun.y) * max(AltostratusHeight - progress_view.y,0.0);
					float HighAlt_shadow = GetAltostratusDensity(HighAlt_shadowPos);
					Sunlight += HighAlt_shadow;
				#endif
				
				float phase = PhaseHG(-SdotV, (1.0-cumulus));

				float ambientlightshadow = 1.0 - clamp(exp((progress_view.y - (MaxCumulusHeight - 50)) / 100.0),0.0,1.0);

				vec3 S = Cloud_lighting(muE, cumulus*Cumulus_density, Sunlight, MoonLight, SkyColor, sunContribution, sunContributionMulti, moonContribution, ambientlightshadow, 0, progress_view);

				vec3 Sint = (S - S * exp(-mult*muE)) / muE;
				color += max(muE*Sint*total_extinction,0.0);
				total_extinction *= max(exp(-mult*muE),0.0);	

				if (total_extinction < 1e-5) break;
			}
			progress_view += dV_view;
		}
	#endif


	#ifdef Altostratus
		if (max(AltostratusHeight-cameraPosition.y,0.0)/max(normalize(dV_view).y,0.0) / 100000.0 < AltostratusHeight) {

			vec3 progress_view_high = dV_view2 + cameraPosition + dV_view2/dV_view2.y * max(AltostratusHeight-cameraPosition.y,0.0);
			float altostratus = GetAltostratusDensity(progress_view_high);

			float Sunlight = 0.0;
			float MoonLight = 0.0;

			if(altostratus > 1e-5){
				for (int j = 0; j < 2; j++){
					vec3 shadowSamplePos_high = progress_view_high + dV_Sun * float(j+Dither.y);
					float shadow = GetAltostratusDensity(shadowSamplePos_high);
					Sunlight += shadow;
				}
				vec3 S = Cloud_lighting(altostratus, altostratus, Sunlight, MoonLight, SkyColor, sunContribution, sunContributionMulti, moonContribution, 1, 1, progress_view_high);

				vec3 Sint = (S - S * exp(-20*altostratus)) / altostratus;
				color += max(altostratus*Sint*total_extinction,0.0);
				total_extinction *= max(exp(-20*altostratus),0.0);
			}
		}
	#endif

	vec3 normView = normalize(dV_view);
	// Assume fog color = sky gradient at long distance
	vec3 fogColor = skyFromTex(normView, colortex4)/150. * 5.0;
	float dist = max(cameraPosition.y+CumulusHeight,abs(CumulusHeight))/abs(normView.y);
	float fog = exp(dist / -5000.0 * (1.0+rainCloudwetness*8.));

	// if(IntersecTerrain) fog = 1.0;

	return mix(vec4(fogColor,0.0), vec4(color,total_extinction), fog);
	// return vec4(color,total_extinction);
}




float GetCloudShadow(vec3 eyePlayerPos){
	vec3 playerPos = eyePlayerPos + cameraPosition;
	playerPos.y += 0.05;
	float shadow = 0.0;

	// assume a flat layer of cloud, and stretch the sampled density along the sunvector, starting from some vertical layer in the cloud.
	#ifdef Cumulus
		vec3 lowShadowStart = playerPos + WsunVec/abs(WsunVec.y) * max((MaxCumulusHeight - 70) - playerPos.y,0.0) ;
		shadow += GetCumulusDensity(lowShadowStart,1)*Cumulus_density;
	#endif

	#ifdef Altostratus 
		vec3 highShadowStart = playerPos + WsunVec/abs(WsunVec.y) * max(AltostratusHeight - playerPos.y,0.0);
		shadow += GetAltostratusDensity(highShadowStart);
	#endif

	shadow = shadow/2.0; // perhaps i should average the 2 shadows being added....
	shadow = clamp(exp(-shadow*20.0),0.0,1.0);

	return shadow;
}
float GetCloudShadow_VLFOG(vec3 WorldPos){

	float shadow = 0.0;

	// assume a flat layer of cloud, and stretch the sampled density along the sunvector, starting from some vertical layer in the cloud.
	#ifdef Cumulus
		vec3 lowShadowStart = WorldPos + WsunVec/abs(WsunVec.y) * max((MaxCumulusHeight - 70) - WorldPos.y,0.0) ;
		shadow += GetCumulusDensity(lowShadowStart,0)*Cumulus_density;
	#endif

	#ifdef Altostratus 
		vec3 highShadowStart = WorldPos + WsunVec/abs(WsunVec.y) * max(AltostratusHeight - WorldPos.y,0.0);
		shadow += GetAltostratusDensity(highShadowStart);
	#endif

	// shadow = shadow/2.0; // perhaps i should average the 2 shadows being added....
	
	shadow = clamp(exp(-shadow*15.0),0.0,1.0);

	// do not allow it to exist above the lowest cloud plane
	shadow *= clamp(((MaxCumulusHeight + CumulusHeight)*0.435 - WorldPos.y)/100,0.0,1.0) ;

	return shadow;
}
float GetAltoOcclusion(vec3 eyePlayerPos){

	vec3 playerPos = eyePlayerPos + cameraPosition;
	playerPos.y += 0.05;
	
	float shadow = 0.0;
	
	vec3 lowShadowStart = playerPos + normalize(vec3(0,1,0)) * max((MaxCumulusHeight - 70) - playerPos.y,0.0) ;
	shadow = GetCumulusDensity(lowShadowStart,0) * cloudDensity;
	
	shadow = clamp(exp(shadow * -1),0.0,1.0);
	return shadow;

}