// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/SampleImageEffect" {
	Properties{
		_MainTex("Screen Texture", 2D) = "white" {}
	}
		SubShader{
		Pass{

		CGPROGRAM
	// Upgrade NOTE: excluded shader from DX11 because it uses wrong array syntax (type[size] name)
	#pragma target 4.6
	#pragma vertex vert
	#pragma fragment frag
	#include "UnityCG.cginc"


	sampler2D _MainTex;
	UNITY_DECLARE_TEX2DARRAY(_TrianglesTex);

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
		o.worldDirection = mul(clipToWorld, clip) - _WorldSpaceCameraPos;

		return o;
	}

	sampler2D_float _CameraDepthTexture;
	float4 _CameraDepthTexture_ST;
	float3 light_pos;

	float4 frag(v2f i) : SV_Target
	{
		float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
		depth = LinearEyeDepth(depth);
		float3 worldspace = i.worldDirection * depth + _WorldSpaceCameraPos;

		float4 color = (0.0, 0.0, 0.0, 0.0);
		color = tex2D(_MainTex, i.uv);
		//color = float4((light_pos - worldspace), 1.0);
		// Use to verify real points
		//color += abs(mul(transform_matrices[3], UNITY_SAMPLE_TEX2DARRAY(_TrianglesTex, float3(i.uv.r, 2, 3))));
		
		// Triangle test
		/*float3 point1 = float3(0.0, 2.0, -2.0);
		float3 point2 = float3(-2.0, 2.0, 2.0);
		float3 point3 = float3(2.0, 2.0, 2.0);

		Ray ray;
		ray.vfOrigin = worldspace;
		ray.vfDirection = light_pos - worldspace;

		if (RayTriangleTest(getIntersection(ray, point1, point2, point3)))
		{
			color.r += 0.8;
		}*/

		bool hit = false;
		for (int object = 0; object < objects; object++)
		{
			for (int vert = 0; vert < triangles_per_object[object]; vert++)
			{
				float3 point1 = mul(transform_matrices[object], _TrianglesTex.Load(int4(vert, 0, object, 0)));
				float3 point2 = mul(transform_matrices[object], _TrianglesTex.Load(int4(vert, 1, object, 0)));
				float3 point3 = mul(transform_matrices[object], _TrianglesTex.Load(int4(vert, 2, object, 0)));

				/*float3 point1 = _TrianglesTex.Load(int4(vert, 0, object, 0)).xyz + transform_positions[object];
				float3 point2 = _TrianglesTex.Load(int4(vert, 1, object, 0)).xyz + transform_positions[object];
				float3 point3 = _TrianglesTex.Load(int4(vert, 2, object, 0)).xyz + transform_positions[object];*/

				/*float3 point1 = mul(_TrianglesTex.Load(int4(vert, 0, object, 0)).xyz, transform_matrices[object]);
				float3 point2 = mul(_TrianglesTex.Load(int4(vert, 1, object, 0)).xyz, transform_matrices[object]);
				float3 point3 = mul(_TrianglesTex.Load(int4(vert, 2, object, 0)).xyz, transform_matrices[object]);*/

				/*float3 point1 = UNITY_SAMPLE_TEX2DARRAY(_TrianglesTex, float3(vert/(float)max_triangles_per_object, 0, object / (float)max_objects)) + transform_positions[object];
				float3 point2 = UNITY_SAMPLE_TEX2DARRAY(_TrianglesTex, float3(vert / (float)max_triangles_per_object, 0.3, object / (float)max_objects)) + transform_positions[object];
				float3 point3 = UNITY_SAMPLE_TEX2DARRAY(_TrianglesTex, float3(vert / (float)max_triangles_per_object, 0.7, object / (float)max_objects)) + transform_positions[object];*/

				//float3 point1 = UNITY_SAMPLE_TEX2DARRAY(_TrianglesTex, float3(vert, 0, object)) + transform_positions[object];
				//float3 point2 = UNITY_SAMPLE_TEX2DARRAY(_TrianglesTex, float3(vert, 1, object)) + transform_positions[object];
				//float3 point3 = UNITY_SAMPLE_TEX2DARRAY(_TrianglesTex, float3(vert, 2, object)) + transform_positions[object];

				// USE TO VERIFY REAL POINTS.
				//color += distance(worldspace, point1) * 0.00001;
				Ray ray;
				ray.vfOrigin = worldspace;
				ray.vfDirection = light_pos - worldspace;
				ray.vfOrigin += normalize(ray.vfDirection)*0.001;
				if (RayTriangleTest(getIntersection(ray, point1, point2, point3)))
				{
					color *= 0.8;
					hit = true;
					break;
				}
				//else
				//	color.b = 0.8;
				if (hit)
					break;
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