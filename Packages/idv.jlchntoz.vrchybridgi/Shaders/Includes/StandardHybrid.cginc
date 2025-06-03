#ifndef STANDARD_HYBRID_INCLUDED
#define STANDARD_HYBRID_INCLUDED

#include "./HybridGI.cginc"
#include "UnityPBSLighting.cginc"

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

void LightingStandardHybrid_GI(SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi) {
    #if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
        gi = HybridGI(data, s.Occlusion, s.Normal);
    #else
        Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, lerp(unity_ColorSpaceDielectricSpec.rgb, s.Albedo, s.Metallic));
        gi = HybridGI(data, s.Occlusion, s.Normal, g);
    #endif
}

#endif