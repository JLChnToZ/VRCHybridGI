// Modified from Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
Shader "Particles/GI Lit" {
    Properties {
        _MainTex("Albedo", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _DistortionStrength("Strength", Float) = 1.0
        _DistortionBlend("Blend", Range(0.0, 1.0)) = 0.5

        _SoftParticlesNearFadeDistance("Soft Particles Near Fade", Float) = 0.0
        _SoftParticlesFarFadeDistance("Soft Particles Far Fade", Float) = 1.0
        _CameraNearFadeDistance("Camera Near Fade", Float) = 1.0
        _CameraFarFadeDistance("Camera Far Fade", Float) = 2.0

        [Toggle(_VRCLV)] _VRCLV ("Use VRC Light Volumes", Int) = 0

        // Hidden properties
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _ColorMode ("__colormode", Float) = 0.0
        [HideInInspector] _FlipbookMode ("__flipbookmode", Float) = 0.0
        [HideInInspector] _LightingEnabled ("__lightingenabled", Float) = 0.0
        [HideInInspector] _DistortionEnabled ("__distortionenabled", Float) = 0.0
        [HideInInspector] _EmissionEnabled ("__emissionenabled", Float) = 0.0
        [HideInInspector] _BlendOp ("__blendop", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
        [HideInInspector] _Cull ("__cull", Float) = 2.0
        [HideInInspector] _SoftParticlesEnabled ("__softparticlesenabled", Float) = 0.0
        [HideInInspector] _CameraFadingEnabled ("__camerafadingenabled", Float) = 0.0
        [HideInInspector] _SoftParticleFadeParams ("__softparticlefadeparams", Vector) = (0,0,0,0)
        [HideInInspector] _CameraFadeParams ("__camerafadeparams", Vector) = (0,0,0,0)
        [HideInInspector] _ColorAddSubDiff ("__coloraddsubdiff", Vector) = (0,0,0,0)
        [HideInInspector] _DistortionStrengthScaled ("__distortionstrengthscaled", Float) = 0.0
    }

    Category {
        SubShader {
            Tags {
                "RenderType" = "Opaque"
                "IgnoreProjector" = "True"
                "PreviewType" = "Plane"
                "PerformanceChecks" = "False"
            }

            BlendOp [_BlendOp]
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]
            ColorMask RGB

            GrabPass {
                Tags { "LightMode" = "Always" }
                "_GrabTexture"
            }

            UsePass "Particles/Standard Unlit/SHADOWCASTER"
            UsePass "Particles/Standard Unlit/SCENESELECTIONPASS"
            UsePass "Particles/Standard Unlit/SCENEPICKINGPASS"

            Pass {
                Tags { "LightMode" = "ForwardBase" }

                CGPROGRAM
                #pragma multi_compile __ SOFTPARTICLES_ON
                #pragma multi_compile_fog
                #pragma target 2.5

                #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON _ALPHAMODULATE_ON
                #pragma shader_feature_local _ _COLOROVERLAY_ON _COLORCOLOR_ON _COLORADDSUBDIFF_ON
                #pragma shader_feature_local _NORMALMAP
                #pragma shader_feature _EMISSION
                #pragma shader_feature_local _FADING_ON
                #pragma shader_feature_local _REQUIRE_UV2
                #pragma shader_feature_local EFFECT_BUMP
                #pragma shader_feature_local _VRCLV

                #pragma vertex vertCustom
                #pragma fragment fragCustom
                #pragma multi_compile_instancing
                #pragma instancing_options procedural:vertInstancingSetup

                #ifdef _VRCLV
                #include "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc"
                #endif

                #include "UnityStandardParticles.cginc"

                struct VertexOutputCustom {
                    float4 vertex : SV_POSITION;
                    float4 color : COLOR;
                    UNITY_FOG_COORDS(0)
                    float2 texcoord : TEXCOORD1;
                    #if defined(_FLIPBOOK_BLENDING)
                        float3 texcoord2AndBlend : TEXCOORD2;
                    #endif
                    #if defined(SOFTPARTICLES_ON) || defined(_FADING_ON)
                        float4 projectedPosition : TEXCOORD3;
                    #endif
                    #if _DISTORTION_ON
                        float4 grabPassPosition : TEXCOORD4;
                    #endif
                    #if _VRCLV
                        float4 worldPos : TEXCOORD5;
                    #endif
                    UNITY_VERTEX_OUTPUT_STEREO
                };

                fixed4 readTextureFromCustom(sampler2D tex, VertexOutputCustom IN) {
                    fixed4 color = tex2D(tex, IN.texcoord);
                    #ifdef _FLIPBOOK_BLENDING
                        fixed4 color2 = tex2D(tex, IN.texcoord2AndBlend.xy);
                        color = lerp(color, color2, IN.texcoord2AndBlend.z);
                    #endif
                    return color;
                }

                void vertCustom(appdata_particles v, out VertexOutputCustom o) {
                    UNITY_SETUP_INSTANCE_ID(v);
                    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                    float4 clipPosition = UnityObjectToClipPos(v.vertex);
                    o.vertex = clipPosition;
                    o.color = v.color;

                    vertColor(o.color);
                    vertTexcoord(v, o);
                    vertFading(o);
                    vertDistortion(o);

                    #if _VRCLV
                        o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                    #endif

                    UNITY_TRANSFER_FOG(o, o.vertex);
                }

                half4 fragCustom(VertexOutputCustom IN) : SV_Target {
                    half4 albedo = readTextureFromCustom(_MainTex, IN);
                    albedo *= _Color;

                    #ifdef _VRCLV
                        float3 L0, L1r, L1g, L1b;
                        LightVolumeSH(IN.worldPos, L0, L1r, L1g, L1b);
                        albedo.rgb *= L0;
                    #else
                        albedo.rgb *= float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
                    #endif

                    fragColorMode(IN);
                    fragSoftParticles(IN);
                    fragCameraFading(IN);

                    #if defined(_NORMALMAP)
                        float3 normal = normalize(UnpackScaleNormal(readTextureFromCustom(_BumpMap, IN), _BumpScale));
                    #else
                        float3 normal = float3(0,0,1);
                    #endif

                    #if defined(_EMISSION)
                        half3 emission = readTextureFromCustom(_EmissionMap, IN).rgb;
                    #else
                        half3 emission = 0;
                    #endif

                    fragDistortion(IN);

                    half4 result = albedo;

                    #if defined(_ALPHAMODULATE_ON)
                        result.rgb = lerp(half3(1.0, 1.0, 1.0), albedo.rgb, albedo.a);
                    #endif

                    result.rgb += emission * _EmissionColor * cameraFade * softParticlesFade;

                    #if !defined(_ALPHABLEND_ON) && !defined(_ALPHAPREMULTIPLY_ON) && !defined(_ALPHAOVERLAY_ON)
                        result.a = 1;
                    #endif

                    #if defined(_ALPHATEST_ON)
                    clip(albedo.a - _Cutoff + 0.0001);
                    #endif

                    UNITY_APPLY_FOG_COLOR(IN.fogCoord, result, fixed4(0,0,0,0));
                    return result;
                }
                ENDCG
            }
        }
    }

    Fallback "Particles/Standard Unlit"
    CustomEditor "UnlitParticlesShaderEditorGUI"
}