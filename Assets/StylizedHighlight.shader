// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Unlit/StylizedHighlight"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color",Color) = (1,1,1,1)
		_Specular ("Specular", Color) = (1,1,1,1)
		_Gloss ("Gloss",float) = 1
		_TranslateU("TranslateU", float) = 0
		_TranslateV("TranslateV", float) = 0
		_SpecularRampMap("_SpecularRampMap",2D) = "black"{}
		_SpecRot("Specular Rotate theta", float) = 0
		_SpecK("SpecK", float) = 1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Tags { "LightMode"="ForwardBase" }
			CGPROGRAM
			#pragma multi_compile_fwdbase
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float4 TtoW0 : TEXCOORD1;  
				float4 TtoW1 : TEXCOORD2;  
				float4 TtoW2 : TEXCOORD3; 
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			float _Gloss;
			fixed4 _Specular;
			float _TranslateU;
			float _TranslateV;
			sampler2D _SpecularRampMap;
			float _SpecRot;
			float _SpecK;
			float magnitude(float3 v)
			{
				return sqrt(v.x*v.x+v.y*v.y+v.z*v.z);
			}
			float3 rotateAroundAxis(float3 v, float3 axis, float rad)
			{
				float3 proj = dot(axis,v)/magnitude(axis);
				float3 verti = v - proj;
				float x = v.x * cos(rad) + (axis.y * v.z - axis.z * v.y) * sin(rad) + axis.x * (axis.x * v.x + axis.y * v.y + axis.z * v.z)*(1 - cos(rad));
				float y = v.y * cos(rad) + (axis.x * v.z - axis.z * v.x) * sin(rad) + axis.y * (axis.x * v.x + axis.y * v.y + axis.z * v.z)*(1 - cos(rad));
				float z = v.z * cos(rad) + (axis.x * v.y - axis.y * v.x) * sin(rad) + axis.z * (axis.x * v.x + axis.y * v.y + axis.z * v.z)*(1 - cos(rad));
				return float3(x,y,z);
			}
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);	
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
				// Compute the matrix that transform directions from tangent space to world space
				// Put the world position in w component for optimization
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col;

				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 worldNormal = normalize(float3(i.TtoW0[2],i.TtoW1[2],i.TtoW2[2]));
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				fixed3 diffuse = _LightColor0.rgb * _Color * saturate(dot(worldNormal, worldLightDir));
				fixed3 worldViewDir = _WorldSpaceCameraPos - worldPos;
				fixed3 h = normalize((worldViewDir + worldLightDir)/2);
				fixed3 worldTangent = fixed3(i.TtoW0[0],i.TtoW1[0],i.TtoW2[0]);
				fixed3 worldBinormal = fixed3(i.TtoW0[1],i.TtoW1[1],i.TtoW2[1]);
				fixed2 translate = fixed2(_TranslateU, _TranslateV);
				fixed3 rotatedWorldTangent = rotateAroundAxis(worldTangent, worldNormal, _SpecRot);
				fixed3 rotatedWorldBinormal = rotateAroundAxis(worldBinormal, worldNormal, _SpecRot);
				h += (_TranslateU*rotatedWorldTangent + _TranslateV*rotatedWorldBinormal);
				h = normalize(h);
				fixed specularIntensity = pow(saturate(dot(worldNormal, h)),_Gloss);
				specularIntensity = tex2D(_SpecularRampMap, fixed2(specularIntensity, specularIntensity)).x;
				fixed3 specular = _SpecK * _Specular *  _LightColor0.rgb * specularIntensity;
				col = fixed4(ambient + specular + diffuse,1);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
