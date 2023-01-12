#define VOLUMETRIC_CLOUDS// if you don't like the noise on the default cloud settings, turn up the cloud samples. if that hurts performance too much, turn down the clouds quality.

#define cloud_LevelOfDetail 1		// Number of fbm noise iterations for on-screen clouds (-1 is no fbm)	[-1 0 1 2 3 4 5 6 7 8]
#define cloud_ShadowLevelOfDetail 0	// Number of fbm noise iterations for the shadowing of on-screen clouds (-1 is no fbm)	[-1 0 1 2 3 4 5 6 7 8]
#define cloud_LevelOfDetailLQ 1	// Number of fbm noise iterations for reflected clouds (-1 is no fbm)	[-1 0 1 2 3 4 5 6 7 8]
#define cloud_ShadowLevelOfDetailLQ 0	// Number of fbm noise iterations for the shadowing of reflected clouds (-1 is no fbm)	[-1 0 1 2 3 4 5 6 7 8]
#define minRayMarchSteps 20		// Number of ray march steps towards zenith for on-screen clouds	[20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 105 110 115 120 125 130 135 140 145 150 155 160 165 170 175 180 185 190 195 200]
#define maxRayMarchSteps 30		// Number of ray march steps towards horizon for on-screen clouds	[5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 105 110 115 120 125 130 135 140 145 150 155 160 165 170 175 180 185 190 195 200]
#define minRayMarchStepsLQ 10	// Number of ray march steps towards zenith for reflected clouds	[5  10  15  20  25  30  35  40  45  50  55  60  65  70  75  80  85  90 95 100]
#define maxRayMarchStepsLQ 30		// Number of ray march steps towards horizon for reflected clouds	[  5  10  15  20  25  30  35  40  45  50  55  60  65  70  75  80  85  90 95 100]
#define cloudMieG 0.5 // Values close to 1 will create a strong peak of luminance around the sun and weak elsewhere, values close to 0 means uniform fog. [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 ]
#define cloudMieG2 0.9 // Multiple scattering approximation. Values close to 1 will create a strong peak of luminance around the sun and weak elsewhere, values close to 0 means uniform fog. [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 ]
#define cloudMie2Multiplier 0.7 // Multiplier for multiple scattering approximation  [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 ]

#define Cloud_top_cutoff 1.0  // the cutoff point on the top part of the cloud. [ 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 4 5 6 7 8 9] 
#define Cloud_base_cutoff 5.0 // the cutoff point on the base of the cloud. [0.1 1 2 4 6 8 10 12 14 16 18 20]


#ifdef HQ_CLOUDS
int maxIT_clouds = minRayMarchSteps;
int maxIT = maxRayMarchSteps;
#else
int maxIT_clouds = minRayMarchStepsLQ;
int maxIT = maxRayMarchStepsLQ;
#endif

///////  shape
#define cloudDensity 0.0514	// Cloud Density, 0.04-0.06 is around irl values	[0.0010 0.0011 0.0013 0.0015 0.0017 0.0020 0.0023 0.0026 0.0030 0.0034 0.0039 0.0045 0.0051 0.0058 0.0067 0.0077 0.0088 0.0101 0.0115 0.0132 0.0151 0.0173 0.0199 0.0228 0.0261 0.0299 0.0342 0.0392 0.0449 0.0514 0.0589 0.0675 0.0773 0.0885 0.1014 0.1162 0.1331 0.1524 0.1746 0.2000 0.3 0.35 0.4 0.45 0.5 0.6 0.7 0.8 0.9 1.0]
#define fbmAmount 0.50 		// Amount of noise added to the cloud shape	[0.00 0.02 0.04 0.06 0.08 0.10 0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.32 0.34 0.36 0.38 0.40 0.42 0.44 0.46 0.48 0.50 0.52 0.54 0.56 0.58 0.60 0.62 0.64 0.66 0.68 0.70 0.72 0.74 0.76 0.78 0.80 0.82 0.84 0.86 0.88 0.90 0.92 0.94 0.96 0.98 1.00 1.02 1.04 1.06 1.08 1.10 1.12 1.14 1.16 1.18 1.20 1.22 1.24 1.26 1.28 1.30 1.32 1.34 1.36 1.38 1.40 1.42 1.44 1.46 1.48 1.50 1.52 1.54 1.56 1.58 1.60 1.62 1.64 1.66 1.68 1.70 1.72 1.74 1.76 1.78 1.80 1.82 1.84 1.86 1.88 1.90 1.92 1.94 1.96 1.98 2.00 2.02 2.04 2.06 2.08 2.10 2.12 2.14 2.16 2.18 2.20 2.22 2.24 2.26 2.28 2.30 2.32 2.34 2.36 2.38 2.40 2.42 2.44 2.46 2.48 2.50 2.52 2.54 2.56 2.58 2.60 2.62 2.64 2.66 2.68 2.70 2.72 2.74 2.76 2.78 2.80 2.82 2.84 2.86 2.88 2.90 2.92 2.94 2.96 2.98 3.00]
#define fbmPower1 3.00	// Higher values increases high frequency details of the cloud shape	[1.0 1.50 1.52 1.54 1.56 1.58 1.60 1.62 1.64 1.66 1.68 1.70 1.72 1.74 1.76 1.78 1.80 1.82 1.84 1.86 1.88 1.90 1.92 1.94 1.96 1.98 2.00 2.02 2.04 2.06 2.08 2.10 2.12 2.14 2.16 2.18 2.20 2.22 2.24 2.26 2.28 2.30 2.32 2.34 2.36 2.38 2.40 2.42 2.44 2.46 2.48 2.50 2.52 2.54 2.56 2.58 2.60 2.62 2.64 2.66 2.68 2.70 2.72 2.74 2.76 2.78 2.80 2.82 2.84 2.86 2.88 2.90 2.92 2.94 2.96 2.98 3.00 3.02 3.04 3.06 3.08 3.10 3.12 3.14 3.16 3.18 3.20 3.22 3.24 3.26 3.28 3.30 3.32 3.34 3.36 3.38 3.40 3.42 3.44 3.46 3.48 3.50 3.52 3.54 3.56 3.58 3.60 3.62 3.64 3.66 3.68 3.70 3.72 3.74 3.76 3.78 3.80 3.82 3.84 3.86 3.88 3.90 3.92 3.94 3.96 3.98 4.00 5. 6. 7. 8. 9. 10.]
#define fbmPower2 1.50	// Lower values increases high frequency details of the cloud shape	[1.00 1.50 1.52 1.54 1.56 1.58 1.60 1.62 1.64 1.66 1.68 1.70 1.72 1.74 1.76 1.78 1.80 1.82 1.84 1.86 1.88 1.90 1.92 1.94 1.96 1.98 2.00 2.02 2.04 2.06 2.08 2.10 2.12 2.14 2.16 2.18 2.20 2.22 2.24 2.26 2.28 2.30 2.32 2.34 2.36 2.38 2.40 2.42 2.44 2.46 2.48 2.50 2.52 2.54 2.56 2.58 2.60 2.62 2.64 2.66 2.68 2.70 2.72 2.74 2.76 2.78 2.80 2.82 2.84 2.86 2.88 2.90 2.92 2.94 2.96 2.98 3.00 3.02 3.04 3.06 3.08 3.10 3.12 3.14 3.16 3.18 3.20 3.22 3.24 3.26 3.28 3.30 3.32 3.34 3.36 3.38 3.40 3.42 3.44 3.46 3.48 3.50 3.52 3.54 3.56 3.58 3.60 3.62 3.64 3.66 3.68 3.70 3.72 3.74 3.76 3.78 3.80 3.82 3.84 3.86 3.88 3.90 3.92 3.94 3.96 3.98 4.00 5. 6. 7. 8. 9. 10.]

#define Cloud_Size 35 // [1 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]
#define Cloud_Height 319 // [-300 -290 -280 -270 -260 -250 -240 -230 -220 -210 -200 -190 -180 -170 -160 -150 -140 -130 -120 -110 -100 -90 -80 -70 -60 -50 -40 -30 -20 -10 0 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200 210 220 230 240 250 260 270 280 290 300 310 319 320]

///////  lighting
#define Shadow_brightness 0.5 // how dark / bright you want the shadowed part of the clouds to be. low values can look weird. [ 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0 4.0 5.0 6.0]
#define self_shadow_samples 3.0 // amount of interations for cloud self shadows. longer/shorter cloud self shadows. [ 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 15 20 30 40 50]


#define Dynamic_sky_day -1 // -1 MEANS THIS IS OFF. select which day of the 8 to the clouds should take shape in [0 1 2 3 4 5 6 7 ]
#define Dynamic_Sky // day 1: partly cloudy. day 2: really cloudy, misty. day 3: mostly clear. day 4: cloudy. day 5: cloudy again. day 6: scattered clouds. day 7: partly cloudy. day 8: clear

#define High_Altitude_Clouds // a layer of clouds way up yonder
#define Cumulus_Clouds


///////  other
#define flip_the_clouds 1 // what was once above is now below [1 -1] 
#define cloud_speed 1 // how 	[ 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 2.0 3.0 5.0 10.0 25.0 50.0 100.0 200.0]

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

// uniform vec4 Moon_Weather_properties;
// float highCov =		 Dynamic_sky_day == 0 ? 0.4 : Dynamic_sky_day == 1 ? 0.6 :	Dynamic_sky_day == 2 ? 0.4 :	Dynamic_sky_day == 3 ? -1000 :	Dynamic_sky_day == 4 ? 1 :	Dynamic_sky_day == 5 ? -1000 :	Dynamic_sky_day == 6 ? 0.6 : 0.4;
// float lowCov =		 Dynamic_sky_day == 0 ? 0.4 : Dynamic_sky_day == 1 ? 0.9 : 	Dynamic_sky_day == 2 ? 0.0 :	Dynamic_sky_day == 3 ? 0.5 :	Dynamic_sky_day == 4 ? 0 :	Dynamic_sky_day == 5 ? -1000 :	Dynamic_sky_day == 6 ? -1000 : 0.8;
// float FogDen =		 Dynamic_sky_day == 0 ? 0 :	Dynamic_sky_day == 1 ? 0 :	Dynamic_sky_day == 2 ? 0 :	Dynamic_sky_day == 3 ? 0 :	Dynamic_sky_day == 4 ? 0 :	Dynamic_sky_day == 5 ? 0 :	Dynamic_sky_day == 6 ? 0 : 0;
// float CloudyFogden = Dynamic_sky_day == 0 ? 0 :	Dynamic_sky_day == 1 ? 0 :	Dynamic_sky_day == 2 ? 0 :	Dynamic_sky_day == 3 ? 0 :	Dynamic_sky_day == 4 ? 0 :	Dynamic_sky_day == 5 ? 0 :	Dynamic_sky_day == 6 ? 0 : 0;
// vec4 custom_day =  vec4(highCov, lowCov, FogDen, CloudyFogden);


// #ifdef Dynamic_Sky

// 	#if Dynamic_sky_day < 0
// 		vec4 Weather_properties = Moon_Weather_properties;
// 	#endif

// 	#if Dynamic_sky_day >= 0
// 		vec4 Weather_properties = custom_day;
// 	#endif

// #else
// 	vec4 Weather_properties = vec4(0);
// #endif

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
	
	float CloudLarge = texture2D(noisetex, samplePos.xz/150000  + cloud_movement1).b;
	float CloudSmall = texture2D(noisetex, samplePos.xz/15000 	- cloud_movement1	+ vec2(1-CloudLarge,-CloudLarge)/5).r;

	float coverage = CloudSmall-CloudLarge;

	float mult = max( abs(pos.y-1750) / 5000, 0);

	// #ifdef Dynamic_Sky
	// 	cloudshape = ( coverage + (-0.35+mix(Weather_properties.r, Rain_coverage, rainCloudwetness)*1.5) ) - mult;
	// 	// cloudshape =  coverage - mult;
	// #else
	// 	cloudshape = ( coverage + (-0.35+mix(cloudCoverage, Rain_coverage, rainCloudwetness)*1.5) ) - mult   ;
	// #endif

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

	return cloud;
}

float getCloudDensity(in vec3 pos, in int LoD){

	
	vec3 samplePos = pos*vec3(1.0,1./48.,1.0)/4  ;
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
	float powder = max(1.0 - exp2(-CloudShape*100.0),0.0);
	float ambientShading = (powder*0.8+0.2) * exp2(-SkyShadowing * 50.);
	vec3 ambientLighting = SkyColors * 4.0 * ambientShading;

	if(cloudType == 1) ambientLighting = SkyColors * (1.0-powder/2);

	vec3 sunLighting  = ( exp2(-SunShadowing * 2.0 )*sunContribution + exp(-SunShadowing * 0.2 )*sunContributionMulti  ) * powder;
	vec3 moonLighting  = ( exp2(-MoonShadowing * 2.0 )*moonContribution + exp(-MoonShadowing * 0.2 )*moonContributionMulti  ) * powder;

	// if(cloudType == 0) sunLighting *= clamp((1.05-CirrusCoverage),0,1); // less sunlight hits low clouds if high clouds have alot of coverage

	return ambientLighting + sunLighting + moonLighting;
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
	startOffset = dV_view*dither;

	vec3 camPos = ((cameraPosition*flipClouds)-height)*Cloud_Size;
	
	vec3 progress_view = startOffset + camPos + dV_view*(cloud_height-camPos.y)/dV_view.y;

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
	float mieDayMulti = phaseg(SdotV, 0.35)*3.14;
	float mieDay = mix(phaseg(SdotV,0.75), mieDayMulti,0.8)*3.14;

	float mieNightMulti = phaseg(-SdotV, 0.35)*3.14;
	float mieNight = mix(phaseg(-SdotV,0.9), mieNightMulti,0.5)*3.14;

	vec3 sunContribution = mieDay*sunColor*6.14;
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

	
	float cloud = 0.0;
	for(int i=0;i<maxIT_clouds;i++) {

		#ifdef Cumulus_Clouds
			cloud = getCloudDensity(progress_view, cloudLoD);
		#endif

		float basefade = clamp( (progress_view.y - 1750 ) /  1750  ,0.0,1.0) ;

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
				float muEshA = (cloud*cloudDensity) ;
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
