Shader "Flooded_Grounds/PBR_Water_URP"
{
    Properties
    {
        _Color("Tint", Color) = (0.2,0.4,1,1)
        _MainTex("Base Map", 2D) = "white" {}
        _BumpMap("Normal Map A", 2D) = "bump" {}
        _BumpMap2("Normal Map B", 2D) = "bump" {}
        _ParallaxMap("Height Map", 2D) = "black" {}
        _ScrollSpeed("Scroll Speed", Float) = 0.2
        _WaveFreq("Wave Frequency", Float) = 20
        _WaveHeight("Wave Height", Float) = 0.1
        _BumpLerp("Normal Blend", Range(0,1)) = 0.5
        _Smoothness("Smoothness", Range(0,1)) = 0.9
        _Emis("Emission", Range(0,1)) = 0.1
        _Parallax("Parallax Height", Range(0.005,0.08)) = 0.02
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_MainTex);      SAMPLER(sampler_MainTex);
            TEXTURE2D(_BumpMap);      SAMPLER(sampler_BumpMap);
            TEXTURE2D(_BumpMap2);     SAMPLER(sampler_BumpMap2);
            TEXTURE2D(_ParallaxMap);  SAMPLER(sampler_ParallaxMap);

            float4 _Color;
            float _ScrollSpeed;
            float _WaveFreq;
            float _WaveHeight;
            float _BumpLerp;
            float _Smoothness;
            float _Emis;
            float _Parallax;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 posHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float3 posWS : TEXCOORD5;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;

                float3 pos = v.positionOS.xyz;
                float phase = _Time.y * _WaveFreq;
                float offset = (pos.x + pos.z * 2.0) * 8.0;
                pos.y += sin(phase + offset) * _WaveHeight;

                float4 worldPos = mul(unity_ObjectToWorld, float4(pos,1));
                o.posHCS = TransformWorldToHClip(worldPos.xyz);
                o.posWS  = worldPos.xyz;

                o.uv = v.uv;
                o.uv2 = v.uv2;

                VertexNormalInputs n = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS    = n.normalWS;
                o.tangentWS   = n.tangentWS;
                o.bitangentWS = n.bitangentWS;

                return o;
            }

            float3 UnpackN(float4 t)
            {
                float3 n;
                n.xy = t.xy * 2 - 1;
                n.z  = sqrt(saturate(1 - dot(n.xy,n.xy)));
                return n;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float2 scroll1 = float2(_ScrollSpeed * _Time.y, (_ScrollSpeed * _Time.y) * 0.5);
                float2 scroll2 = float2((1 - _ScrollSpeed) * _Time.y, (1 - _ScrollSpeed * _Time.y) * 0.5);

                float2 uvPar = i.uv + scroll1 * 0.15;
                float h = SAMPLE_TEXTURE2D(_ParallaxMap, sampler_ParallaxMap, uvPar).r;
                float2 par = clamp((h - 0.5) * _Parallax, -0.05, 0.05).xx;

                float2 uvA = i.uv + par + scroll1;
                float2 uvB = i.uv + par + scroll2;

                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvA).rgb * _Color.rgb;

                float3 nA = UnpackN(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uvA));
                float3 nB = UnpackN(SAMPLE_TEXTURE2D(_BumpMap2, sampler_BumpMap2, i.uv2));
                float3 nTS = normalize(lerp(nA, nB, _BumpLerp));

                float3x3 TBN = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                float3 normalWS = normalize(mul(TBN, nTS));

                Light light = GetMainLight();

                float3 L = normalize(-light.direction);
                float3 V = normalize(_WorldSpaceCameraPos - i.posWS);
                float3 H = normalize(L + V);

                float diff = saturate(dot(normalWS, L));
                float spec = pow(saturate(dot(normalWS, H)), 64 * _Smoothness);

                float3 color =
                    albedo * diff * light.color +
                    spec * light.color +
                    albedo * _Emis;

                return float4(color, 1);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
