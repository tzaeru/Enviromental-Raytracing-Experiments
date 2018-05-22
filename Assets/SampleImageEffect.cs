using UnityEngine;
using System.Collections;

public class SampleImageEffect : MonoBehaviour
{
    public Shader m_Shader = null;
    private Material m_Material;
    public Light light;

    void Start()
    {
        GetComponent<Camera>().depthTextureMode = DepthTextureMode.Depth;

        if (m_Shader)
        {
            m_Material = new Material(m_Shader);
            m_Material.name = "ImageEffectMaterial";
            m_Material.hideFlags = HideFlags.HideAndDontSave;
        }

        else
        {
            Debug.LogWarning(gameObject.name + ": Shader is not assigned. Disabling image effect.", this.gameObject);
            enabled = false;
        }

        int totalVertexes = 0;
        int totalTriangles = 0;
        

        int object_i = 0;
        const int max_triangles_per_object = 2048;
        const int max_objects = 9;
        float[] triangles_per_object = new float[max_objects];
        Matrix4x4[] transform_matrices = new Matrix4x4[max_objects];
        Vector4[] transform_positions = new Vector4[max_objects];

        Texture2DArray triangles_tex = new Texture2DArray(max_triangles_per_object, 3, max_objects, TextureFormat.RGBAFloat, false, true);
        m_Material.SetTexture("_TrianglesTex", triangles_tex);

        foreach (MeshFilter mf in FindObjectsOfType(typeof(MeshFilter)))
        {
            print("Name: " + mf.name);
            print("Position: " + mf.transform.position);
            print("Transform Matrix: " + mf.transform.localToWorldMatrix);
            print("Vertices: " + mf.sharedMesh.vertexCount);
            print("Triangles: " + mf.sharedMesh.triangles.Length / 3);

            Color[] _triangles = new Color[max_triangles_per_object * 3];
            for (int i = 0; i < mf.sharedMesh.triangles.Length/3; i++)
            {
                _triangles[i] = new Color(mf.sharedMesh.vertices[mf.sharedMesh.triangles[i*3]].x,
                    mf.sharedMesh.vertices[mf.sharedMesh.triangles[i*3]].y,
                    mf.sharedMesh.vertices[mf.sharedMesh.triangles[i*3]].z,
                    1.0f);
                _triangles[i + max_triangles_per_object] = new Color(mf.sharedMesh.vertices[mf.sharedMesh.triangles[i*3+1]].x,
                    mf.sharedMesh.vertices[mf.sharedMesh.triangles[i*3+1]].y,
                    mf.sharedMesh.vertices[mf.sharedMesh.triangles[i*3+1]].z,
                    1.0f);
                _triangles[i + max_triangles_per_object*2] = new Color(mf.sharedMesh.vertices[mf.sharedMesh.triangles[i*3+2]].x,
                    mf.sharedMesh.vertices[mf.sharedMesh.triangles[i *3+2]].y,
                    mf.sharedMesh.vertices[mf.sharedMesh.triangles[i *3+2]].z,
                    1.0f);
            }

            triangles_tex.SetPixels(_triangles, object_i);
            triangles_tex.Apply();

            triangles_per_object[object_i] = mf.sharedMesh.triangles.Length/3;
            transform_matrices[object_i] = mf.transform.localToWorldMatrix;
            transform_positions[object_i] = mf.transform.position;

            totalVertexes += mf.sharedMesh.vertexCount;
            totalTriangles += mf.sharedMesh.triangles.Length/3;
            object_i++;
        }

        
        m_Material.SetInt("objects", object_i);
        m_Material.SetFloatArray("triangles_per_object", triangles_per_object);
        m_Material.SetMatrixArray("transform_matrices", transform_matrices);
        m_Material.SetVectorArray("transform_positions", transform_positions);

        print("Total Vertices: " + totalVertexes);
        print("Total Triangles: " + totalTriangles);
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if (m_Shader && m_Material)
        {
            var p = GL.GetGPUProjectionMatrix(GetComponent<Camera>().projectionMatrix, false);// Unity flips its 'Y' vector depending on if its in VR, Editor view or game view etc... (facepalm)
            p[2, 3] = p[3, 2] = 0.0f;
            p[3, 3] = 1.0f;
            var clipToWorld = Matrix4x4.Inverse(p * GetComponent<Camera>().worldToCameraMatrix) * Matrix4x4.TRS(new Vector3(0, 0, -p[2, 2]), Quaternion.identity, Vector3.one);
            m_Material.SetMatrix("clipToWorld", clipToWorld);
            m_Material.SetVector("light_pos", light.transform.position);

            Graphics.Blit(src, dst, m_Material);
        }

        else
        {
            Graphics.Blit(src, dst);
            Debug.LogWarning(gameObject.name + ": Shader is not assigned. Disabling image effect.", this.gameObject);
            enabled = false;
        }
    }

    void OnDisable()
    {
        if (m_Material)
        {
            DestroyImmediate(m_Material);
        }
    }
}
