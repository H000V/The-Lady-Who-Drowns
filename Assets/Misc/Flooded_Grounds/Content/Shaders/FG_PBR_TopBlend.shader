Shader "Flooded_Grounds/PBR_TopBlend_URP"
{
    Properties
    {
        _MainTex ("Base Albedo (RGB)", 2D) = "white" {}
        _Spc ("Base Metalness(R) Smoothness(A)", 2D) = "black" {}
        _BumpMap ("Base Normal", 2D) = "bump" {}
        _AO ("Base AO", 2D) = "white" {}
        _layer1Tex ("Layer1 Albedo (RGB) Smoothness (A)", 2D) = "white" {}
        _layer1Metal ("Layer1 Metalness", Range(0,1)) = 0
        _layer1Norm ("Layer 1 Normal", 2D) = "bump" {}
        _layer1Breakup ("Layer1 Breakup (R)", 2D) = "white" {}
        _layer1BreakupAmnt ("Layer1 Breakup Amount", Range(0,1)) = 0.5
        _layer1Tiling ("Layer1 Tiling", Float) = 10
        _Power ("Layer1 Blend Amount", Float) = 1
        _Shift ("Layer1 Blend Height", Float) = 1
        _DetailBump ("Detail Normal", 2D) = "bump" {}
        _DetailInt ("DetailNormal Intensity", Range(0,1)) = 0.4
        _DetailTiling ("DetailNormal Tiling", Float) = 2
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline"="UniversalPipeline" }
        LOD 400

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Textures
            TEXTURE2D(_MainTex);      SAMPLER(sampler_MainTex);
            TEXTURE2D(_Spc);          SAMPLER(sampler_Spc);
            TEXTURE2D(_BumpMap);      SAMPLER(sampler_BumpMap);
            TEXTURE2D(_AO);           SAMPLER(sampler_AO);
            TEXTURE2D(_layer1Tex);    SAMPLER(sampler_layer1Tex);
            TEXTURE2D(_layer1Norm);   SAMPLER(sampler_layer1Norm);
            TEXTURE2D(_layer1Breakup);SAMPLER(sampler_layer1Breakup);
            TEXTURE2D(_DetailBump);   SAMPLER(sampler_DetailBump);

            // Properties
            float4 _MainTex_ST;
            float4 _layer1Tex_ST;
            float4 _DetailBump_ST;

            float _layer1Tiling;
            float _Power;
            float _Shift;
            float _layer1Metal;
            float _layer1BreakupAmnt;
            float _DetailInt;
            float _DetailTiling;

            // Vertex inputs
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionH : SV_POSITION;
                float2 uv        : TEXCOORD0;
                float3 posWS     : TEXCOORD1;
                float3 normalWS  : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
            };

            // Helper: unpack normal from normal map sample (RGBA->Tangent space normal)
            float3 UnpackNormalTS(float4 t)
            {
                float3 n;
                n.xy = t.xy * 2.0 - 1.0;
                n.z = sqrt(saturate(1.0 - dot(n.xy, n.xy)));
                return n;
            }

            Varyings vert(Attributes v)
            {
                Varyings o;

                // Object -> World
                float4 worldPos = mul(unity_ObjectToWorld, v.positionOS);
                o.posWS = worldPos.xyz;
                o.positionH = TransformWorldToHClip(o.posWS);

                // Build world-space TBN
                float3 normalWS = normalize(mul((float3x3)unity_ObjectToWorld, v.normalOS));
                float3 tangentWS = normalize(mul((float3x3)unity_ObjectToWorld, v.tangentOS.xyz));
                float3 bitangentWS = cross(normalWS, tangentWS) * v.tangentOS.w;

                o.normalWS = normalWS;
                o.tangentWS = tangentWS;
                o.bitangentWS = bitangentWS;

                o.uv = v.uv;

                return o;
            }

            // Simple Fresnel (Schlick) helper
            float3 FresnelSchlick(float3 F0, float cosTheta)
            {
                return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // UVs
                float2 uvBase = IN.uv;
                float2 uvLayer1 = IN.uv * _layer1Tiling;
                float2 uvDetail = IN.uv * _DetailTiling;

                // Sample textures (sRGB sampling handled by SRP)
                float4 baseCol = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvBase);
                float4 spc = SAMPLE_TEXTURE2D(_Spc, sampler_Spc, uvBase); // r=metal, a=smooth
                float3 ao = SAMPLE_TEXTURE2D(_AO, sampler_AO, uvBase).rgb;

                float4 layer1ColSample = SAMPLE_TEXTURE2D(_layer1Tex, sampler_layer1Tex, uvLayer1);
                float layer1Breakup = SAMPLE_TEXTURE2D(_layer1Breakup, sampler_layer1Breakup, uvLayer1).r;
                float4 layer1NormSample = SAMPLE_TEXTURE2D(_layer1Norm, sampler_layer1Norm, uvLayer1);

                float4 detailNormSample = SAMPLE_TEXTURE2D(_DetailBump, sampler_DetailBump, uvDetail);

                // Unpack normals (tangent space)
                float3 baseN_ts = UnpackNormalTS(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uvBase));
                float3 layerN_ts = UnpackNormalTS(layer1NormSample);
                float3 detailN_ts = UnpackNormalTS(detailNormSample);

                // Compose modNormal used for blend mask calculation (similar to original)
                // Note: original added only r/g channels of layer1norm slightly. We'll follow that behavior.
                float3 modNormal_ts = baseN_ts + float3(layerN_ts.r * 0.6, layerN_ts.g * 0.6, 0.0);

                // Convert modNormal_ts to world-space for dot with world normal.
                float3x3 TBN_world = float3x3(IN.tangentWS, IN.bitangentWS, IN.normalWS);
                float3 modNormalWS = normalize(mul(TBN_world, modNormal_ts));

                // Blend mask based on dot(worldNormal, up)
                float3 worldUp = float3(0.0, 1.0, 0.0);
                float blend = dot(normalize(IN.normalWS), worldUp); // use geometry normal to mimic WorldNormalVector(IN, modNormal)
                // incorporate influence of modNormal (soft influence)
                blend = saturate( (blend * _Power + _Shift) * lerp(1.0, layer1Breakup, _layer1BreakupAmnt) );
                blend = pow(blend, 3.0); // original pow(blend2,3)

                // Final normal: lerp base and layer normals in tangent space, then add detail normal intensity,
                // then transform to world space (TBN)
                float3 blendedN_ts = lerp(baseN_ts, layerN_ts, blend);
                blendedN_ts.xy += detailN_ts.xy * _DetailInt;
                blendedN_ts = normalize(blendedN_ts);

                float3 normalWS = normalize( mul(TBN_world, blendedN_ts) );

                // Albedo / metallic / smoothness / ao
                float3 albedo = lerp(baseCol.rgb, layer1ColSample.rgb, blend);
                float metallic = lerp(spc.r, _layer1Metal, blend);
                float smoothness = lerp(spc.a, layer1ColSample.a, blend);
                float aoFinal = ao.r; // using red channel; original used ao.rgb but occlusion should be scalar

                // PBR lighting (single main light + ambient via ambient probe)
                Light mainLight = GetMainLight();
                float3 L = normalize(-mainLight.direction); // URP light.direction points from world to light? GetMainLight convention used earlier
                float3 V = normalize(_WorldSpaceCameraPos - IN.posWS);
                float3 H = normalize(L + V);

                // Cook-Torrance simplified (no environment)
                float NdotL = saturate(dot(normalWS, L));
                float NdotV = saturate(dot(normalWS, V));
                float NdotH = saturate(dot(normalWS, H));
                float VdotH = saturate(dot(V, H));

                // base reflectance F0
                float3 F0 = lerp(0.04, albedo, metallic);
                float3 F = FresnelSchlick(F0, VdotH);

                // Normal Distribution (GGX)
                float alpha = max(0.001, (1.0 - smoothness) * (1.0 - smoothness) * 0.5 + 0.01);
                float alphaSqr = alpha * alpha;
                float denom = (NdotH * NdotH) * (alphaSqr - 1.0) + 1.0;
                float D = alphaSqr / (PI * denom * denom + 1e-6);

                // Geometry (Smith)
                float k = (smoothness + 1.0) * (smoothness + 1.0) / 8.0;
                float G_V = NdotV / (NdotV * (1.0 - k) + k + 1e-6);
                float G_L = NdotL / (NdotL * (1.0 - k) + k + 1e-6);
                float G = G_V * G_L;

                float3 specular = (D * G) * F / (4.0 * NdotV * NdotL + 1e-6);

                // Combine light contribution (main directional light)
                float3 radiance = mainLight.color;
                float3 diffuse = (1.0 - F) * albedo / PI;
                float3 Lo = (diffuse + specular) * radiance * NdotL;

                // Add ambient probe and AO
                float3 ambient = SampleSH(normalWS);
                float3 colorOut = Lo + ambient * aoFinal + albedo * 0.0; // no emissive in original shader

                // Gamma/linear handled by URP, return linear color
                return float4(colorOut, 1.0);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
