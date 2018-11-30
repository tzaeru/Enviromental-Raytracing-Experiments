// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Object Shader With Several Outputs" {
	Properties{
		_Texture("Main Text", 2D) = "white"{}
		_Color("Diffuse Material Color", Color) = (1,1,1,1)
		_SpecColor("Specular Material Color", Color) = (1,1,1,1)
		_Shininess("Shininess", Float) = 10
		_Reflection("Reflection", Float) = 0.0
	}
		SubShader{
		Pass{
		Tags{ "LightMode" = "ForwardBase" }
		// pass for ambient light and 
		// first directional light source without attenuation

		CGPROGRAM

#pragma vertex vert  
#pragma fragment frag 

#include "UnityCG.cginc"
		uniform float4 _LightColor0;
	// color of light source (from "Lighting.cginc")

	// User-specified properties
	uniform float4 _Color;
	uniform float4 _SpecColor;
	uniform float _Shininess;

	sampler2D _Texture;
	float4 _Texture_ST;

	float _Reflection;

	struct vertexInput {
		float4 vertex : POSITION;
		float3 normal : NORMAL;
		float2 uv : TEXCOORD0;
	};
	struct vertexOutput {
		float4 pos : SV_POSITION;
		float4 posWorld : TEXCOORD0;
		float3 normalDir : TEXCOORD1;
		float2 uv : TEXCOORD2;
	};

	vertexOutput vert(vertexInput input)
	{
		vertexOutput output;

		float4x4 modelMatrix = unity_ObjectToWorld;
		float4x4 modelMatrixInverse = unity_WorldToObject;

		output.posWorld = mul(modelMatrix, input.vertex);
		output.normalDir = normalize(
			mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
		output.pos = UnityObjectToClipPos(input.vertex);
		output.uv = TRANSFORM_TEX(input.uv, _Texture);
		return output;
	}

	struct FragmentOutput
	{
		float4 color : SV_Target0;
		float4 position : SV_Target1;
		float4 normal : SV_Target2;
	};

	

	FragmentOutput frag(vertexOutput input)
	{
		float3 normalDirection = normalize(input.normalDir);

		float3 viewDirection = normalize(
			_WorldSpaceCameraPos - input.posWorld.xyz);
		float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);

		float3 ambientLighting =
			UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb * tex2D(_Texture, input.uv);

		float3 diffuseReflection = _LightColor0.rgb * _Color.rgb
			* max(0.0, dot(normalDirection, lightDirection)) * tex2D(_Texture, input.uv);

		float3 specularReflection;
		if (dot(normalDirection, lightDirection) < 0.0)
			// light source on the wrong side?
		{
			specularReflection = float3(0.0, 0.0, 0.0);
			// no specular reflection
		}
		else // light source on the right side
		{
			specularReflection = _LightColor0.rgb
				* _SpecColor.rgb * pow(max(0.0, dot(
					reflect(-lightDirection, normalDirection),
					viewDirection)), _Shininess);
		}

		FragmentOutput o;
		//o.dest0 = float4(1.0, 1.0, 1.0, 1.0);

		o.color = float4(ambientLighting + diffuseReflection
			+ specularReflection, 1.0);
		o.position = input.posWorld;
		o.normal = float4(input.normalDir, _Reflection);
		return o;
	}

		ENDCG
	}

		Pass{
		Tags{ "LightMode" = "ForwardAdd" }
		// pass for additional light sources
		Blend One One // additive blending 

		CGPROGRAM

#pragma vertex vert  
#pragma fragment frag 

#include "UnityCG.cginc"
		uniform float4 _LightColor0;
	// color of light source (from "Lighting.cginc")
	uniform float4x4 unity_WorldToLight; // transformation 
									// from world to light space (from Autolight.cginc)
	uniform sampler2D _LightTextureB0;
	// cookie alpha texture map (from Autolight.cginc)

	// User-specified properties
	uniform float4 _Color;
	uniform float4 _SpecColor;
	uniform float _Shininess;

	float _Reflection;

	struct vertexInput {
		float4 vertex : POSITION;
		float3 normal : NORMAL;
	};
	struct vertexOutput {
		float4 pos : SV_POSITION;
		float4 posWorld : TEXCOORD0;
		// position of the vertex (and fragment) in world space 
		float4 posLight : TEXCOORD1;
		// position of the vertex (and fragment) in light space
		float3 normalDir : TEXCOORD2;
		// surface normal vector in world space
	};

	vertexOutput vert(vertexInput input)
	{
		vertexOutput output;

		float4x4 modelMatrix = unity_ObjectToWorld;
		float4x4 modelMatrixInverse = unity_WorldToObject;

		output.posWorld = mul(modelMatrix, input.vertex);
		output.posLight = mul(unity_WorldToLight, output.posWorld);
		output.normalDir = normalize(
			mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
		output.pos = UnityObjectToClipPos(input.vertex);
		return output;
	}

	struct FragmentOutput
	{
		float4 color : SV_Target0;
		float4 position : SV_Target1;
		float4 normal : SV_Target2;
	};

	FragmentOutput frag(vertexOutput input) : SV_TARGET
	{
		float3 normalDirection = normalize(input.normalDir);

		float3 viewDirection = normalize(
			_WorldSpaceCameraPos - input.posWorld.xyz);
		float3 lightDirection;
		float attenuation;

		if (0.0 == _WorldSpaceLightPos0.w) // directional light?
		{
			attenuation = 1.0; // no attenuation
			lightDirection = normalize(_WorldSpaceLightPos0.xyz);
		}
		else // point or spot light
		{
			float3 vertexToLightSource =
				_WorldSpaceLightPos0.xyz - input.posWorld.xyz;
			lightDirection = normalize(vertexToLightSource);

			float distance = input.posLight.z;

			attenuation =
				tex2D(_LightTextureB0, float2(distance, distance)).a;
		}

		float3 diffuseReflection =
			attenuation * _LightColor0.rgb * _Color.rgb
			* max(0.0, dot(normalDirection, lightDirection));

		float3 specularReflection;
		if (dot(normalDirection, lightDirection) < 0.0)
			// light source on the wrong side?
		{
			specularReflection = float3(0.0, 0.0, 0.0);
			// no specular reflection
		}
		else // light source on the right side
		{
			specularReflection = attenuation * _LightColor0.rgb
				* _SpecColor.rgb * pow(max(0.0, dot(
					reflect(-lightDirection, normalDirection),
					viewDirection)), _Shininess);
		}

		FragmentOutput o;
		o.color = float4(diffuseReflection
			+ specularReflection, 1.0);
		o.position = input.posWorld;
		o.normal = float4(input.normalDir, _Reflection);
		return o;
	}
		ENDCG
	}
	}
		Fallback "Specular"
}