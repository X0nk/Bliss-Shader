

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
// uniform float lightningFlash;

#define WEATHERCLOUDS
#include "/lib/climate_settings.glsl"


float maxHeight = 5000.;
float cloud_height = 1500.;

// quick variables
float rainCloudwetness = rainStrength ;
float rainClouds = rainCloudwetness;

float cloud_movement1 = frameTimeCounter * cloud_speed * 0.001;


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

float cloudshape = 0.0;

float cloudCov(in vec3 pos,vec3 samplePos){
	
	// float CloudLarge = texture2D(noisetex, samplePos.xz/150000  + cloud_movement1	).b;
	// float CloudSmall = texture2D(noisetex, samplePos.xz/15000 	- cloud_movement1	+ vec2(1-CloudLarge,-CloudLarge)/5).r;


	// float coverage = CloudSmall-CloudLarge;

	// // float mult = max( abs(pos.y - (maxHeight+cloud_height)*0.4 ) / 5000, 0); 
	
	// float mult = max( abs(pos.y-1750) / 5000, 0);


	// cloudshape = DailyWeather_LowAltitude(coverage) - mult ;

	// return max(cloudshape,0.0);




	float CloudLarge = texture2D(noisetex, samplePos.xz/150000  + cloud_movement1).b;
	float CloudSmall = texture2D(noisetex, samplePos.xz/15000 	- cloud_movement1	+ vec2(1-CloudLarge,-CloudLarge)/5).r;

	float coverage = (CloudSmall) - pow(CloudLarge*0.5+0.5,1.5);

	float mult = max( abs(pos.y - (maxHeight+cloud_height)*0.4 ) / 5000, 0); 
	// float mult = max( abs(pos.y-1750) / 5000, 0);

	cloudshape = DailyWeather_LowAltitude(coverage) - mult;

	return max(cloudshape,0.0);
}
//Erode cloud with 3d Perlin-worley noise, actual cloud value
float cloudVol(in vec3 pos,in vec3 samplePos,in float cov, in int LoD){
	float noise = 0.0 ;
	float totalWeights = 0.0;
	float pw =  log(fbmPower1);
	float pw2 = log(fbmPower2);

	// samplePos.xyz -= cloud_movement1.xyz*400;

	for (int i = 0; i <= LoD; i++){
		float weight = exp(-i*pw2);

		noise += weight - densityAtPos(samplePos * 8 * exp(i*pw) )*weight  ;
		totalWeights += weight ;
	}

	noise *= clamp(1.0-cloudshape,0.0,1.0);
	noise /= totalWeights;
	noise = noise*noise;
	float cloud = max(cov-noise*noise*fbmAmount,0.0);

	// // noise =  (1.0 - densityAtPos(samplePos * 4.));
	// // samplePos = floor(samplePos*)/16;
	// noise += ((1.0 - densityAtPos(samplePos * 16.))*0.5+0.5) 	* 	(1.0 - densityAtPos(samplePos * 4.));
	// // noise += (1.0 - densityAtPos(samplePos / 160 * 1000.));
	// noise *=  clamp(pow(1.0-cloudshape,0.5),0.0,1.0);

	// float cloud = max(cov - noise*noise*noise,0.0) ;
	
	return cloud;
}

float getCloudDensity(in vec3 pos, in int LoD){

	
	// vec3 samplePos = floor((pos*vec3(1.0,1./48.,1.0)/4 ) /512)*512 ;
	vec3 samplePos =  pos*vec3(1.0,1./48.,1.0)/4;
	float coverageSP = cloudCov(pos,samplePos);

	if (coverageSP > 0.001) {
		if (LoD < 0) return max(coverageSP - 0.27*fbmAmount,0.0);
		return cloudVol(pos,samplePos,coverageSP, LoD);
	} else return 0.0;
}

float HighAltitudeClouds(vec3 pos){
	vec2 pos2d = pos.xz/100000.0 ;

	float cloudLarge = texture2D(noisetex, pos2d/5. ).b;
	float cloudSmall = texture2D(noisetex, pos2d + vec2(-cloudLarge,cloudLarge)/10).b;
	
	
	// #ifdef Dynamic_Sky
	// 	coverage = max(10.3 - Weather_properties.g*10.,0.0);
	// 	// thickness = Weather_properties.g*3 ;
	// #endif

	float coverage = 1;
	float thickness = 1;
	DailyWeather_HighAltitude(coverage, thickness);

	float cirrusFinal = exp(pow((cloudSmall + cloudLarge),thickness) * -coverage );
	return max(cirrusFinal,0.0);
}

//Mie phase function
float phaseg(float x, float g){
    float gg = g * g;
    return (gg * -0.25 + 0.25) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5) /3.14;
}

// random magic number bullshit go!
vec3 Cloud_lighting(
	vec3 Pos,
	float CloudShape,
	float SkyShadowing,
	float SunShadowing,
	float MoonShadowing,
	vec3 SkyColors,
	vec3 sunContribution,
	vec3 sunContributionMulti,
	vec3 moonContribution,
	vec3 moonContributionMulti,
	int cloudType
){
	// low altitude
	float powder = 1.0 - exp(-CloudShape * 400.0);
	float ambientShading = exp(-SkyShadowing * 50. + powder)*powder ;
	vec3 ambientLighting = SkyColors * ambientShading;

	
	vec3 sunLighting = exp(-SunShadowing)*sunContribution	+	exp(-SunShadowing * 0.2)*sunContributionMulti;
	sunLighting *= powder;
	
	vec3 moonLighting = exp(-MoonShadowing)*moonContribution	+	exp(-MoonShadowing * 0.2)*moonContributionMulti;
	moonLighting *= powder;

	return ambientLighting + sunLighting + moonLighting;


 
	// low altitude
	// float powder = max(1.0 - exp2(-CloudShape*100.0),0.0);
	// float ambientShading = (powder*0.8+0.2) * exp2(-SkyShadowing * 50.);
	// vec3 ambientLighting = SkyColors * 4.0 * ambientShading;

	// if(cloudType == 1) ambientLighting = SkyColors * (1.0-powder/2);

	// vec3 sunLighting  = ( exp2(-SunShadowing * 2.0 )*sunContribution + exp(-SunShadowing * 0.2 )*sunContributionMulti  ) * powder;
	// vec3 moonLighting  = ( exp2(-MoonShadowing * 2.0 )*moonContribution + exp(-MoonShadowing * 0.2 )*moonContributionMulti  ) * powder;

	// // if(cloudType == 0) sunLighting *= clamp((1.05-CirrusCoverage),0,1); // less sunlight hits low clouds if high clouds have alot of coverage

	// return ambientLighting + sunLighting + moonLighting;
}

vec3 pixelCoord (vec3 Coordinates, int Resolution){
	return floor(Coordinates / Resolution) * Resolution;
}

vec3 startOffset = vec3(0);
vec4 renderClouds(
	vec3 fragpositi,
	vec3 color,
	float dither,
	vec3 sunColor,
	vec3 moonColor,
	vec3 avgAmbient,
	float dither2
){
	#ifndef VOLUMETRIC_CLOUDS
		return vec4(0.0,0.0,0.0,1.0);
	#endif

	float vL = 0.0;
	float total_extinction = 1.0;
	color = vec3(0.0);

	//project pixel position into projected shadowmap space
	vec4 fragposition = gbufferModelViewInverse*vec4(fragpositi,1.0);

	vec3 worldV = normalize(fragposition.rgb);
	float VdotU = worldV.y;

	//project view origin into projected shadowmap space
	vec4 start = (gbufferModelViewInverse*vec4(0.0,0.0,0.,1.));
	
	// vec3 dV_view = worldV;

	// cloud plane curvature
	float curvature = 0.05;
	worldV.y += curvature;
	vec3 dV_view = worldV;
	worldV.y -= curvature;
	vec3 dV_view2 = worldV;



	maxIT_clouds = int(clamp( maxIT_clouds / sqrt(exp2(VdotU)),0.0, maxIT));

	worldV = normalize(worldV)*100000. + cameraPosition; //makes max cloud distance not dependant of render distance
	dV_view = normalize(dV_view);

	float height = Cloud_Height;
	int flipClouds = 1;
	// if (worldV.y < cloud_height){
	// 	flipClouds = -1;
	// };

	if (worldV.y < cloud_height  || cameraPosition.y > 390. ) return vec4(0.,0.,0.,1.);	//don't trace if no intersection is possible
	// if (worldV.y < cloud_height && flipClouds == -1) return vec4(0.,0.,0.,1.);	//don't trace if no intersection is possible

	//setup ray to start at the start of the cloud plane and end at the end of the cloud plane
	dV_view *= max(maxHeight - cloud_height, 0.0)/dV_view.y/(maxIT_clouds);

	// dV_view = floor(dV_view/1000)*1000;
	startOffset = dV_view*dither;

	vec3 camPos = ((cameraPosition*flipClouds)-height)*Cloud_Size;
	
	vec3 progress_view = startOffset + camPos + dV_view*(cloud_height-camPos.y)/dV_view.y;
	// progress_view = floor
	float shadowStep = 200.;
	vec3 dV_Sun = flipClouds * normalize(mat3(gbufferModelViewInverse)*sunVec)*shadowStep;
	float mult = length(dV_view);

	float SdotV = dot(sunVec,normalize(fragpositi));

	float spinX  =  sin(frameTimeCounter       *3.14);
	float spinZ = 	sin(1.57 + frameTimeCounter*3.14);
	float SdotV_custom = dot(mat3(gbufferModelView) * normalize(vec3(0,0.1,0)),normalize(fragpositi));

	float phaseLightning = phaseg(SdotV_custom, 0.7);

	// direct light colors and shit for clouds
	// multiply everything by ~pi just for good luck :D
	// float mieDayMulti = phaseg(SdotV, 0.35)*3.14;
	// float mieDay = mix(phaseg(SdotV,0.75), mieDayMulti,0.8)*3.14;

	float mieDayMulti = phaseg(SdotV, 0.35);
	float mieDay = phaseg(SdotV,0.75) + mieDayMulti;

	float mieNightMulti = phaseg(-SdotV, 0.35);
	float mieNight = phaseg(-SdotV,0.75) + mieNightMulti;

	vec3 sunContribution = mieDay*sunColor*3.14;
	vec3 sunContributionMulti = mieDayMulti*sunColor*3.14;

	vec3 moonContribution = mieNight*moonColor*3.14;
	vec3 moonContributionMulti = mieNightMulti*moonColor*3.14;

	float ambientMult = 1.0;
	vec3 skyCol0 = (avgAmbient * ambientMult) ;

	vec3 progress_view_high = progress_view + (20000.0-progress_view.y) * dV_view / dV_view.y;
	float muEshD_high = 0.0;
	float muEshN_high = 0.0;

	float cirrusShadowStep = 7.;
	float cirrusDensity = 0.03;
	// progress_view = floor(progress_view/512)*512;
	
	float cloud = 0.0;
	for(int i=0;i<maxIT_clouds;i++) {

		#ifdef Cumulus_Clouds
			cloud = getCloudDensity(progress_view, cloudLoD);
		#endif

		// float basefade = clamp( (progress_view.y - 1750 ) /  1750  ,0.0,1.0) ;
		float basefade = clamp( (progress_view.y - (maxHeight+cloud_height)*0.25) / ((maxHeight+cloud_height)*0.5)  ,0.0,1.0) ;
		// float basefade = clamp( exp( (progress_view.y - (maxHeight+cloud_height)*0.5 ) / 5/00)   ,0.0,1.0) ;

		float densityofclouds =  basefade*cloudDensity ;
		
		if(cloud >= 0.0){
			float muS = cloud*densityofclouds;
			float muE =	cloud*densityofclouds;

			float muEshD = 0.0;
			if (sunContribution.g > 1e-5){
				for (int j=0; j < self_shadow_samples; j++){
					float sample = j+dither2;

					#ifdef Cumulus_Clouds
						// low altitude clouds shadows
						vec3 shadowSamplePos = progress_view + dV_Sun * (sample + sample*2.0);

						if (shadowSamplePos.y < maxHeight){
							float cloudS = getCloudDensity(vec3(shadowSamplePos), cloudShadowLoD);
							muEshD += cloudS*cloudDensity*shadowStep;
						}
					#endif
					
					#ifdef High_Altitude_Clouds
						// high altitude clouds shadows
						vec3 shadowSamplePos_high =  progress_view_high + dV_Sun * (sample + sample*2.0);
						float highAlt_cloudS = HighAltitudeClouds(shadowSamplePos_high);
						muEshD_high += highAlt_cloudS*cirrusDensity*cirrusShadowStep;
					#endif
				}
			}

			float muEshN = 0.0;
			if (moonContribution.g > 1e-5){
				for (int j=0; j<self_shadow_samples; j++){
					float sample = j+dither2;
					
					#ifdef Cumulus_Clouds
						// low altitude clouds shadows
						vec3 shadowSamplePos = progress_view - dV_Sun * (sample + sample*2.0);
						if (shadowSamplePos.y < maxHeight){
							float cloudS = getCloudDensity(vec3(shadowSamplePos), cloudShadowLoD);
							muEshN += cloudS*cloudDensity*shadowStep;
						}
					#endif

					#ifdef High_Altitude_Clouds
						// high altitude clouds shadows
						vec3 shadowSamplePos_high =  progress_view_high - dV_Sun * (sample + sample*2.0);
						float highAlt_cloudS = HighAltitudeClouds(shadowSamplePos_high);
						muEshN_high += highAlt_cloudS*cirrusDensity*cirrusShadowStep;
					#endif
				}
			}
			
			#ifdef Cumulus_Clouds
				// clamp(abs(dV_Sun.y)/150.0,0.5,1.0)
				float muEshA = cloud*cloudDensity ;
				vec3 S = Cloud_lighting(progress_view, muE, muEshA, muEshD, muEshN, skyCol0 * max(abs(dV_Sun.y)/150.0,0.5), sunContribution, sunContributionMulti, moonContribution, moonContributionMulti, 0);

				// float bottom = clamp( (progress_view.y-3250.*0.6) / 1000.  ,0.0,1.0) ;
				// float location = bottom * (muEshA*5000) * pow(phaseLightning,1.5);
				// vec3 lightningLighting = lightningFlash * vec3(0.5,0.75,1) * location * max(dV_Sun.y,1.);
				// S += lightningLighting ;

				vec3 Sint = (S - S * exp(-mult*muE)) / muE;
				color += max(muS*Sint*total_extinction,0.0);
				total_extinction *= max(exp(-muE*mult),0);	

				if (total_extinction < 1e-5) break;
			#endif
		}
		progress_view += dV_view;
	}

	// do this aftewards because stinky
	#ifdef High_Altitude_Clouds
		float cirrus = HighAltitudeClouds(progress_view_high);
		if (cirrus >= 0.0){
			float muS = cirrus*cirrusDensity;
			float muE =	cirrus*cirrusDensity;

			float muEshA_high = cirrus*cirrusDensity;

			vec3 S = Cloud_lighting(progress_view, muE, muEshA_high, muEshD_high, muEshN_high, skyCol0  * max(abs(dV_Sun.y)/150.0,0.5) , sunContribution, sunContributionMulti, moonContribution, moonContributionMulti, 1);
			
			vec3 Sint = (S - S * exp(-mult*muE)) / muE;
			color += max(muS*Sint*total_extinction,0.0);
			total_extinction *= max(exp(-muE*mult),0);
		}
	#endif
	
	vec3 normView = normalize(dV_view2)*flipClouds;
	// Assume fog color = sky gradient at long distance
	vec3 fogColor = skyFromTex(normView, colortex4)/150.;
	float dist = (cloud_height - (cameraPosition.y))/normalize(dV_view2).y;
	float fog = exp(-dist/15000.0*(1.0+rainCloudwetness*8.));
	return mix(vec4(fogColor,0.0), vec4(color,total_extinction), fog);
	// return vec4(color,total_extinction);
}
