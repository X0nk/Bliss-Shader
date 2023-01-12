vec4 smoothfilter(in sampler2D tex, in vec2 uv, in vec2 textureResolution)
{
	uv = uv*textureResolution + 0.5;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );
	uv = iuv + (fuv*fuv)*(3.0-2.0*fuv); 
	uv = uv/textureResolution - 0.5/textureResolution;
	return texture2D( tex, uv);
}

float shadowsmoothfilter(in sampler2DShadow tex, in vec3 uv,in float textureResolution)
{
	uv.xy = uv.xy*textureResolution + 0.5;
	vec2 iuv = floor( uv.xy );
	vec2 fuv = fract( uv.xy );
	uv.xy = iuv + (fuv*fuv)*(3.0-2.0*fuv); 
	uv.xy = uv.xy/textureResolution - 0.5/textureResolution;
	return shadow2D( tex, uv).x;
}
