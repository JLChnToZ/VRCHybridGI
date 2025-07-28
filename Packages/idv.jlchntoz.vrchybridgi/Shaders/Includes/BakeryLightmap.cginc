#ifndef BAKERY_LM_INCLUDED
#define BAKERY_LM_INCLUDED

#if defined(_BAKERY_RNM) || defined(_BAKERY_SH)
    UNITY_DECLARE_TEX2D(_RNM0);
    UNITY_DECLARE_TEX2D(_RNM1);
    UNITY_DECLARE_TEX2D(_RNM2);
#endif

inline float3 SampleBakeryRNM(float2 uv, float3 tangent) {
    #if defined(_BAKERY_RNM)
        const float RSQRT2 = 0.7071067811865476; // 1 / sqrt(2)
        const float RSQRT3 = 0.5773502691896257; // 1 / sqrt(3)
        const float NRSQRT6 = -0.4082482904638631; // -1 / sqrt(6)
        const float SQRT2_3 = 0.816496580927726; // sqrt(2/3)
        const float3x3 basis = float3x3(
            SQRT2_3, 0, RSQRT3,
            NRSQRT6, RSQRT2, RSQRT3,
            NRSQRT6, -RSQRT2, RSQRT3
        );

        const float3x3 rnm = float3x3(
            DecodeLightmap(UNITY_SAMPLE_TEX2D(_RNM0, uv)),
            DecodeLightmap(UNITY_SAMPLE_TEX2D(_RNM1, uv)),
            DecodeLightmap(UNITY_SAMPLE_TEX2D(_RNM2, uv))
        );

        return mul(saturate(mul(basis, tangent)), rnm);
    #else
        return 0;
    #endif
}

// We need this since GI functions doesn't have local space tangent input
inline float3 SampleBakeryRNM(float2 uv) {
    return SampleBakeryRNM(uv, float3(1, 0, 0));
}

inline void SampleBakerySH(float2 uv, float3 L0, out float3 L1x, out float3 L1y, out float3 L1z) {
    #if defined(_BAKERY_SH)
        float3x3 nL1 = float3x3(
            UNITY_SAMPLE_TEX2D(_RNM0, uv).xyz,
            UNITY_SAMPLE_TEX2D(_RNM1, uv).xyz,
            UNITY_SAMPLE_TEX2D(_RNM2, uv).xyz
        );
    #elif defined(_BAKERY_MONOSH)
        float3 nL1 = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, uv).xyz;
    #else
        float3 nL1 = 0;
    #endif
    nL1 = mad(nL1, 4, -2);
    L1x = nL1[0] * L0;
    L1y = nL1[1] * L0;
    L1z = nL1[2] * L0;
}

// Adopted and modified from Filamented
inline float SHEvaluateDiffuseL1Geomerics(float4 L, float3 n) {
    float R0 = max(L.w, 0);
    float3 R1 = 0.5 * L.xyz;
    float lenR1 = length(R1);
    float q = saturate(mad(dot(R1 / lenR1, n), 0.5, 0.5));
    float lenR1divR0 = lenR1 / R0;
    float p = mad(lenR1divR0, 2, 1);
    float a = (1 - lenR1divR0) / (1 + lenR1divR0);
    return R0 * (a + (1 - a) * (p + 1) * pow(q, p));
}

inline float3 ShadeBakerySH(float3 L0, float3 L1x, float3 L1y, float3 L1z, float3 normalWorld) {
    float4x4 L = float4x4(L1x, 0, L1y, 0, L1z, 0, L0, 1);
    float3 sh = mul(float4(normalWorld, 1), L).xyz;
    #ifdef _BAKERY_SHNONLINEAR
        L._44 = 0;
        const float lumaSH = SHEvaluateDiffuseL1Geomerics(mul(L, (1).xxxx), normalWorld);
        const float regularLumaSH = dot(sh, 1);
        sh *= lerp(1, lumaSH / regularLumaSH, saturate(regularLumaSH * 16));
    #endif
    return sh;
}

#endif