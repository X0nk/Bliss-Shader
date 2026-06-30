const float PI48 = 150.796447372*WAVY_SPEED;
float pi2wt = PI48*frameTimeCounter;

uniform vec2 windDirection_foliage;
uniform vec2 windDirection;
uniform float rainStrength;
uniform sampler2D noisetex;

vec2 calcWave(in vec3 pos) {


    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec2 ret = (sin(pi2wt*vec2(0.0063,0.0015)*4. - pos.xz + pos.y*0.05)+0.1)*magnitude ;

    return ret;
}

vec3 calcMovePlants(in vec3 pos) {

    vec2 move1 = calcWave(pos );
	float move1y = -length(move1);
    vec3 result = vec3(move1.x,move1y,move1.y)*5.*WAVY_STRENGTH * (1.0+rainStrength);
    
    #if WIND_SYSTEM_MODE > 0
    	// result.xz += windDirection_foliage/200.0*-move1y * (1.0+rainStrength);
        vec2 windMaps = vec2(texture(noisetex, (pos.xz + windDirection*5.0)/128.0).r,0.0);
        if(rainStrength > 0.001) windMaps.y = texture(noisetex, (pos.xz + windDirection*5.0)/128.0).b;
        float windForce = mix(0.0,1.0,pow(1.0-pow(1.0-mix(windMaps.x,1-windMaps.y,rainStrength),2.0),2.0));
        result.xz += windDirection_foliage*windForce/4000.0;
    #endif

    return result;
}

vec3 calcWaveLeaves(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {

    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec3 ret = (sin(pi2wt*vec3(0.0063,0.0224,0.0015)*1.5 - pos))*magnitude;

    return ret;
}

vec3 calcMoveLeaves(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWaveLeaves(pos      , 0.0054, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
    vec3 result = move1*5.*WAVY_STRENGTH * (1.0+rainStrength);
	
    #if WIND_SYSTEM_MODE > 0
        // result.xz += windDirection_foliage * length(move1.z) * (sin((windDirection_foliage.x+pos.x)*(windDirection_foliage.y+pos.z)*0.00008+frameTimeCounter)*0.5+0.5)/100.0 * (1.0+2*rainStrength);
        vec2 windMaps = vec2(texture(noisetex, (pos.xz + windDirection*5.0)/128.0).r,0.0);
        if(rainStrength > 0.001) windMaps.y = texture(noisetex, (pos.xz + windDirection*5.0)/128.0).b;
        float windForce = mix(0.0,1.0,pow(1.0-pow(1.0-mix(windMaps.x,windMaps.y,rainStrength),2.0),2.0));
	    result.xz += windDirection_foliage*windForce/4000.0 * 0.5;
    #endif
    
    return result;
}

void applyWorldCurvature(inout vec3 worldPos){

	float curvature = length(worldPos) / (16.0*8.0);
	worldPos.y -= curvature*curvature * (float(CURVATURE_AMOUNT)/10.0f);
}