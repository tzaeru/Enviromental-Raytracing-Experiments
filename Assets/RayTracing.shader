// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/RaytracerPostEffects" {
	Properties{
		_ColorTex("Screen Texture", 2D) = "white" {}
		_PosTex("Position Texture", 2D) = "white" {}
		_NormalsTex("Normals Texture", 2D) = "white" {}
	}
		SubShader{
		Pass{

		CGPROGRAM
	// Upgrade NOTE: excluded shader from DX11 because it uses wrong array syntax (type[size] name)
	#pragma target 4.6
	#pragma vertex vert
	#pragma fragment frag
	#include "UnityCG.cginc"


	uniform sampler2D _ColorTex;
	UNITY_DECLARE_TEX2D(_PosTex);
	UNITY_DECLARE_TEX2D(_NormalsTex);

	UNITY_DECLARE_TEX2DARRAY(_TrianglesTex);
	UNITY_DECLARE_TEX2DARRAY(_TriangleNormalsTex);

	struct appdata
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};

	struct v2f
	{
		float2 uv : TEXCOORD0;
		float3 worldDirection : TEXCOORD1;
		float4 vertex : SV_POSITION;
	};

	uniform float4x4 clipToWorld;
	static const int max_triangles_per_object = 2048;
	static const int max_objects = 9;
	static const float EPSILON = 0.0000001;
	//uniform float4 triangles[4042];
	uniform int objects = 0;
	uniform int triangles_per_object[max_objects];
	uniform float4x4 transform_matrices[max_objects];
	uniform float4 transform_positions[max_objects];
	uniform float aabbs[max_objects * 6];
	uniform float4 object_diffuse_colors[max_objects];

	uniform float3 camera_pos;

	struct Ray						// 48 bytes
	{
		float3 vfOrigin;			// 12 bytes
		float3 vfDirection;			// 12 bytes
		float3 vfReflectiveFactor;	// 12 bytes
		float fMinT, fMaxT;			// 8 bytes
		int iTriangleId;			// 4 bytes
	};

	struct Intersection				// 24 bytes
	{
		int iTriangleId;			// 4 bytes
		float fU, fV, fT;			// 12 bytes
		int iVisitedNodes;			// 4 bytes
		int iRoot;					// 4 bytes
	};

	bool CollisionOptimized(Ray ray, float3 A, float3 B, float3 C)
	{
		Intersection intersection;
		intersection.iTriangleId = -1;

		float3 P, T, Q;
		float3 E1 = B - A;
		float3 E2 = C - A;
		P = cross(ray.vfDirection, E2);
		float ap = dot(E1, P);
		if (ap > -EPSILON && ap < EPSILON)
			return false;
		float det = 1.0f / ap;
		T = ray.vfOrigin - A;
		intersection.fU = dot(T, P) * det;
		if (intersection.fU < 0.0 || intersection.fU > 1.0)
			return false;
		Q = cross(T, E1);
		intersection.fV = dot(ray.vfDirection, Q)*det;
		if (intersection.fV < 0.0 || intersection.fU + intersection.fV > 1.0)
			return false;
		intersection.fT = dot(E2, Q)*det;

		if (intersection.fT > EPSILON)
			return true;

		return false;
	}

	float AABBTest(Ray ray, float minx, float miny, float minz, float maxx, float maxy, float maxz) {
		float t1 = (minx - ray.vfOrigin.x) / ray.vfDirection.x;
		float t2 = (maxx - ray.vfOrigin.x) / ray.vfDirection.x;
		float t3 = (miny - ray.vfOrigin.y) / ray.vfDirection.y;
		float t4 = (maxy - ray.vfOrigin.y) / ray.vfDirection.y;
		float t5 = (minz - ray.vfOrigin.z) / ray.vfDirection.z;
		float t6 = (maxz - ray.vfOrigin.z) / ray.vfDirection.z;

		float tmin = max(max(min(t1, t2), min(t3, t4)), min(t5, t6));
		float tmax = min(min(max(t1, t2), max(t3, t4)), max(t5, t6));

		// if tmax < 0, ray (line) is intersecting AABB, but whole AABB is behing us
		if (tmax < 0) {
			return -1;
		}

		// if tmin > tmax, ray doesn't intersect AABB
		if (tmin > tmax) {
			return -1;
		}

		if (tmin < 0) {
			return tmax;
		}
		return tmin;
	}
	
	// ------------------------------------------
	// Gets the current ray intersection
	// ------------------------------------------
	Intersection getIntersection(Ray ray, float3 A, float3 B, float3 C)
	{
		Intersection intersection;
		intersection.iTriangleId = -1;

		float3 P, T, Q;
		float3 E1 = B - A;
		float3 E2 = C - A;
		P = cross(ray.vfDirection, E2);
		float det = 1.0f / dot(E1, P);
		T = ray.vfOrigin - A;
		intersection.fU = dot(T, P) * det;
		Q = cross(T, E1);
		intersection.fV = dot(ray.vfDirection, Q)*det;
		intersection.fT = dot(E2, Q)*det;

		return intersection;
	}

	// ------------------------------------------
	// Ray-Triangle intersection test
	// ------------------------------------------
	bool RayTriangleTest(Intersection intersection)
	{
		return (
			(intersection.fU >= 0.0f)
			//&& (intersection.fU <= 1.0f)
			&& (intersection.fV >= 0.0f)
			&& ((intersection.fU + intersection.fV) <= 1.0f)
			&& (intersection.fT >= 0.0f)
			);
	}


	v2f vert(appdata v)
	{
		v2f o;

		o.vertex = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;

		float4 clip = float4(o.vertex.xy, 0.0, 1.0);
		o.worldDirection = normalize(WorldSpaceViewDir(v.vertex));

		return o;
	}

	uniform float3 light_pos;

	float4 frag(v2f i) : SV_Target
	{
		float depth;
		float4 color = tex2D(_ColorTex, i.uv);
		//color = tex2D(_PosTex, i.uv);	
		//float3 worldspace = _PosTex.Load(int4(i.uv.x, i.uv.y, 0, 0));
		//float3 worldspace = tex2D(sampler_PosTex, i.uv);
		float3 worldspace = _PosTex.Load(int4((i.uv.x)*_ScreenParams.x, (i.uv.y)*_ScreenParams.y, 0, 0))/2.0;
		//color = float4 (worldspace, 1.0);

		float4 normal = _NormalsTex.Load(int4((i.uv.x)*_ScreenParams.x, (i.uv.y)*_ScreenParams.y, 0, 0));

		Ray ray;
		ray.vfOrigin = worldspace;
		ray.vfDirection = normalize(light_pos - worldspace);
		ray.vfOrigin += ray.vfDirection * 0.00001;

		//if (length(worldspace - float3(-0.6, 0.8140001, -0.392)) < 0.1)
		//	color.r = 1.0;
		//if (worldspace.x < 0.815)
		//	color.r = 1.0;


		bool hit = false;
		for (int object = 0; object < objects; object++)
		{
			float3 aabb_min = mul(transform_matrices[object], float3(aabbs[object * 6 + 0], aabbs[object * 6 + 1], aabbs[object * 6 + 2]));
			float3 aabb_max = mul(transform_matrices[object], float3(aabbs[object * 6 + 3], aabbs[object * 6 + 4], aabbs[object * 6 + 5]));

			if (AABBTest(ray, aabb_min.x, aabb_min.y, aabb_min.z, aabb_max.x, aabb_max.y, aabb_max.z) < 0.0)
			{
				//continue;
			}

			for (int vert = 0; vert < triangles_per_object[object]; vert++)
			{
				float3 point1 = mul(transform_matrices[object], _TrianglesTex.Load(int4(vert, 0, object, 0)));
				float3 point2 = mul(transform_matrices[object], _TrianglesTex.Load(int4(vert, 1, object, 0)));
				float3 point3 = mul(transform_matrices[object], _TrianglesTex.Load(int4(vert, 2, object, 0)));

				if (RayTriangleTest(getIntersection(ray, point1, point2, point3)))
				{
					color *= 0.8;
					//color.r = 0.8;
					hit = true;
					break;
				}
				//else
				//	color.b = 0.8;
			}

			if (hit)
				break;
		}

		hit = false;

		// Reflection here
		if (normal.w > 0.01)
		{
			//float3 camera_dir = normalize(camera_pos - worldspace);

			Ray ray;
			ray.vfOrigin = worldspace;
			//ray.vfDirection = reflect(normalize(i.worldDirection), normalize(normal.xyz));
			//i.worldDirection.y = -i.worldDirection.y;
			ray.vfDirection = reflect(normalize(normal.xyz), normalize(i.worldDirection));
			ray.vfOrigin += ray.vfDirection * 0.0001;

			//color = float4(ray.vfDirection, 1.0);
			float closest_distance = 1000000.0;
			float3 closest_normal;
			float4 closest_color;
			float3 hit_direction;
			for (int object = 0; object < objects; object++)
			{
				float3 aabb_min = mul(transform_matrices[object], float3(aabbs[object * 6 + 0], aabbs[object * 6 + 1], aabbs[object * 6 + 2]));
				float3 aabb_max = mul(transform_matrices[object], float3(aabbs[object * 6 + 3], aabbs[object * 6 + 4], aabbs[object * 6 + 5]));

				if (AABBTest(ray, aabb_min.x, aabb_min.y, aabb_min.z, aabb_max.x, aabb_max.y, aabb_max.z) < 0.0)
				{
					//continue;
				}

				for (int vert = 0; vert < triangles_per_object[object]; vert++)
				{
					float3 point1 = mul(transform_matrices[object], _TrianglesTex.Load(int4(vert, 0, object, 0)));
					float3 point2 = mul(transform_matrices[object], _TrianglesTex.Load(int4(vert, 1, object, 0)));
					float3 point3 = mul(transform_matrices[object], _TrianglesTex.Load(int4(vert, 2, object, 0)));

					Intersection intersection = getIntersection(ray, point1, point2, point3);
					if (RayTriangleTest(intersection))
					{
						if (intersection.fT < closest_distance)
						{
							closest_distance = intersection.fT;
							closest_color = object_diffuse_colors[object];
							// We get a hacky per-triangle normal.
							closest_normal = normalize(mul(transform_matrices[object], _TriangleNormalsTex.Load(int4(vert, 0, object, 0))).xyz);
							hit_direction = ray.vfDirection;
						}
						hit = true;
					}
				}
			}

			if (hit)
			{
				// Hacky ad-hoc lighting calculation
				float3 lightDir = normalize(light_pos - (worldspace + closest_distance * hit_direction));

				/* compute the distance to the light source to a varying variable*/
				float dist = length(lightDir);

				// Calculate the cosine of the angle between the vertex's normal vector
				// and the vector going to the light.
				float cos_angle = dot(closest_normal, lightDir);
				cos_angle = clamp(cos_angle, 0.0, 1.0);

				// Scale the color of this fragment based on its angle to the light.
				float4 reflection = (closest_color * cos_angle);

				// Reflection strength from w
				color = color * (1.0 - normal.w) + reflection * normal.w;
			}
		}
		//float4 color = tex2D(_MainTex, i.uv) + float4((light_pos - worldspace), 1.0);
		//color = float4(light_pos - worldspace, 1.0);
		
		return color;
	}
		ENDCG
	}
	}

}