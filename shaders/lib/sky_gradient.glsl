#define ffstep(x,y) clamp((y - x) * 1e35,0.0,1.0)

vec3 drawSun(float cosY, float sunInt,vec3 nsunlight,vec3 inColor){
	return inColor+nsunlight/0.0008821203*pow(smoothstep(cos(0.0093084168595*3.2),cos(0.0093084168595*1.8),cosY),3.)*0.62;
}

vec3 drawMoon(vec3 PlayerPos, vec3 WorldSunVec, vec3 Color, inout vec3 occludeStars){

	float Shape = clamp((exp(1 + -1000 * dot(WorldSunVec+PlayerPos,PlayerPos)) - 1.5),0.0,25.0);
	occludeStars *= max(1.0-Shape*5,0.0);

	float shape2 = pow(exp(Shape * -10),0.15) * 255.0;

	vec3 sunNormal = vec3(dot(WorldSunVec+PlayerPos, vec3(shape2,0,0)), dot(PlayerPos+WorldSunVec, vec3(0,shape2,0)), -dot(WorldSunVec, PlayerPos) * 15.0);


	// even has a little tilt approximation haha.... yeah....
	vec3[8] phase = vec3[8](
		vec3( -1.0,	 -0.5,	 1.0	),
		vec3( -1.0,	 -0.5,	 0.35	),
		vec3( -1.0,	 -0.5,   0.2	),
		vec3( -1.0,	 -0.5,   0.1	),
		vec3(  1.0,	 0.25,	-1.0	),
		vec3(  1.0,	 0.25,	 0.1	),
		vec3(  1.0,	 0.25,	 0.2	),
		vec3(  1.0,	 0.25,	 0.35	)
	);
	
	vec3 LightDir = phase[moonPhase];

	return Shape * pow(clamp(dot(sunNormal,LightDir)/5,0.0,1.5),5) * Color  + clamp(Shape * 4.0 * pow(shape2/200,2.0),0.0,1.0)*0.004;
}

const float pi = 3.141592653589793238462643383279502884197169;



float w0(float a)
{
    return (1.0/6.0)*(a*(a*(-a + 3.0) - 3.0) + 1.0);
}

float w1(float a)
{
    return (1.0/6.0)*(a*a*(3.0*a - 6.0) + 4.0);
}

float w2(float a)
{
    return (1.0/6.0)*(a*(a*(-3.0*a + 3.0) + 3.0) + 1.0);
}

float w3(float a)
{
    return (1.0/6.0)*(a*a*a);
}

float g0(float a)
{
    return w0(a) + w1(a);
}

float g1(float a)
{
    return w2(a) + w3(a);
}

float h0(float a)
{
    return -1.0 + w1(a) / (w0(a) + w1(a));
}

float h1(float a)
{
    return 1.0 + w3(a) / (w2(a) + w3(a));
}

vec4 texture2D_bicubic(sampler2D tex, vec2 uv)
{
	vec4 texelSize = vec4(texelSize,1.0/texelSize);
	uv = uv*texelSize.zw;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) * texelSize.xy;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) * texelSize.xy;

    return g0(fuv.y) * (g0x * texture2D(tex, p0)  +
                        g1x * texture2D(tex, p1)) +
           g1(fuv.y) * (g0x * texture2D(tex, p2)  +
                        g1x * texture2D(tex, p3));
}
vec4 texture2D_bicubic_offset(sampler2D tex, vec2 uv, float noise, float scale)
{
	float offsets = noise * (2.0 * 3.141592653589793238462643383279502884197169);
	vec2 circleOffsets = vec2(sin(offsets), cos(offsets)) * scale;
	
	#ifdef SCREENSHOT_MODE
		circleOffsets = vec2(0.0);
	#endif
	
	vec4 texelSize = vec4(texelSize,1.0/texelSize);
	uv = (uv + texelSize.xy)*texelSize.zw;
	
	vec2 iuv = floor( uv + circleOffsets );
	vec2 fuv = fract( uv + circleOffsets );

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) * (texelSize.xy);
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) * (texelSize.xy);
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) * (texelSize.xy);
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) * (texelSize.xy);

    return (g0(fuv.y) * (g0x * texture2D(tex, p0)  +
                        g1x * texture2D(tex, p1)) +
           g1(fuv.y) * (g0x * texture2D(tex, p2)  +
                        g1x * texture2D(tex, p3)));
}

vec2 sphereToCarte(vec3 dir) {
    float lonlat = clamp(atan(-dir.x, -dir.z), -pi, pi);
    return vec2(lonlat * (0.5/pi) +0.5,0.5*dir.y+0.5);
}

vec3 skyFromTex(vec3 pos,sampler2D sampler){
	vec2 p = sphereToCarte(pos);
	return texture2D(sampler,p*texelSize*256.+vec2(18.5,1.5)*texelSize).rgb;
}
vec3 skyFromTexLOD(vec3 pos,sampler2D sampler, float LOD){
	vec2 p = sphereToCarte(pos);
	return texture2DLod(sampler,p*texelSize*256.+vec2(18.5,1.5)*texelSize,LOD).rgb;
}
vec4 skyCloudsFromTex(vec3 pos,sampler2D sampler){
	vec2 p = sphereToCarte(pos);
	return texture2D(sampler,p*texelSize*256.+vec2(18.5+257.,1.5)*texelSize);
}
vec4 skyCloudsFromTexLOD(vec3 pos,sampler2D sampler, float LOD){
	vec2 p = sphereToCarte(pos);
	return texture2DLod(sampler,p*texelSize*256. + vec2(18.5 + 257., 1.5)*texelSize,LOD);
}

vec4 skyCloudsFromTexLOD2(vec3 pos,sampler2D sampler, float LOD){
	vec2 p = sphereToCarte(pos);
	return texture2DLod(sampler,p*texelSize*256. + vec2(256.0 - 256.0*0.12,1.5)*texelSize,LOD);
}