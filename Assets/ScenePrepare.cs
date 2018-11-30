using UnityEngine;

[ExecuteInEditMode]
public class ScenePrepare : MonoBehaviour
{
    public RenderTexture color_texture;
    public RenderTexture normals_texture;
    public RenderTexture position_texture;

    RenderBuffer[] _mrt;

    void OnEnable()
    {
        _mrt = new RenderBuffer[3];
        color_texture = new RenderTexture(Screen.width, Screen.height, 24, RenderTextureFormat.ARGB32);
        color_texture.filterMode = FilterMode.Point;
        color_texture.useMipMap = false;
        position_texture = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat);
        position_texture.filterMode = FilterMode.Point;
        position_texture.useMipMap = false;
        normals_texture = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat);
        normals_texture.filterMode = FilterMode.Point;
        normals_texture.useMipMap = false;

        _mrt[0] = color_texture.colorBuffer;
        _mrt[1] = position_texture.colorBuffer;
        _mrt[2] = normals_texture.colorBuffer;

        GetComponent<Camera>().SetTargetBuffers(_mrt, color_texture.depthBuffer);
    }

    void Update()
    {

    }
}