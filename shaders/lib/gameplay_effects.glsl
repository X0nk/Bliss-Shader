#ifdef IS_IRIS
    uniform float currentPlayerHealth;
    uniform float maxPlayerHealth;
    uniform float oneHeart;
    uniform float threeHeart;
#else
    uniform bool isDead;
#endif

uniform float hurt;

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


void applyGameplayEffects_FRAGMENT(inout vec3 color, in vec2 texcoord){
    
    #if defined LOW_HEALTH_EFFECT || defined DAMAGE_TAKEN_EFFECT
        // detect when health is zero
        #ifdef IS_IRIS
            bool isDead = currentPlayerHealth * maxPlayerHealth <= 0.0 && currentPlayerHealth > -1;
        #else
            float oneHeart = 0.0;
            float threeHeart = 0.0;
        #endif
        
        float vignette = sqrt(clamp(dot(texcoord*2.0 - 1.0, texcoord*2.0 - 1.0) * 0.5, 0.0, 1.0));
        
        // heart beat effect to scale stuff with, make it more intense. theres a multiplier "MOTION_AMOUNT" for accessiblity 
        float beatingRate = isDead ? 0.0 : (oneHeart > 0.0 ? 15.0 : 7.5);
        float heartBeat = (pow(sin(frameTimeCounter * beatingRate)*0.5+0.5,2.0)*0.2 + 0.1);

        // scale UV to be more and more lower frequency towards the edges of the screen, to create a tunnel vision effect,
        vec2 zoomUV = 0.5 + (texcoord - 0.5) * (1.0 - vignette * (isDead ? 0.7 : heartBeat * MOTION_AMOUNT));
        vec3 distortedScreen = vec3(1.0, 0.0, 0.0) * dot(texture2D(colortex7, zoomUV).rgb, vec3(0.21, 0.72, 0.07));
       
        #ifdef LOW_HEALTH_EFFECT
            // at 1 heart or 3 hearts, create 2 levels of a strain / tunnel vision effect.

            // black and white version of the scene color.
            vec3 colorLuma = vec3(1.0, 1.0, 1.0) * dot(color,vec3(0.21, 0.72, 0.07));

            // I LOVE LINEAR INTERPOLATION
            color = mix(color, mix(colorLuma, distortedScreen, vignette), mix(vignette * threeHeart, oneHeart, oneHeart));

            if(isDead) color = distortedScreen*0.3;
        #endif


        #ifdef DAMAGE_TAKEN_EFFECT
            // when damage is taken, flash the above effect. because it uses the stuff above, it seamlessly blends to them.
            color = mix(color, distortedScreen, (vignette*vignette) * sqrt(hurt));
        #endif


        // if(isDead) color = vec3(0);
    #endif
}