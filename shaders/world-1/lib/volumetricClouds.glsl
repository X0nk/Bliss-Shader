#define VOLUMETRIC_CLOUDS

float cloud_height = 1500.;
float maxHeight = 3200.;
#ifdef HQ_CLOUDS
int maxIT_clouds = 20;
int maxIT = 60;
#else
int maxIT_clouds = 9;
int maxIT = 27;
#endif

float cdensity = 0.015;


//3D noise from 2d texture
float densityAtPos(in vec3 pos)
{

	pos /= 18.;
	pos.xz *= 0.5;


	vec3 p = floor(pos);
	vec3 f = fract(pos);

	f = (f*f) * (3.-2.*f);

	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);

	vec2 coord =  uv / 512.0;
	//The y channel has an offset to avoid using two textures fetches
	vec2 xy = texture2D(noisetex, coord).yx;

	return mix(xy.r,xy.g, f.y);
}
vec4 smoothfilter(in sampler2D tex, in vec2 uv)
{
	uv = uv*512.0 + 0.5;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );
	uv = iuv + (fuv*fuv)*(3.0-2.0*fuv);
	uv = uv/512.0 - 0.5/512.0;
	return texture2D( tex, uv);
}
//Cloud without 3D noise, is used to exit early lighting calculations if there is no cloud
float cloudCov(in vec3 pos,vec3 samplePos){
	float mult = max(pos.y-2000.0,0.0)/2000.0;
	float mult2 = max(-pos.y+2000.0,0.0)/500.0;
	float coverage = clamp(texture2D(noisetex,samplePos.xz/12500.).r-0.2+0.4*rainStrength,0.0,1.0)/(1.0-0.2+0.4*rainStrength);
	float cloud = coverage*coverage*4.0 - mult*mult*mult*3.0 - mult2*mult2;
	return max(cloud, 0.0);
}
//Erode cloud with 3d Perlin-worley noise, actual cloud value
#ifdef HQ_CLOUDS
	float cloudVol(in vec3 pos,in vec3 samplePos,in float cov){
		//Less erosion on bottom of the cloud
		float mult2 = (pos.y-1500)/2500.0+rainStrength*0.4;
		float noise = 1.0-densityAtPos(samplePos*15.);
		noise += 0.5-densityAtPos(samplePos*30.)*0.5;
		noise /= 1.5;
		noise = noise*noise;
		float cloud = clamp(cov-noise*noise*0.33*(0.2+mult2),0.0,1.0);
		//float cloud = clamp(cov-0.1*(0.2+mult2),0.0,1.0);
		return cloud;
}
	//Low quality cloud, noise is replaced by the average noise value, used for shadowing
	float cloudVolLQ(in vec3 pos){
		float mult = max(pos.y-2000.0,0.0)/2000.0;
		float mult2 = max(-pos.y+2000.0,0.0)/500.0;
		float mult3 = (pos.y-1500)/2500.0+rainStrength*0.4;
		vec3 samplePos = pos*vec3(1.0,1./32.,1.0)/4+frameTimeCounter*vec3(0.5,0.,0.5)*25.;
		float coverage = clamp(texture2D(noisetex,samplePos.xz/12500.).r-0.2+0.4*rainStrength,0.0,1.0)/(1.0-0.2+0.4*rainStrength);
		float cloud = coverage*coverage*4.0 - mult*mult*mult*3.0 - mult2*mult2 - 0.11 * (0.2 + mult3);
		return max(cloud, 0.0);
	}
#else
	float cloudVol(in vec3 pos,in vec3 samplePos,in float cov){
		float mult2 = (pos.y-1500)/2500.0+rainStrength*0.4;
		float cloud = clamp(cov-0.11*(0.2+mult2),0.0,1.0);
		return cloud;

	}
	//Low quality cloud, noise is replaced by the average noise value, used for shadowing
	float cloudVolLQ(in vec3 pos){
		float mult = max(pos.y-2000.0,0.0)/2000.0;
		float mult2 = max(-pos.y+2000.0,0.0)/500.0;
		float mult3 = (pos.y-1500)/2500.0+rainStrength*0.4;
		vec3 samplePos = pos*vec3(1.0,1./32.,1.0)/4+frameTimeCounter*vec3(0.5,0.,0.5)*25.;
		float coverage = clamp(texture2D(noisetex,samplePos.xz/12500.).r-0.2+0.4*rainStrength,0.0,1.0)/(1.0-0.2+0.4*rainStrength);
		float cloud = coverage*coverage*4.0 - mult*mult*mult*3.0 - mult2*mult2 - 0.11 * (0.2 + mult3);
		return max(cloud, 0.0);
	}
#endif


//Mie phase function
float phaseg(float x, float g){
    float gg = g * g;
    return (gg * -0.25 /3.14 + 0.25 /3.14) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5);
}

float calcShadow(vec3 pos, vec3 ray){
	float shadowStep = length(ray);
	float d = 0.0;
	for (int j=1;j<6;j++){
		float cloudS=cloudVolLQ(vec3(pos+ray*j));
		d += cloudS*cdensity;

		}
	return max(exp(-shadowStep*d),exp(-0.25*shadowStep*d)*0.7);
}
float cirrusClouds(vec3 pos){
	vec2 pos2D = pos.xz/50000.0 + frameTimeCounter/200.;
	float cirrusMap = clamp(texture2D(noisetex,pos2D.yx/6. ).b-0.7+0.7*rainStrength,0.0,1.0);
	float cloud = texture2D(noisetex, pos2D).r;
	float weights = 1.0;
	vec2 posMult = vec2(2.0,1.5);
	for (int i = 1; i < 4; i++){
		pos2D *= posMult;
		float weight =exp2(-i*1.0);
		cloud += texture2D(noisetex, pos2D).r*weight;

		weights += weight;
	}
	cloud = clamp(cloud*cirrusMap*0.25,0.0,1.0);
	return cloud/weights * float(abs(pos.y - 5500.0) < 200.0);
}

vec4 renderClouds(vec3 fragpositi, vec3 color,float dither,vec3 sunColor,vec3 moonColor,vec3 avgAmbient) {
		#ifndef VOLUMETRIC_CLOUDS
			return vec4(0.0,0.0,0.0,1.0);
		#endif
		//setup ray in projected shadow map space
		bool land = false;

		float SdotU = dot(normalize(fragpositi.xyz),sunVec);
		float z2 = length(fragpositi);
		float z = -fragpositi.z;


		//project pixel position into projected shadowmap space
		vec4 fragposition = gbufferModelViewInverse*vec4(fragpositi,1.0);

		vec3 worldV = normalize(fragposition.rgb);
		float VdotU = worldV.y;
		maxIT_clouds = int(clamp(maxIT_clouds/sqrt(VdotU),0.0,maxIT*1.0));
		//worldV.y -= -length(worldV.xz)/sqrt(-length(worldV.xz/earthRad)*length(worldV.xz/earthRad)+earthRad);

		//project view origin into projected shadowmap space
		vec4 start = (gbufferModelViewInverse*vec4(0.0,0.0,0.,1.));
		vec3 dV_view = worldV;


		vec3 progress_view = dV_view*dither+cameraPosition;

		float vL = 0.0;
		float total_extinction = 1.0;


		float distW = length(worldV);
		worldV = normalize(worldV)*300000. + cameraPosition; //makes max cloud distance not dependant of render distance
		dV_view = normalize(dV_view);

		//setup ray to start at the start of the cloud plane and end at the end of the cloud plane
		dV_view *= max(maxHeight-cloud_height, 0.0)/dV_view.y/maxIT_clouds;
		vec3 startOffset = dV_view*dither;

		progress_view = startOffset + cameraPosition + dV_view*(cloud_height-cameraPosition.y)/(dV_view.y);


		if (worldV.y < cloud_height) return vec4(0.,0.,0.,1.);	//don't trace if no intersection is possible



		float shadowStep = 240.;
		vec3 dV_Sun = normalize(mat3(gbufferModelViewInverse)*sunVec)*shadowStep;

		float mult = length(dV_view);


		color = vec3(0.0);

		total_extinction = 1.0;
		float SdotV = dot(sunVec,normalize(fragpositi));
		//fake multiple scattering approx 1 (from horizon zero down clouds)
		float mieDay = max(phaseg(SdotV,0.7),phaseg(SdotV,0.2));
		float mieNight = max(phaseg(-SdotV,0.7),phaseg(-SdotV,0.2));

		vec3 sunContribution = mieDay*sunColor*3.14;
		vec3 moonContribution = mieNight*moonColor*3.14;
		vec3 skyCol0 = avgAmbient*(1.0-rainStrength*0.8);

		float powderMulMoon = 1.0;
		float powderMulSun = 1.0;

		for (int i=0;i<maxIT_clouds;i++) {
		vec3 curvedPos = progress_view;
		vec2 xz = progress_view.xz-cameraPosition.xz;
		curvedPos.y -= sqrt(pow(6731e3,2.0)-dot(xz,xz))-6731e3;
		vec3 samplePos = curvedPos*vec3(1.0,1./32.,1.0)/4+frameTimeCounter*vec3(0.5,0.,0.5)*25.;
			float coverageSP = cloudCov(curvedPos,samplePos);
			if (coverageSP>0.00){
				float cloud = cloudVol(curvedPos,samplePos,coverageSP);
				if (cloud > 0.0005){
					float muS = cloud*cdensity;
					float muE =	cloud*cdensity;
					float muEshD = 0.0;
					if (sunContribution.g > 1e-5){
						for (int j=1;j<8;j++){
							vec3 shadowSamplePos = curvedPos+dV_Sun*j;
							if (shadowSamplePos.y < maxHeight)
							{
								float cloudS=cloudVolLQ(vec3(shadowSamplePos));
								muEshD += cloudS*cdensity;
							}
						}
					}
					float muEshN = 0.0;
					if (moonContribution.g > 1e-5){
						for (int j=1;j<8;j++){
							vec3 shadowSamplePos = curvedPos-dV_Sun*j;
							if (shadowSamplePos.y < maxHeight)
							{
								float cloudS=cloudVolLQ(vec3(shadowSamplePos));
								muEshN += cloudS*cdensity;
							}
						}
					}
					//fake multiple scattering approx 2  (from horizon zero down clouds)
					float sunShadow = max(exp2(-shadowStep*muEshD),exp2(-0.25*shadowStep*muEshD))*(1.0-exp(-muE*100.0*2.0));
					float moonShadow = max(exp2(-shadowStep*muEshN),exp2(-0.25*shadowStep*muEshN))*(1.0-exp(-muE*100.0*2.0));
					float h = 0.5-0.5*clamp(curvedPos.y/4000.-1500./4000.,0.0,1.0);
					float ambientPowder = (1.0-h*exp2(-muE*100.0*2.0));
					vec3 S = vec3(sunContribution*sunShadow+moonShadow*moonContribution+skyCol0*ambientPowder);


					vec3 Sint=(S - S * exp2(-mult*muE)) / (muE);
					color += muS*Sint*total_extinction;
					total_extinction *= exp2(-muE*mult);


					if (total_extinction < 1/250.) break;
				}
			}

			progress_view += dV_view;
		}

		//high altitude clouds
		progress_view = progress_view + (5500.0-progress_view.y) * dV_view / dV_view.y;
		mult = 400.0 * inversesqrt(abs(normalize(dV_view).y));
		float cirrus = cirrusClouds(vec3(progress_view.x,5500.0,progress_view.z))*cdensity*2.0;
		if (cirrus > 1e-5){
			float muEshD = 0.0;
			if (sunContribution.g > 1e-5){
				for (int j=1;j<8;j++){
					float cloudS=cirrusClouds(vec3(progress_view+dV_Sun*j));
					muEshD += cloudS*cdensity*2.;
				}
			}
			float muEshN = 0.0;
			if (moonContribution.g > 1e-5){
				for (int j=1;j<8;j++){
					float cloudS=cirrusClouds(vec3(progress_view-dV_Sun*j));
					muEshN += cloudS*cdensity*2.0;
				}
			}
			float sunShadow = max(exp(-shadowStep*muEshD),exp(-0.25*shadowStep*muEshD)*0.4)*(1.0-exp(-cirrus*mult*2.0));
			float moonShadow = max(exp(-shadowStep*muEshN),exp(-0.25*shadowStep*muEshN)*0.4)*(1.0-exp(-cirrus*mult*2.0));
			float ambientPowder = (1.0-exp(-cirrus*mult*2.0));
			vec3 S = vec3(sunContribution*sunShadow+moonShadow*moonContribution+skyCol0*ambientPowder*0.5);
			vec3 Sint=(S - S * exp(-mult*cirrus)) / (cirrus);
			color += Sint * cirrus * total_extinction;
			total_extinction *= exp(-mult*cirrus);
		}
		float cosY = normalize(dV_view).y;


		return mix(vec4(color,clamp(total_extinction*(1.0+1/250.)-1/250.,0.0,1.0)),vec4(0.0,0.0,0.0,1.0),1-smoothstep(0.02,0.15,cosY));

}
