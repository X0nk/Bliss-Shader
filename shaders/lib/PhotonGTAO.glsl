
// Common constants

const float eps          = 1e-6;
const float e            = exp(1.0);
const float tau          = 2.0 * pi;
const float half_pi      = 0.5 * pi;
const float rcp_pi       = 1.0 / pi;
const float degree       = tau / 360.0; // Size of one degree in radians, useful because radians() is not a constant expression on all platforms
const float golden_ratio = 0.5 + 0.5 * sqrt(5.0);
const float golden_angle = tau / golden_ratio / golden_ratio;
const float hand_depth   = 0.56;

#if defined TAA && defined TAA_UPSCALING
const float taau_render_scale = RENDER_SCALE.x;
#else
const float taau_render_scale = 1.0;
#endif

// Helper functions

#define rcp(x) (1.0 / (x))
#define clamp01(x) clamp(x, 0.0, 1.0) // free on operation output
#define max0(x) max(x, 0.0)
#define min1(x) min(x, 1.0)

float sqr(float x) { return x * x; }
vec2  sqr(vec2  v) { return v * v; }
vec3  sqr(vec3  v) { return v * v; }
vec4  sqr(vec4  v) { return v * v; }

float cube(float x) { return x * x * x; }

float max_of(vec2 v) { return max(v.x, v.y); }
float max_of(vec3 v) { return max(v.x, max(v.y, v.z)); }
float max_of(vec4 v) { return max(v.x, max(v.y, max(v.z, v.w))); }
float min_of(vec2 v) { return min(v.x, v.y); }
float min_of(vec3 v) { return min(v.x, min(v.y, v.z)); }
float min_of(vec4 v) { return min(v.x, min(v.y, min(v.z, v.w))); }

float length_squared(vec2 v) { return dot(v, v); }
float length_squared(vec3 v) { return dot(v, v); }

vec2 normalize_safe(vec2 v) { return v == vec2(0.0) ? v : normalize(v); }
vec3 normalize_safe(vec3 v) { return v == vec3(0.0) ? v : normalize(v); }

float rcp_length(vec2 v) { return inversesqrt(dot(v, v)); }
float rcp_length(vec3 v) { return inversesqrt(dot(v, v)); }

float fast_acos(float x) {
	const float C0 = 1.57018;
	const float C1 = -0.201877;
	const float C2 = 0.0464619;

	float res = (C2 * abs(x) + C1) * abs(x) + C0; // p(x)
	res *= sqrt(1.0 - abs(x));

	return x >= 0 ? res : pi - res; // Undo range reduction
}
vec2 fast_acos(vec2 v) { return vec2(fast_acos(v.x), fast_acos(v.y)); }

uniform vec2 view_res;
uniform vec2 view_pixel_size;

float linear_step(float edge0, float edge1, float x) {
	return clamp01((x - edge0) / (edge1 - edge0));
}

vec2 linear_step(vec2 edge0, vec2 edge1, vec2 x) {
	return clamp01((x - edge0) / (edge1 - edge0));
}

vec4 project(mat4 m, vec3 pos) {
    return vec4(m[0].x, m[1].y, m[2].zw) * pos.xyzz + m[3];
}
vec3 project_and_divide(mat4 m, vec3 pos) {
    vec4 homogenous = project(m, pos);
    return homogenous.xyz / homogenous.w;
}

vec3 screen_to_view_space(vec3 screen_pos, bool handle_jitter) {
	vec3 ndc_pos = 2.0 * screen_pos - 1.0;

	return project_and_divide(gbufferProjectionInverse, ndc_pos);
}

vec3 view_to_screen_space(vec3 view_pos, bool handle_jitter) {
	vec3 ndc_pos = project_and_divide(gbufferProjection, view_pos);


	return ndc_pos * 0.5 + 0.5;
}


// ---------------------
//   ambient occlusion
// ---------------------

#define GTAO_SLICES        2
#define GTAO_HORIZON_STEPS 3
#define GTAO_RADIUS        2.0
#define GTAO_FALLOFF_START 0.75

float integrate_arc(vec2 h, float n, float cos_n) {
	vec2 tmp = cos_n + 2.0 * h * sin(n) - cos(2.0 * h - n);
	return 0.25 * (tmp.x + tmp.y);
}

float calculate_maximum_horizon_angle(
	vec3 view_slice_dir,
	vec3 viewer_dir,
	vec3 screen_pos,
	vec3 view_pos,
	float dither
) {
	const float step_size = GTAO_RADIUS * rcp(float(GTAO_HORIZON_STEPS));

	float max_cos_theta = -1.0;

	vec2 ray_step = (view_to_screen_space(view_pos + view_slice_dir * step_size, true) - screen_pos).xy;
	vec2 ray_pos = screen_pos.xy + ray_step * (dither + max_of(view_pixel_size) * rcp_length(ray_step));


	for (int i = 0; i < GTAO_HORIZON_STEPS; ++i, ray_pos += ray_step) {
		float depth = texelFetch2D(depthtex1, ivec2(clamp(ray_pos,0.0,1.0) * view_res * taau_render_scale - 0.5), 0).x;

		if (depth == 1.0 || depth < hand_depth || depth == screen_pos.z) continue;

		vec3 offset = screen_to_view_space(vec3(ray_pos, depth), true) - view_pos;

		float len_sq = length_squared(offset);
		float norm = inversesqrt(len_sq);

		float distance_falloff = linear_step(GTAO_FALLOFF_START * GTAO_RADIUS, GTAO_RADIUS, len_sq * norm);

		float cos_theta = dot(viewer_dir, offset) * norm;
		      cos_theta = mix(cos_theta, -1.0, distance_falloff);

		max_cos_theta = max(cos_theta, max_cos_theta);
	}

	return fast_acos(clamp(max_cos_theta, -1.0, 1.0));
}

float ambient_occlusion(vec3 screen_pos, vec3 view_pos, vec3 view_normal, vec2 dither) {
	float ao = 0.0;

	// Construct local working space
	vec3 viewer_dir   = normalize(-view_pos);
	vec3 viewer_right = normalize(cross(vec3(0.0, 1.0, 0.0), viewer_dir));
	vec3 viewer_up    = cross(viewer_dir, viewer_right);
	mat3 local_to_view = mat3(viewer_right, viewer_up, viewer_dir);

	for (int i = 0; i < GTAO_SLICES; ++i) {
		float slice_angle = (i + dither.x) * (pi / float(GTAO_SLICES));

		vec3 slice_dir = vec3(cos(slice_angle), sin(slice_angle), 0.0);
		vec3 view_slice_dir = local_to_view * slice_dir;

		vec3 ortho_dir = slice_dir - dot(slice_dir, viewer_dir) * viewer_dir;
		vec3 axis = cross(slice_dir, viewer_dir);

		vec3 projected_normal = view_normal - axis * dot(view_normal, axis);

		float len_sq = dot(projected_normal, projected_normal);
		float norm = inversesqrt(len_sq);

		float sgn_gamma = sign(dot(ortho_dir, projected_normal));
		float cos_gamma = clamp01(dot(projected_normal, viewer_dir) * norm);
		float gamma = sgn_gamma * fast_acos(cos_gamma);

		vec2 max_horizon_angles;
		max_horizon_angles.x = calculate_maximum_horizon_angle(-view_slice_dir, viewer_dir, screen_pos, view_pos, dither.y);
		max_horizon_angles.y = calculate_maximum_horizon_angle( view_slice_dir, viewer_dir, screen_pos, view_pos, dither.y);

		max_horizon_angles = gamma + clamp(vec2(-1.0, 1.0) * max_horizon_angles - gamma, -half_pi, half_pi) ;


		ao += integrate_arc(max_horizon_angles, gamma, cos_gamma) * len_sq * norm  ;
	}
	ao *= rcp(float(GTAO_SLICES));
	return ao*(ao*0.5+0.5);
}
