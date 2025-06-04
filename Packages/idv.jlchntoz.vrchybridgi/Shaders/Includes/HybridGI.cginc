#ifndef HYBRID_GI_INCLUDED
#define HYBRID_GI_INCLUDED

#include "UnityCG.cginc"
#include "UnityImageBasedLighting.cginc"

#ifdef _LTCGI
#include "Packages/at.pimaker.ltcgi/Shaders/LTCGI_structs.cginc"
#define LTCGI_V2_CUSTOM_INPUT UnityIndirect
#define LTCGI_V2_DIFFUSE_CALLBACK(l, o) l.diffuse += o.color * o.intensity
#define LTCGI_V2_SPECULAR_CALLBACK(l, o) l.specular += o.color * o.intensity
#include "Packages/at.pimaker.ltcgi/Shaders/LTCGI.cginc"
#endif

#ifdef _VRCLV
#include "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc"
#endif

#ifdef _BAKERY_SH
UNITY_DECLARE_TEX2D(_RNM0);
UNITY_DECLARE_TEX2D(_RNM1);
UNITY_DECLARE_TEX2D(_RNM2);
#endif

// Adopted from Filamented
float shEvaluateDiffuseL1Geomerics(float L0, float3 L1, float3 n) {
    float R0 = max(L0, 0);
    float3 R1 = 0.5 * L1;
    float lenR1 = length(R1);
    float q = saturate(mad(dot(R1 / lenR1, n), 0.5, 0.5));
    float lenR1divR0 = lenR1 / R0;
    float p = mad(lenR1divR0, 2.0, 1.0);
    float a = (1.0 - lenR1divR0) / (1.0 + lenR1divR0);
    return R0 * (a + (1.0 - a) * (p + 1.0) * pow(q, p));
}

// Modified from UnityGI_Base
inline UnityGI HybridGI(UnityGIInput data, half occlusion, half3 normalWorld) {
    UnityGI gi;
    ResetUnityGI(gi);

    // Base pass with Lightmap support is responsible for handling ShadowMask / blending here for performance reason
    #ifdef HANDLE_SHADOWS_BLENDING_IN_GI
        half bakedAtten = UnitySampleBakedOcclusion(data.lightmapUV.xy, data.worldPos);
        float zDist = dot(_WorldSpaceCameraPos - data.worldPos, UNITY_MATRIX_V[2].xyz);
        float fadeDist = UnityComputeShadowFadeDistance(data.worldPos, zDist);
        data.atten = UnityMixRealtimeAndBakedShadows(data.atten, bakedAtten, UnityComputeShadowFade(fadeDist));
    #endif

    gi.light = data.light;
    gi.light.color *= data.atten;

    #ifdef _VRCLV
        float3 L0, L1r, L1g, L1b;
        #ifdef LIGHTMAP_ON
            LightVolumeAdditiveSH(data.worldPos, L0, L1r, L1g, L1b);
        #else
            LightVolumeSH(data.worldPos, L0, L1r, L1g, L1b);
        #endif
        gi.indirect.diffuse = LightVolumeEvaluate(normalWorld, L0, L1r, L1g, L1b);
    #elif UNITY_SHOULD_SAMPLE_SH
        gi.indirect.diffuse = ShadeSHPerPixel(normalWorld, data.ambient, data.worldPos);
    #endif

    #ifdef LIGHTMAP_ON
        const half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, data.lightmapUV.xy);
        half3 bakedColor = DecodeLightmap(bakedColorTex);

        #if defined(_BAKERY_SH) || defined(_BAKERY_MONOSH)
            #if defined(_BAKERY_SH)
                const float3 nL1x = mad(UNITY_SAMPLE_TEX2D(_RNM0, data.lightmapUV.xy), 4, -2);
                const float3 nL1y = mad(UNITY_SAMPLE_TEX2D(_RNM1, data.lightmapUV.xy), 4, -2);
                const float3 nL1z = mad(UNITY_SAMPLE_TEX2D(_RNM2, data.lightmapUV.xy), 4, -2);
                const float3 L1x = nL1x * bakedColor;
                const float3 L1y = nL1y * bakedColor;
                const float3 L1z = nL1z * bakedColor;
            #elif defined(_BAKERY_MONOSH)
                const float3 nL1 = mad(UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, data.lightmapUV.xy).xyz, 4, -2);
                const float3 L1x = nL1.x * bakedColor;
                const float3 L1y = nL1.y * bakedColor;
                const float3 L1z = nL1.z * bakedColor;
            #endif
            float3 sh = bakedColor + normalWorld.x * L1x + normalWorld.y * L1y + normalWorld.z * L1z;
            #if _BAKERY_SHNONLINEAR
                const float lumaSH = shEvaluateDiffuseL1Geomerics(dot(bakedColor, 1), float3(dot(L1x, 1), dot(L1y, 1), dot(L1z, 1)), normalWorld);
                const float regularLumaSH = dot(sh, 1);
                sh *= lerp(1, lumaSH / regularLumaSH, saturate(regularLumaSH * 16));
            #endif
            gi.indirect.diffuse += max(sh, 0);
        #else
            #ifdef DIRLIGHTMAP_COMBINED
                const fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, data.lightmapUV.xy);
                bakedColor = DecodeDirectionalLightmap(bakedColor, bakedDirTex, normalWorld);
            #endif
            gi.indirect.diffuse += bakedColor;
        #endif
        #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
            ResetUnityLight(gi.light);
            gi.indirect.diffuse = SubtractMainLightWithRealtimeAttenuationFromLightmap(gi.indirect.diffuse, data.atten, bakedColorTex, normalWorld);
        #endif
    #endif

    #ifdef DYNAMICLIGHTMAP_ON
        fixed4 realtimeColorTex = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, data.lightmapUV.zw);
        half3 realtimeColor = DecodeRealtimeLightmap(realtimeColorTex);

        #ifdef DIRLIGHTMAP_COMBINED
            half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, data.lightmapUV.zw);
            realtimeColor = DecodeDirectionalLightmap(realtimeColor, realtimeDirTex, normalWorld);
        #endif
        gi.indirect.diffuse += realtimeColor;
    #endif

    gi.indirect.diffuse *= occlusion;
    return gi;
}

inline UnityGI HybridGI(UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData gloss) {
    UnityGI gi = HybridGI(data, occlusion, normalWorld);
    gi.indirect.specular = UnityGI_IndirectSpecular(data, occlusion, gloss);
    #ifdef _LTCGI
        float3 viewDir = normalize(_WorldSpaceCameraPos - data.worldPos);
        LTCGI_Contribution(gi.indirect, data.worldPos, normalWorld, viewDir, gloss.roughness, data.lightmapUV.xy);
    #endif
    return gi;
}
#endif