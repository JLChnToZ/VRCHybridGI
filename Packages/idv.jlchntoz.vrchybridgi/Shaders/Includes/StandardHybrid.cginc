#ifndef STANDARD_HYBRID_INCLUDED
#define STANDARD_HYBRID_INCLUDED

/**
    Add following to your shader properties to toggle HybridGI features:
    [Toggle(_LTCGI)] _LTCGI ("Use LTCGI", Int) = 0
    [Toggle(_VRCLV)] _VRCLV ("Use VRC Light Volumes", Int) = 0
    [KeywordEnum(None, SH, RNM, MonoSH)] _Bakery ("Directional Lightmap Mode", Int) = 0
    [Toggle(_BAKERY_SHNONLINEAR)] _SHNonLinear ("Non-Linear SH", Int) = 0
**/

#ifndef SKIP_HYBRID_GI_SHADER_FEATURES
    #pragma shader_feature_local_fragment __ _LTCGI
    #pragma shader_feature_local_fragment __ _VRCLV

    #ifdef LIGHTMAP_ON
        #pragma shader_feature_local_fragment __ _BAKERY_SH _BAKERY_MONOSH _BAKERY_RNM
        #pragma shader_feature_local_fragment __ _BAKERY_SHNONLINEAR
    #endif
#endif

#include "./HybridGI.cginc"
#include "UnityPBSLighting.cginc"

#define SurfaceOutputStandardHybrid SurfaceOutputStandard

inline half4 LightingStandardHybrid(SurfaceOutputStandard s, half3 viewDir, UnityGI gi) {
    // Just inherit the original LightingStandard function
    return LightingStandard(s, viewDir, gi);
}

inline half4 LightingStandardHybrid_Deferred(
    SurfaceOutputStandard s, float3 viewDir, UnityGI gi,
    out half4 b0, out half4 b1, out half4 b2
) {
    // Just inherit the original LightingStandard_Deferred function
    return LightingStandard_Deferred(s, viewDir, gi, b0, b1, b2);
}

inline void LightingStandardHybrid_GI(SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi) {
    #if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
        gi = HybridGI(data, s.Occlusion, s.Normal);
    #else
        half3 specular = lerp(unity_ColorSpaceDielectricSpec.rgb, s.Albedo, s.Metallic);
        Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, specular);
        gi = HybridGI(data, s.Occlusion, s.Normal, g);
    #endif
}

#define SurfaceOutputStandardSpecularHybrid SurfaceOutputStandardSpecular

inline half4 LightingStandardSpecularHybrid(SurfaceOutputStandardSpecular s, half3 viewDir, UnityGI gi) {
    // Just inherit the original LightingStandardSpecular function
    return LightingStandardSpecular(s, viewDir, gi);
}

inline half4 LightingStandardSpecularHybrid_Deferred(
    SurfaceOutputStandardSpecular s, float3 viewDir, UnityGI gi,
    out half4 b0, out half4 b1, out half4 b2
) {
    // Just inherit the original LightingStandardSpecular_Deferred function
    return LightingStandardSpecular_Deferred(s, viewDir, gi, b0, b1, b2);
}

inline void LightingStandardSpecularHybrid_GI(SurfaceOutputStandardSpecular s, UnityGIInput data, inout UnityGI gi) {
    #if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
        gi = HybridGI(data, s.Occlusion, s.Normal);
    #else
        Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, s.Specular);
        gi = HybridGI(data, s.Occlusion, s.Normal, g);
    #endif
}

#endif