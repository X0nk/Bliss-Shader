#ifdef IS_IRIS
    uniform float currentPlayerHealth;
    uniform float maxPlayerHealth;
    uniform float oneHeart;
    uniform float threeHeart;

    uniform float CriticalDamageTaken;
    uniform float MinorDamageTaken;
    // uniform float currentPlayerAir;
#else
    uniform bool isDead;
#endif

uniform float fireLavaInteract;
uniform float waterInteract;
uniform int isEyeInWater;
uniform vec3 waterIntersectDir;
// uniform float exitPowderSnow;
// uniform float currentPlayerHunger;
// uniform float maxPlayerHunger;
// uniform float currentPlayerArmor;
// uniform float maxPlayerArmor;
// uniform float currentPlayerAir;
// uniform float maxPlayerAir;
// uniform bool is_sneaking;
// uniform bool is_sprinting;
// uniform bool is_hurt;
// uniform bool is_invisible;
// uniform bool is_burning;
// uniform bool is_on_ground;
// uniform bool isSpectator;

void getWaterDistortionEffects(inout vec2 texcoord){
    vec2 scaleTexcoord = (texcoord-0.5)*vec2(aspectRatio, 1.0);

	vec3 centerPixelViewPos = toScreenSpace(vec3(0.5,0.5,1.0));
	vec3 centerPixelPlayerPos = mat3(gbufferModelViewInverse) * centerPixelViewPos + normalize(waterIntersectDir);
    vec2 offsetTexcoord = toClipSpace3(mat3(gbufferModelView) * centerPixelPlayerPos).xy;

    float enterSpeed = pow(clamp(length(waterIntersectDir)*15.0,0.0,1),2.0);
    vec2 enterDir = (offsetTexcoord.xy-0.5)*1000.0;
    float dotvn = dot(scaleTexcoord.xy,enterDir);

    vec2 splash = vec2(0.0);
    
    // UV animation
    if(isEyeInWater > 0){
        splash += waterInteract * (-scaleTexcoord*clamp(clamp(dotvn*5.0,-1.0,1.0)*0.3+0.7,0.0,1.0)*2.0 + enterDir*clamp(clamp(dotvn*3.0,-1.0,1.0)*0.5+0.5,0.0,1.0)*5.0) * (0.5+0.5*enterSpeed);
    }else{
        splash += waterInteract * enterDir * (1.0 + 5.0*enterSpeed) * clamp(clamp(-dotvn*3.0,-1.0,1.0)*0.5+0.5,0.0,1.0);
    }

    float modifierValue = texture(noisetex, (scaleTexcoord + splash)*0.5).r;

    // animated modifierValue altercation
    if(isEyeInWater > 0){
        modifierValue = modifierValue*(1.0-waterInteract);
    }else{
        modifierValue = sqrt(min(max(modifierValue - (1.0-sqrt((1.0-waterInteract)))*0.7,0.0) * (1.0 + (1.0-waterInteract)),1.0)) * 0.5;
    }

    texcoord -= (texcoord-0.5) * modifierValue * (float(WATER_ON_CAMERA_EFFECT_AMOUNT/50.0));
}

void getFireDistortionEffects(inout vec2 texcoord){

    vec2 scaleTexcoord = (texcoord-0.5)*vec2(aspectRatio, 1.0);

    vec2 zoomin = 0.5 + scaleTexcoord * (1.0-pow(1.0-clamp(-texcoord.y*0.5+0.75,0.0,1.0),1.0)) * (1.0-pow(1.0-fireLavaInteract,2.0));
    float modifierValue = texture(noisetex,  zoomin * vec2(aspectRatio,1.0) - vec2(0.0,frameTimeCounter*0.3)).b * clamp(-texcoord.y*0.3+0.3,0.0,1.0) * (float(ON_FIRE_DISTORT_EFFECT_AMOUNT)/100.0) * fireLavaInteract;

    texcoord -= (texcoord-0.5) * modifierValue;
}

vec3 getHealthStatusColorEffects(in vec3 color, in vec2 texcoord, in float noise){
    // detect when health is zero
    #ifdef IS_IRIS
        bool isDead = currentPlayerHealth * maxPlayerHealth <= 0.0 && currentPlayerHealth > -1;
    #else
        float oneHeart = 0.0;
        float threeHeart = 0.0;
    #endif

    if(isDead){
        // apply death effect. since death is binary anything else running doesnt matter.
        vec2 offsetTexcoord = texcoord - (texcoord-0.5) * (length(texcoord*2.0-1.0)*0.7) * (0.7 + noise*0.3);
        return dot(texture(colortex7, offsetTexcoord).rgb, vec3(0.21, 0.72, 0.07)) * vec3(0.35,0.0,0.0);
    }else{
        float vignette = length(texcoord*2.0-1.0)*0.7;
        float heartBeat = (pow(sin(frameTimeCounter * 15)*0.5+0.5,2.0)*0.2 + 0.1);

        // apply low health distortion effects
        float modifierValue = vignette * noise * heartBeat * threeHeart;

        #if CRITICALLY_LOW_HEALTH_EFFECT_START > 0 
            // apply critical hit distortion effect
            modifierValue = mix(modifierValue, vignette * (0.5 + noise), CriticalDamageTaken) * MOTION_AMOUNT;
        #endif

        // sample color with offset texcoord
        vec2 offsetTexcoord = texcoord - (texcoord-0.5) * modifierValue;
        vec3 sampleColor = texture(colortex7, offsetTexcoord).rgb;

        // setup various colors to blend together
        float distortedColorLuma = dot(sampleColor, vec3(0.21, 0.72, 0.07));
        float colorLuma = dot(color, vec3(0.21, 0.72, 0.07));

        // blend colors together based on status
        vec3 redVignette = mix(vec3(colorLuma), vec3(1.0, 0.3, 0.3) * distortedColorLuma, vignette);

        #if LOW_HEALTH_EFFECT_START > 0 || CRITICALLY_LOW_HEALTH_EFFECT_START > 0
            color = mix(color, redVignette, mix(vignette * threeHeart, oneHeart, oneHeart));
        #endif

        #if MINOR_DAMAGE_TAKEN_EFFECT_START > 0
            color = mix(color, redVignette, vignette * sqrt(min(MinorDamageTaken,1.0)));
        #endif

        #if CRITICAL_DAMAGE_TAKEN_EFFECT_START > 0
            color = mix(color, redVignette, sqrt(CriticalDamageTaken));
        #endif
    
        return color;
    }
}