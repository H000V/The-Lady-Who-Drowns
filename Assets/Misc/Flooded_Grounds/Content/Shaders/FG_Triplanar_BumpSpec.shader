Shader "Flooded_Grounds/Triplanar_BumpSpec_URP"
{
    Properties
    {
        _TexScale ("Tex Scale", Range (0.1, 10.0))= 1.0
        _BlendPlateau ("BlendPlateau", Range (0.0, 1.0)) = 0.2       
        _MainTex ("Base 1 (RGB) Gloss(A)", 2D) = "white" {}
        _BumpMap1 ("NormalMap 1 (_Y_X)", 2D)  = "bump" {}   
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags { "Queue"="Geometry" "IgnoreProjector"="True" "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 400
        ZWrite On

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
            TEXTURE2D(_BumpMap1);       SAMPLER(sampler_BumpMap1);

            float _TexScale;
            float _BlendPlateau;
            float _Cutoff;
            float4 _MainTex_ST;

            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionH : SV_POSITION;
                float3 posWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                float4 worldPos4 = mul(unity_ObjectToWorld, v.vertex);
                o.posWS = worldPos4.xyz;
                o.positionH = TransformWorldToHClip(o.posWS);
                o.normalWS = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));
                o.uv = v.uv;
                return o;
            }

            // Helper to unpack a normal-like map if stored in special channels:
            // original shader used .wy for a packed normal form; keep that mapping available.
            static float2 SampleBumpWY(float2 uv)
            {
                float4 t = SAMPLE_TEXTURE2D(_BumpMap1, sampler_BumpMap1, uv);
                // return wy remapped from [0,1] to [-1,1]
                return t.wy * 2.0 - 1.0;
            }

            float3 BlendBumpToWorld(float3 worldNormal, float3 blended_bumpvec)
            {
                // Original shader added bump to a fixed vector — use world normal as base
                // then add blended bumpvec (which is in object/local axes relative to projections)
                // and renormalize. This is a cheap, stable approach that preserves original feel.
                float3 n = normalize(worldNormal + blended_bumpvec);
                return n;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // compute triplanar coordinates from world-space position
                float3 p = IN.posWS * _TexScale;

                float2 coordX = p.yz;
                float2 coordY = p.zx;
                float2 coordZ = p.xy;

                // blend weights -> abs(normal)
                float3 bw = abs(IN.normalWS);
                // tighten and plateau as original
                bw = bw - _BlendPlateau;
                bw = max(bw, 0);
                float sum = bw.x + bw.y + bw.z + 1e-6;
                bw /= sum;

                // Sample color projections
                float4 c1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, coordX);
                float4 c2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, coordY);
                float4 c3 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, coordZ);

                // sample bump maps using original .wy packing
                float2 bv1 = SampleBumpWY(coordX);
                float2 bv2 = SampleBumpWY(coordY);
                float2 bv3 = SampleBumpWY(coordZ);

                // reconstruct partial bump vectors similar to original mapping
                float3 bump1 = float3(0, bv1.x, bv1.y);
                float3 bump2 = float3(bv2.y, 0, bv2.x);
                float3 bump3 = float3(bv3.x, bv3.y, 0);

                // blend color and bump
                float4 blendedColor = c1 * bw.x + c2 * bw.y + c3 * bw.z;
                float3 blendedBump = bump1 * bw.x + bump2 * bw.y + bump3 * bw.z;

                // form final normal in world space (cheap approach mirroring original)
                float3 finalNormalWS = BlendBumpToWorld(IN.normalWS, blendedBump);

                // alpha test
                if (blendedColor.a <= _Cutoff) discard;

                // lighting: use main directional light + ambient probe
                Light mainLight = GetMainLight();
                float3 L = normalize(-mainLight.direction);
                float3 V = normalize(_WorldSpaceCameraPos - IN.posWS);
                float NdotL = saturate(dot(finalNormalWS, L));

                // simple Lambert diffuse + a tiny specular
                float3 albedo = blendedColor.rgb;
                float3 diffuse = albedo * NdotL * mainLight.color;

                // small Blinn spec to emulate shininess stored in alpha channel of _MainTex
                float smoothness = blendedColor.a; // original used alpha as gloss
                float3 H = normalize(L + V);
                float ndoth = saturate(dot(finalNormalWS, H));
                float spec = pow(ndoth, 16.0 + smoothness * 48.0) * smoothness;
                float3 specular = spec * mainLight.color;

                // ambient via SH probe
                float3 ambient = SampleSH(finalNormalWS);

                float3 outCol = diffuse + specular + ambient * 0.5;

                // return linear color (URP handles srgb conversions)
                return float4(outCol, 1.0);
            }

            ENDHLSL
        }
    }

    FallBack "Diffuse"
}
