// This is the demo shader on how to use the "Hybrid GI".
Shader "Custom/HybridSurfaceSample" {
    Properties {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        // Add following properties to make these features toggleable
        [Toggle(_LTCGI)] _LTCGI ("Use LTCGI", Int) = 0
        [Toggle(_VRCLV)] _VRCLV ("Use VRC Light Volumes", Int) = 0
        [KeywordEnum(None, SH, RNM, MonoSH)] _Bakery ("Directional Lightmap Mode", Int) = 0
        [Toggle(_BAKERY_SHNONLINEAR)] _SHNonLinear ("Non-Linear SH", Int) = 0
    }
    SubShader {
        Tags {
            "RenderType" = "Opaque"
            "LTCGI" = "_LTCGI" // This tag is required for LTCGI support
        }
        LOD 200

        CGPROGRAM
        // Use "StandardHybrid" instead of "Standard" to enable hybrid lighting model.
        // If you were using "StandardSpecular", you can replace it to "StandardSpecularHybrid".
        #pragma surface surf StandardHybrid fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        // It is required to add this file.
        #include "Packages/idv.jlchntoz.vrchybridgi/Shaders/Includes/StandardHybrid.cginc"

        // The rest are the same as normal surface shaders.

        sampler2D _MainTex;

        struct Input {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
        // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf(Input IN, inout SurfaceOutputStandard o) {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
