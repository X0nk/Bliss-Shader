// uniform float LowCoverage;

// uniform float isDeserts;
const float sunAngularSize = 0.533333;
const float moonAngularSize = 0.516667;

//Sky coefficients and heights

#define airNumberDensity 2.5035422e25
#define ozoneConcentrationPeak 8e-6
const float ozoneNumberDensity = airNumberDensity * ozoneConcentrationPeak;
#define ozoneCrossSection vec3(4.51103766177301e-21, 3.2854797958699e-21, 1.96774621921165e-22)

#define sky_planetRadius 6731e3

#define sky_atmosphereHeight 110e3
#define sky_scaleHeights vec2(8.0e3, 1.2e3)


#define sky_coefficientRayleigh vec3(sky_coefficientRayleighR*1e-6, sky_coefficientRayleighG*1e-5, sky_coefficientRayleighB*1e-5)


#define sky_coefficientMie vec3(sky_coefficientMieR*1e-6, sky_coefficientMieG*1e-6, sky_coefficientMieB*1e-6) // Should be >= 2e-6
const vec3 sky_coefficientOzone = (ozoneCrossSection * (ozoneNumberDensity * 0.2e-6)); // ozone cross section * (ozone number density * (cm ^ 3))

const vec2 sky_inverseScaleHeights = 1.0 / sky_scaleHeights;
const vec2 sky_scaledPlanetRadius = sky_planetRadius * sky_inverseScaleHeights;
const float sky_atmosphereRadius = sky_planetRadius + sky_atmosphereHeight;
const float sky_atmosphereRadiusSquared = sky_atmosphereRadius * sky_atmosphereRadius;

#define sky_coefficientsScattering mat2x3(sky_coefficientRayleigh, sky_coefficientMie)
const mat3   sky_coefficientsAttenuation = mat3(sky_coefficientRayleigh , sky_coefficientMie, sky_coefficientOzone ); // commonly called the extinction coefficient





float sky_rayleighPhase(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) * rPI;
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}

float sky_miePhase(float cosTheta, const float g) {
	float gg = g * g;
	return (gg * -0.25 + 0.25) * rPI * pow(-(2.0 * g) * cosTheta + (gg + 1.0), -1.5);
}

vec2 sky_phase(float cosTheta, const float g) {
	return vec2(sky_rayleighPhase(cosTheta), sky_miePhase(cosTheta, g));
}

vec3 sky_density(float centerDistance) {
	vec2 rayleighMie = exp(centerDistance * -sky_inverseScaleHeights + sky_scaledPlanetRadius);

	// Ozone distribution curve by Sergeant Sarcasm - https://www.desmos.com/calculator/j0wozszdwa
	float ozone = exp(-max(0.0, (35000.0 - centerDistance) - sky_planetRadius) * (1.0 / 5000.0))
	            * exp(-max(0.0, (centerDistance - 35000.0) - sky_planetRadius) * (1.0 / 15000.0));
	return vec3(rayleighMie, ozone);
}

vec3 sky_airmass(vec3 position, vec3 direction, float rayLength, const float steps) {
	float stepSize  = rayLength * (1.0 / steps);
	vec3  increment = direction * stepSize;
	position += increment * 0.5;

	vec3 airmass = vec3(0.0);
	for (int i = 0; i < steps; ++i, position += increment) {
		airmass += sky_density(length(position));
	}

	return airmass * stepSize;
}
vec3 sky_airmass(vec3 position, vec3 direction, const float steps) {
	float rayLength = dot(position, direction);
	      rayLength = rayLength * rayLength + sky_atmosphereRadiusSquared - dot(position, position);
		  if (rayLength < 0.0) return vec3(0.0);
	      rayLength = sqrt(rayLength) - dot(position, direction);

	return sky_airmass(position, direction, rayLength, steps);
}

vec3 sky_opticalDepth(vec3 position, vec3 direction, float rayLength, const float steps) {
	return sky_coefficientsAttenuation * sky_airmass(position, direction, rayLength, steps);
}
vec3 sky_opticalDepth(vec3 position, vec3 direction, const float steps) {
	return sky_coefficientsAttenuation * sky_airmass(position, direction, steps);
}

vec3 sky_transmittance(vec3 position, vec3 direction, const float steps) {
	return exp(-sky_opticalDepth(position, direction, steps) * rLOG2);
}



vec3 calculateAtmosphere(vec3 background, vec3 viewVector, vec3 upVector, vec3 sunVector, vec3 moonVector, out vec2 pid, out vec3 transmittance, const int iSteps, float noise) {
	const int jSteps = 4;

	#ifdef SKY_GROUND
		float planetGround = exp(-100 * pow(max(-viewVector.y*5 + 0.1,0.0),2)); // darken the ground in the sky.
	#else
		float planetGround = pow(clamp(viewVector.y+1.0,0.0,1.0),2); // darken the ground in the sky.
	#endif
	
	float GroundDarkening = max(planetGround * 0.7+0.3,clamp(sunVector.y*2.0,0.0,1.0));

	vec3 viewPos = (sky_planetRadius + eyeAltitude) * upVector;

	vec2 aid = rsi(viewPos, viewVector, sky_atmosphereRadius);
	if (aid.y < 0.0) {transmittance = vec3(1.0); return vec3(0.0);}

	pid = rsi(viewPos, viewVector, sky_planetRadius * 0.998);
	bool planetIntersected = pid.y >= 0.0;

	vec2 sd = vec2((planetIntersected && pid.x < 0.0) ? pid.y : max(aid.x, 0.0), (planetIntersected && pid.x > 0.0) ? pid.x : aid.y);

	float stepSize  = (sd.y - sd.x) * (1.0 / iSteps);
	vec3  increment = viewVector * stepSize;
	vec3  position  = viewVector * sd.x + viewPos;
	position += increment * (0.34*noise);

	vec2 phaseSun = sky_phase(dot(viewVector, sunVector), 0.8);
	vec2 phaseMoon = sky_phase(dot(viewVector, moonVector), 0.8);

	vec3 scatteringSun     = vec3(0.0);
	vec3 scatteringMoon    = vec3(0.0);
	vec3 scatteringAmbient = vec3(0.0);

	transmittance = vec3(1.0);

	float high_sun = clamp(pow(sunVector.y+0.6,5),0.0,1.0) * 3.0; // make sunrise less blue, and allow sunset to be bluer
	float low_sun = clamp(((1.0-abs(sunVector.y))*3.) - high_sun,1.0,1.8) ;


	for (int i = 0; i < iSteps; ++i, position += increment) {
		vec3 density = sky_density(length(position));
		if (density.y > 1e35) break;
		vec3 stepAirmass      = density * stepSize ;
		vec3 stepOpticalDepth = sky_coefficientsAttenuation * stepAirmass ;

		vec3 stepTransmittance       = exp2(-stepOpticalDepth * rLOG2);
		vec3 stepTransmittedFraction = clamp01((stepTransmittance - 1.0) / -stepOpticalDepth) ;
		vec3 stepScatteringVisible   = transmittance * stepTransmittedFraction * GroundDarkening ;
		
		#ifdef ORIGINAL_CHOCAPIC_SKY
			scatteringSun  += sky_coefficientsScattering  * (stepAirmass.xy * phaseSun) * stepScatteringVisible * sky_transmittance(position, sunVector,  jSteps) * planetGround;
		#else
			scatteringSun  += sky_coefficientsScattering  * (stepAirmass.xy * phaseSun) * stepScatteringVisible * sky_transmittance(position, sunVector*0.5+0.1,  jSteps) * planetGround;
		#endif

		scatteringMoon += sky_coefficientsScattering * (stepAirmass.xy * phaseMoon) * stepScatteringVisible * sky_transmittance(position, moonVector, jSteps) * planetGround;
		
		// Nice way to fake multiple scattering.
		#ifdef ORIGINAL_CHOCAPIC_SKY
			scatteringAmbient += sky_coefficientsScattering * stepAirmass.xy * stepScatteringVisible;
		#else
			scatteringAmbient += sky_coefficientsScattering * stepAirmass.xy * stepScatteringVisible * low_sun;
		#endif
		
		transmittance *= stepTransmittance;
	}
	
	vec3 scattering = scatteringSun * sunColorBase + scatteringAmbient * background + scatteringMoon*moonColorBase	;

	return scattering;
}
