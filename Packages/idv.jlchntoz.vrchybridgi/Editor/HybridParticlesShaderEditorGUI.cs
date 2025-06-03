using System;
using UnityEngine;
using UnityEditor;

public class HybridParticlesShaderEditorGUI : ShaderGUI {
    // Since the StandardParticlesShaderGUI is not public, we need to use reflection to access it.
    static readonly Type baseType = Type.GetType("UnityEditor.StandardParticlesShaderGUI, UnityEditor", false);
    readonly ShaderGUI baseInstance;
    readonly MaterialProperty[] filteredProperties = new MaterialProperty[2];

    public HybridParticlesShaderEditorGUI() {
        if (baseType != null) baseInstance = (ShaderGUI)Activator.CreateInstance(baseType);
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties) {
        baseInstance?.OnGUI(materialEditor, properties);
        foreach (var p in properties) {
            if (p == null) continue;
            switch (p.name) {
                case "_LTCGI": filteredProperties[0] = p; break;
                case "_VRCLV": filteredProperties[1] = p; break;
            }
        }
        materialEditor.PropertiesDefaultGUI(filteredProperties);
    }

    public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader) =>
        baseInstance?.AssignNewShaderToMaterial(material, oldShader, newShader);


    public override void ValidateMaterial(Material material) =>
        baseInstance?.ValidateMaterial(material);

    public override void OnClosed(Material material) =>
        baseInstance?.OnClosed(material);

    public override void OnMaterialInteractivePreviewGUI(MaterialEditor materialEditor, Rect r, GUIStyle background) =>
        baseInstance?.OnMaterialInteractivePreviewGUI(materialEditor, r, background);

    public override void OnMaterialPreviewGUI(MaterialEditor materialEditor, Rect r, GUIStyle background) =>
        baseInstance?.OnMaterialPreviewGUI(materialEditor, r, background);

    public override void OnMaterialPreviewSettingsGUI(MaterialEditor materialEditor) =>
        baseInstance?.OnMaterialPreviewSettingsGUI(materialEditor);
}
