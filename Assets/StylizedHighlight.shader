
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
		_ScaleU("ScaleU", range(0,1)) = 1
		_ScaleV("ScaleV", range(0,1)) = 1
		_ScaleK("ScaleK", float) = 0
		_SplitX("SplitX", Range(0,1)) = 0
		_SplitY("SplitY", Range(0,1)) = 0
		_SS("SD", Vector) = (1,1,1,1)
		_SquareN("SquareN", float) = 0
		_SquareSigma("SquareSigma", Range(0,1)) = 0
		

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
			float _ScaleK;
			float _ScaleU;
			float _ScaleV;
			float _SplitX;
			float _SplitY;
			float _SquareN;
			float _SquareSigma;

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

				//o.pos =UnityObjectToClipPos(mul(unity_WorldToObject, worldPos + worldBinormal*_TranslateV));
				
				// Compute the matrix that transform directions from tangent space to world space
				// Put the world position in w component for optimization
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

				o.uv.xy = v.texcoord;
				return o;
			}
			
			//Rotate H in worldcoord and return rotated H
			fixed3 opWorldHRot(float3 h)
			{
			}

			float3 opWorldHScale(float3 h, float scaleK, float2 scaleUV, float3 worldTangent, float3 worldBinormal)
			{
				//Scale U
				h = h - scaleK*dot(h, scaleUV.x * worldTangent) * (scaleUV.x * worldTangent);
				h = normalize(h);
				//Scale V
				h = h - scaleK*dot(h, scaleUV.y * worldBinormal) * (scaleUV.y * worldBinormal);
				h = normalize(h);
				return h;
			}

			float3 opWorldHTranslate(float3 h, float2 translateUV, float3 worldTangent, float3 worldBinormal)
			{
				h += (translateUV.x*worldTangent + translateUV.y*worldBinormal);
				h = normalize(h);
				return h;
			}

			float3 opWorldHSplit(float3 h, float2 gamma, float3 worldTangent, float3 worldBinormal)
			{

				float3 newH = h - gamma.x * sign(dot(h, worldTangent)) * worldTangent - gamma.y * sign(dot(h, worldBinormal)) * worldBinormal;
				newH = normalize(newH);
				return newH;
			}
			float3 opWorldHSquare(float3 h, int n, float sigma, float3 worldTangent, float3 worldBinormal)
			{
				float theta = min(acos(dot(normalize(h),normalize(worldTangent))), acos(dot(normalize(h),normalize(worldBinormal))));
				float sqrnorm = sin(pow(2*theta,n));
				h = h - sigma * sqrnorm * (dot(h, worldTangent) * worldTangent + dot(h, worldBinormal) * worldBinormal);
				float3 sqrH = normalize(h);
				return sqrH;
			}

			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col;

				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 worldNormal = normalize(float3(i.TtoW0[2],i.TtoW1[2],i.TtoW2[2]));
				fixed3 worldTangent = normalize(fixed3(i.TtoW0[0],i.TtoW1[0],i.TtoW2[0]));
				fixed3 worldBinormal = normalize(fixed3(i.TtoW0[1],i.TtoW1[1],i.TtoW2[1]));
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				fixed3 diffuse = _LightColor0.rgb * _Color * saturate(dot(worldNormal, worldLightDir));
				fixed3 worldViewDir = _WorldSpaceCameraPos - worldPos;
				
				fixed3 h = normalize((worldViewDir + worldLightDir)/2);
				h = opWorldHTranslate(h, float2(_TranslateU, _TranslateV), worldTangent, worldBinormal);
				h = opWorldHScale(h, _ScaleK, float2(_ScaleU, _ScaleV), worldTangent,worldBinormal);
				//h = opWorldHSplit(h, float2(_SplitX, _SplitY), worldTangent, worldBinormal);
				h = opWorldHSquare(h, _SquareN, _SquareSigma, worldTangent, worldBinormal);
				h = opWorldHSplit(h, float2(_SplitX, _SplitY), worldTangent, worldBinormal);
				//fixed3 rotatedWorldTangent = rotateAroundAxis(worldTangent, worldNormal, _SpecRot);
				//fixed3 rotatedWorldBinormal = rotateAroundAxis(worldBinormal, worldNormal, _SpecRot);
				fixed specularIntensity = pow(saturate(dot(worldNormal, h)),_Gloss);
				specularIntensity = tex2D(_SpecularRampMap, fixed2(specularIntensity, specularIntensity)).x;
				fixed3 specular = _SpecK * _Specular *  _LightColor0.rgb * specularIntensity;
				col = fixed4(ambient + specular + diffuse,1);
				
				//col = fixed4(worldBinormal, 1);
				//col = fixed4(i.uv.xy,0,1);
				//col = fixed4(worldNormal, 1);
				//col = pow(fixed4(h, 1),3);
				//col = fixed4(h,1);
				
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
