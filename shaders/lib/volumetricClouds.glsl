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

float LAYER0_minHEIGHT = CloudLayer0_height; 
float LAYER0_maxHEIGHT = 100 + LAYER0_minHEIGHT;

float LAYER1_minHEIGHT = max(CloudLayer1_height,LAYER0_maxHEIGHT); 
float LAYER1_maxHEIGHT = 100 + LAYER1_minHEIGHT;

float LAYER2_HEIGHT = max(CloudLayer2_height,LAYER1_maxHEIGHT); 


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

float cloudCov(int layer, in vec3 pos, vec3 samplePos, float minHeight, float maxHeight){
	float FinalCloudCoverage = 0.0;
	
	vec2 SampleCoords0 = vec2(0.0); vec2 SampleCoords1 = vec2(0.0);

	if(layer == 0){
		SampleCoords0 = (samplePos.xz + cloud_movement) / 5000;
		SampleCoords1 = (samplePos.xz - cloud_movement) / 500;
	}

	if(layer == 1){
		SampleCoords0 = -( (samplePos.zx + cloud_movement*2) / 15000);
		SampleCoords1 = -( (samplePos.zx - cloud_movement*2) / 1500);
	}

	if(layer == -1){
		float otherlayer = max(pos.y - (CloudLayer0_height+99.5), 0.0) > 0 ? 0.0 : 1.0;
		if(otherlayer > 0.0){
			SampleCoords0 = (samplePos.xz + cloud_movement) / 5000;
			SampleCoords1 = (samplePos.xz - cloud_movement) / 500;
		}else{
			SampleCoords0 = -( (samplePos.zx + cloud_movement*2) / 15000);
			SampleCoords1 = -( (samplePos.zx - cloud_movement*2) / 1500);
		}
	}

	float CloudSmall = texture2D(noisetex, SampleCoords1 ).r;
	float CloudLarge = texture2D(noisetex, SampleCoords0 ).b;

	float coverage = abs(CloudLarge*2.0 - 1.2)*0.5 - (1.0-CloudSmall);
	float Topshape = 0.0;
	float Baseshape = 0.0;

	if(layer == 0){
		// float FirstLayerCoverage = DailyWeather_Cumulus(coverage);

		float layer0 = min(min(coverage + CloudLayer0_coverage, clamp(maxHeight - pos.y,0,1)), 1.0 - clamp(minHeight - pos.y,0,1));

		Topshape = max(pos.y - (maxHeight - 75),0.0) / 200.0;
		Topshape += max(pos.y - (maxHeight - 10),0.0) / 50.0;

		Baseshape = max(minHeight + 12.5 - pos.y, 0.0) / 50.0;

		FinalCloudCoverage = max(layer0 - Topshape - Baseshape,0.0);
	}

	if(layer == 1){
		float layer1 = min(min(coverage + CloudLayer1_coverage, clamp(maxHeight - pos.y,0,1)), 1.0 - clamp(minHeight - pos.y,0,1));

		Topshape = max(pos.y - (maxHeight - 75), 0.0) / 200;
		Topshape += max(pos.y - (maxHeight - 10 ), 0.0) / 50;
		Baseshape = max(minHeight + 12.5 - pos.y, 0.0) / 50.0;

		FinalCloudCoverage = max(layer1 - Topshape - Baseshape, 0.0);
	}


	if(layer == -1){
		float LAYER0_minHEIGHT_FOG = CloudLayer0_height; 
		float LAYER0_maxHEIGHT_FOG = 100 + LAYER0_minHEIGHT_FOG;

		float LAYER1_minHEIGHT_FOG = max(CloudLayer1_height,LAYER0_maxHEIGHT); 
		float LAYER1_maxHEIGHT_FOG = 100 + LAYER1_minHEIGHT_FOG;

		#ifdef CloudLayer0 
			float layer0 = min(min(coverage + CloudLayer0_coverage, clamp(LAYER0_maxHEIGHT_FOG - pos.y,0,1)), 1.0 - clamp(LAYER0_minHEIGHT_FOG - pos.y,0,1));

			Topshape = max(pos.y - (LAYER0_maxHEIGHT_FOG - 75),0.0) / 200.0;
			Topshape += max(pos.y - (LAYER0_maxHEIGHT_FOG - 10),0.0) / 50.0;
			Baseshape = max(LAYER0_minHEIGHT_FOG + 12.5 - pos.y, 0.0) / 50.0;

			FinalCloudCoverage += max(layer0 - Topshape - Baseshape,0.0);
		#endif
		
		#ifdef CloudLayer1
			float layer1 = min(min(coverage + CloudLayer1_coverage, clamp(LAYER1_maxHEIGHT - pos.y,0,1)), 1.0 - clamp(LAYER1_minHEIGHT_FOG - pos.y,0,1));

			Topshape = max(pos.y - (LAYER1_maxHEIGHT_FOG - 75), 0.0) / 200;
			Topshape += max(pos.y - (LAYER1_maxHEIGHT_FOG - 10 ), 0.0) / 50;
			Baseshape = max(LAYER1_minHEIGHT_FOG + 12.5 - pos.y, 0.0) / 50.0;

			FinalCloudCoverage += max(layer1 - Topshape - Baseshape, 0.0);
		#endif
	}

	return FinalCloudCoverage;
}

//Erode cloud with 3d Perlin-worley noise, actual cloud value
float cloudVol(int layer, in vec3 pos,in vec3 samplePos,in float cov, in int LoD, float minHeight, float maxHeight){
	float otherlayer = max(pos.y - (CloudLayer0_height+99.5), 0.0) > 0 ? 0.0 : 1.0;
	float upperPlane = otherlayer;

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

float GetCumulusDensity(int layer, in vec3 pos, in int LoD, float minHeight, float maxHeight){

	vec3 samplePos =  pos*vec3(1.0,1./48.,1.0)/4;
	
	float coverageSP = cloudCov(layer, pos,samplePos, minHeight, maxHeight);

	// return coverageSP;
	if (coverageSP > 0.001) {
		if (LoD < 0) return max(coverageSP - 0.27*fbmAmount,0.0);
		return cloudVol(layer, pos,samplePos,coverageSP,LoD	,minHeight, maxHeight) ;
	} else return 0.0;
}

float GetAltostratusDensity(vec3 pos){

	float Coverage; float Density;
	DailyWeather_Alto(Coverage, Density);

	float large = texture2D(noisetex, (pos.xz + cloud_movement)/100000. ).b;
	float small = texture2D(noisetex, (pos.xz - cloud_movement)/10000. - vec2(-large,1-large)/5).b;
	large = max(large + Coverage - 0.5, 0.0);
	// float shape = (small + pow((1.0-large),2.0))/2.0;
	float weight = 0.7;
	float shape = max(	large*weight - small*(1.0-weight)		,0.0);
	shape *= shape;



	// infinite vertical height will mess with lighting, so get rid of it.
	// shape = max(shape - pow(abs(LAYER2_HEIGHT - pos.y)/20,1.5), 0.0);
	shape = min(min(shape , clamp((LAYER2_HEIGHT + 15) - pos.y,0,1)), 1.0 - clamp(LAYER2_HEIGHT - pos.y,0,1));

	
	// shape *= Density;

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



vec3 layerStartingPosition(
	vec3 dV_view,
	vec3 cameraPos,
	float dither,
	
	float minHeight,
	float maxHeight
){
	// allow passing through/above/below the plane without limits
	float flip = mix(max(cameraPos.y - maxHeight,0.0), max(minHeight - cameraPos.y,0), clamp(dV_view.y,0,1));

	// orient the ray to be a flat plane facing up/down
	vec3 position = dV_view*dither + cameraPos + dV_view/abs(dV_view.y) * flip;
	
	return position;
}

vec4 renderLayer(
	int layer, 
	in vec3 rayProgress, 
	in vec3 dV_view,
	in float mult,
	in float dither,

	int QUALITY,
	
	float minHeight,
	float maxHeight,

	in vec3 dV_Sun,

	float cloudDensity,
	in vec3 skyLightCol,
	in vec3 sunScatter,
	in vec3 sunMultiScatter,
	in vec3 indirectScatter,
	in float distantfog,
	bool notVisible
){
	vec3 COLOR = vec3(0.0);
	float TOTAL_EXTINCTION = 1.0;


if(layer == 2){
	if(notVisible) return vec4(COLOR, TOTAL_EXTINCTION);
	
	float signFlip = mix(-1.0, 1.0, clamp(cameraPosition.y - minHeight,0.0,1.0));
	
	if(max(signFlip * normalize(dV_view).y,0.0) <= 0.0){
		float altostratus = GetAltostratusDensity(rayProgress);
		
		if(altostratus > 1e-5){
			float muE = altostratus * cloudDensity;

			float directLight = 0.0;
			for (int j = 0; j < 2; j++){
				vec3 shadowSamplePos_high = rayProgress + dV_Sun * (0.1 + j * (0.5 + dither*0.05)) ;
				// vec3 shadowSamplePos_high = rayProgress + dV_Sun * (j * (0.5 + dither*0.05)) ;
				float shadow = GetAltostratusDensity(shadowSamplePos_high) * cloudDensity;
				directLight += shadow;
			}

			float skyscatter_alto = sqrt(altostratus*0.05);
			vec3 lighting = DoCloudLighting(altostratus, 1.0, skyLightCol, skyscatter_alto, directLight, sunScatter, sunMultiScatter, distantfog);

			COLOR += max(lighting - lighting*exp(-mult*muE),0.0) * TOTAL_EXTINCTION;
			TOTAL_EXTINCTION *= max(exp(-mult*muE),0.0);
		}
	}
	
	return vec4(COLOR, TOTAL_EXTINCTION);

}else{

	for(int i = 0; i < QUALITY; i++) {
		/// avoid overdraw
		if(notVisible) break;

		float cumulus = GetCumulusDensity(layer, rayProgress, 1, minHeight, maxHeight);
					
		float fadedDensity = cloudDensity * clamp(exp( (rayProgress.y - (maxHeight - 75)) / 9.0	 ),0.0,1.0);

		if(cumulus > 1e-5){
			float muE =	cumulus * fadedDensity;

			float directLight = 0.0;
			for (int j=0; j < 3; j++){

				vec3 shadowSamplePos = rayProgress + dV_Sun * (0.1 + j * (0.1 + dither*0.05));
				float shadow = GetCumulusDensity(layer, shadowSamplePos, 0, minHeight, maxHeight) * cloudDensity;

				directLight += shadow;
			}

		#if defined CloudLayer1 && defined CloudLayer0
			if(layer == 0) directLight += CloudLayer1_density * 2.0 * GetCumulusDensity(1, rayProgress + dV_Sun/abs(dV_Sun.y) * max((LAYER1_maxHEIGHT-70) - rayProgress.y,0.0), 0, LAYER1_minHEIGHT, LAYER1_maxHEIGHT);
		#endif

		#ifdef CloudLayer2
			// cast a shadow from higher clouds onto lower clouds
			vec3 HighAlt_shadowPos = rayProgress + dV_Sun/abs(dV_Sun.y) * max(LAYER2_HEIGHT - rayProgress.y,0.0);
			float HighAlt_shadow = GetAltostratusDensity(HighAlt_shadowPos) * CloudLayer2_density;
			directLight += HighAlt_shadow;
		#endif
		
		#if defined CloudLayer1 && defined CloudLayer0
			float upperLayerOcclusion = layer == 0 ? CloudLayer1_density * 2.0 * GetCumulusDensity(1, rayProgress + vec3(0.0,1.0,0.0) * max((LAYER1_maxHEIGHT-70) - rayProgress.y,0.0), 0, LAYER1_minHEIGHT, LAYER1_maxHEIGHT) : 0.0;
			float skylightOcclusion = max(exp2((upperLayerOcclusion*upperLayerOcclusion) * -5), 0.75 + (1.0-distantfog)*0.25);
		#else
			float skylightOcclusion = 1.0;
		#endif

			float skyScatter = clamp((maxHeight - 20 - rayProgress.y) / 275.0,0.0,1.0);
			vec3 lighting = DoCloudLighting(muE, cumulus, skyLightCol*skylightOcclusion, skyScatter, directLight, sunScatter, sunMultiScatter, distantfog);

		#if defined CloudLayer1 && defined CloudLayer0
			// a horrible approximation of direct light indirectly hitting the lower layer of clouds after scattering through/bouncing off the upper layer.
			lighting += indirectScatter * exp((skyScatter*skyScatter) * cumulus * -35.0) * upperLayerOcclusion * exp(-20.0 * pow(abs(upperLayerOcclusion - 0.3),2));
		#endif

			COLOR += max(lighting - lighting*exp(-mult*muE),0.0) * TOTAL_EXTINCTION;
			TOTAL_EXTINCTION *= max(exp(-mult*muE),0.0);

			if (TOTAL_EXTINCTION < 1e-5) break;
		}

		rayProgress += dV_view;
	}

	return vec4(COLOR, TOTAL_EXTINCTION);
}
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

	float heightRelativeToClouds = clamp(1.0 - max(cameraPosition.y - LAYER0_minHEIGHT,0.0) / 100.0 ,0.0,1.0);
	// heightRelativeToClouds*=heightRelativeToClouds;

//////////////////////////////////////////
////// Raymarching stuff 
//////////////////////////////////////////

	//project pixel position into projected shadowmap space
	vec4 viewPos = normalize(gbufferModelViewInverse * vec4(FragPosition,1.0) );
	// maxIT_clouds = int(clamp(maxIT_clouds / sqrt(exp2(viewPos.y)),0.0, maxIT));
	maxIT_clouds = int(clamp(maxIT_clouds / sqrt(exp2(viewPos.y)),0.0, maxIT));
	// maxIT_clouds = 15;

	vec3 dV_view = normalize(viewPos.xyz);
	
	// this is the cloud curvature.
	dV_view.y += 0.025 * heightRelativeToClouds;

	vec3 dV_view_Alto = dV_view;
	dV_view_Alto *= 100/abs(dV_view_Alto.y)/15;
	float mult_alto = length(dV_view_Alto);

	dV_view *= 90/abs(dV_view.y)/maxIT_clouds;
	
	float mult = length(dV_view);

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


	// use this to blend into the atmosphere's ground.
	vec3 approxdistance = normalize(dV_view);
	#ifdef SKY_GROUND
		float distantfog = mix(1.0, max(1.0 - clamp(exp2(pow(abs(approxdistance.y),1.5) * -35.0),0.0,1.0),0.0), heightRelativeToClouds);
	#else
		float distantfog = 1.0;
		float distantfog2 = mix(1.0, max(1.0 - clamp(exp(pow(abs(approxdistance.y),1.5) * -35.0),0.0,1.0),0.0), heightRelativeToClouds);
	#endif
	
	// terrible fake rayleigh scattering
	vec3 rC = vec3(sky_coefficientRayleighR*1e-6, sky_coefficientRayleighG*1e-5, sky_coefficientRayleighB*1e-5)*3;
	float atmosphere =  exp(abs(approxdistance.y) * -5.0);
	vec3 scatter = exp(-10000.0 * rC * atmosphere) * distantfog;

	directScattering *= scatter;
	directMultiScattering *= scatter;
	sunIndirectScattering *= scatter;

//////////////////////////////////////////
////// render Cloud layers and do blending orders
//////////////////////////////////////////

	// first cloud layer
	float MinHeight = LAYER0_minHEIGHT; 
	float MaxHeight = LAYER0_maxHEIGHT;

	float MinHeight1 = LAYER1_minHEIGHT;
	float MaxHeight1 = LAYER1_maxHEIGHT;

	float Height2 = LAYER2_HEIGHT;

	// int above_Layer0 = int(clamp(cameraPosition.y - MaxHeight,0.0,1.0));
	int below_Layer0 = int(clamp(MaxHeight - cameraPosition.y,0.0,1.0));

	int above_Layer1 = int(clamp(MaxHeight1 - cameraPosition.y,0.0,1.0));
	bool below_Layer1 = clamp(cameraPosition.y - MinHeight1,0.0,1.0) < 1.0;
	bool below_Layer2 = clamp(cameraPosition.y - Height2,0.0,1.0) < 1.0;
	// bool layer1_below_layer0 = MinHeight1 < MinHeight;
	
	bool altoNotVisible = false;
	
	#ifdef CloudLayer0
		vec3 layer0_start = layerStartingPosition(dV_view, cameraPosition, Dither.y, MinHeight, MaxHeight);
	#endif
	#ifdef CloudLayer1
		vec3 layer1_start = layerStartingPosition(dV_view, cameraPosition, Dither.y, MinHeight1, MaxHeight1);
	#endif
	#ifdef CloudLayer2
		vec3 layer2_start = layerStartingPosition(dV_view_Alto, cameraPosition, Dither.y, Height2, Height2);
	#endif

	#ifdef CloudLayer0
		vec4 layer0 = renderLayer(0, layer0_start, dV_view, mult, Dither.x, maxIT_clouds, MinHeight, MaxHeight, dV_Sun, CloudLayer0_density, SkyColor, directScattering, directMultiScattering, sunIndirectScattering, distantfog, false);
		total_extinction *= layer0.a;

		// stop overdraw.
		bool notVisible = layer0.a < 1e-5 && below_Layer1;
		altoNotVisible = notVisible;
	#else
		// stop overdraw.
		bool notVisible = false;
	#endif

	#ifdef CloudLayer1
		vec4 layer1 = renderLayer(1, layer1_start, dV_view, mult, Dither.x, maxIT_clouds, MinHeight1, MaxHeight1, dV_Sun, CloudLayer1_density, SkyColor, directScattering, directMultiScattering,sunIndirectScattering, distantfog, notVisible);
		total_extinction *= layer1.a;

		// stop overdraw.
		altoNotVisible = (layer1.a < 1e-5  || notVisible)&& below_Layer1;	
	#endif

	#ifdef CloudLayer2
		vec4 layer2 = renderLayer(2, layer2_start, dV_view_Alto, mult_alto, Dither.x, maxIT_clouds, Height2, Height2, dV_Sun, CloudLayer2_density, SkyColor, directScattering, directMultiScattering,sunIndirectScattering, distantfog, altoNotVisible);
		total_extinction *= layer2.a;
	#endif
	
	/// i know this looks confusing
	/// it is changing blending order based on the players position relative to the clouds.
	/// to keep it simple for myself, it all revolves around layer0, the lowest cloud layer.
	/// for layer1, swap between back to front and front to back blending if you are above or below layer0
	/// for layer2, swap between back to front and front to back blending if you are above or below layer1
	

	/// blend the altostratus clouds first, so it is BEHIND all the cumulus clouds, if the player postion is below the cumulus clouds.
	/// handle the case if one of the cloud layers is disabled.
	#if !defined CloudLayer1 && defined CloudLayer2
		if(below_Layer2) color = color * layer2.a + layer2.rgb;
	#endif
	#if defined CloudLayer1 && defined CloudLayer2 
		if(below_Layer2) layer1.rgb = layer2.rgb * layer1.a + layer1.rgb;
	#endif

	/// blend the cumulus clouds together. swap the blending order from (BACK TO FRONT -> FRONT TO BACK) depending on the player position relative to the lowest cloud layer.
	#if defined CloudLayer0 && defined CloudLayer1
		color = mix(layer0.rgb, layer1.rgb,  float(below_Layer0));
		color = mix(color * layer1.a + layer1.rgb, color * layer0.a + layer0.rgb, float(below_Layer0));
	#endif

	/// handle the case of one of the cloud layers being disabled.
	#if defined CloudLayer0 && !defined CloudLayer1
		color = color * layer0.a + layer0.rgb;
	#endif
	#if !defined CloudLayer0 && defined CloudLayer1
		color = color * layer1.a + layer1.rgb;
	#endif

	/// blend the altostratus clouds last, so it is IN FRONT of all the cumulus clouds when the player position is above them.
	#ifdef CloudLayer2
		if(!below_Layer2) color = color * layer2.a + layer2.rgb;
	#endif

	#ifndef SKY_GROUND
		vec3 normView = normalize(dV_view);
		vec4 fogcolor = vec4(skyFromTex(normView, colortex4)/30.0, 0.0);
		
		return mix(fogcolor, vec4(color, total_extinction), clamp(distantfog2,0.0,1.0));
	#else
		return vec4(color, total_extinction);
	#endif
	
}

#endif

float GetCloudShadow(vec3 feetPlayerPos){
#ifdef CLOUDS_SHADOWS

	vec3 playerPos = feetPlayerPos + cameraPosition;

	float shadow = 0.0;

	// assume a flat layer of cloud, and stretch the sampled density along the sunvector, starting from some vertical layer in the cloud.
	#ifdef CloudLayer0
		vec3 lowShadowStart = playerPos + (WsunVec / max(abs(WsunVec.y),0.2)) * max((CloudLayer0_height + 30) - playerPos.y,0.0) ;
		shadow += GetCumulusDensity(0, lowShadowStart, 1, CloudLayer0_height, CloudLayer0_height+100)*CloudLayer0_density;
	#endif
	#ifdef CloudLayer1
		vec3 higherShadowStart = playerPos + (WsunVec / max(abs(WsunVec.y),0.2)) * max((CloudLayer1_height + 30) - playerPos.y,0.0) ;
		shadow += GetCumulusDensity(1, higherShadowStart, 0, CloudLayer1_height, CloudLayer1_height+100)*CloudLayer1_density;
	#endif
	#ifdef CloudLayer2 
		vec3 highShadowStart = playerPos + (WsunVec / max(abs(WsunVec.y),0.2)) * max(CloudLayer2_height - playerPos.y,0.0);
		shadow += GetAltostratusDensity(highShadowStart) * CloudLayer2_density;
	#endif

	shadow = clamp(shadow,0.0,1.0);
	shadow *= shadow;

	shadow = exp2(shadow * -100.0);

	return mix(1.0, shadow, CLOUD_SHADOW_STRENGTH);
	
#else
	return 1.0;
#endif
}

float GetCloudShadow_VLFOG(vec3 WorldPos, vec3 WorldSpace_sunVec){
#ifdef CLOUDS_SHADOWS

	float shadow = 0.0;

	#ifdef CloudLayer0
		vec3 lowShadowStart = WorldPos + (WorldSpace_sunVec / max(abs(WorldSpace_sunVec.y),0.2)) * max((CloudLayer0_height+ 30) - WorldPos.y,0.0)  ;
		shadow += GetCumulusDensity(0, lowShadowStart, 0, CloudLayer0_height,CloudLayer0_height+100)*CloudLayer0_density;
	#endif
	#ifdef CloudLayer1
		vec3 higherShadowStart = WorldPos + (WorldSpace_sunVec / max(abs(WorldSpace_sunVec.y),0.2)) * max((CloudLayer1_height+ 30) - WorldPos.y,0.0)  ;
		shadow += GetCumulusDensity(1,higherShadowStart, 0, CloudLayer1_height,CloudLayer1_height+100)*CloudLayer1_density;
	#endif
	#ifdef CloudLayer2 
		vec3 highShadowStart = WorldPos + (WorldSpace_sunVec / max(abs(WorldSpace_sunVec.y),0.2)) * max(CloudLayer2_height - WorldPos.y,0.0);
		shadow += GetAltostratusDensity(highShadowStart)*CloudLayer2_density;
	#endif

	shadow = clamp(shadow,0.0,1.0);
	shadow *= shadow;

	shadow = exp2(shadow * -150.0);

	return mix(1.0, shadow, CLOUD_SHADOW_STRENGTH);

#else
	return 1.0;
#endif
}
