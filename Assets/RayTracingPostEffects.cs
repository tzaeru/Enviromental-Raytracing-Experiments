using UnityEngine;
using System.Collections;

public class RayTracingPostEffects : MonoBehaviour
{
    private Material m_Material;
    public Light light;

    public GameObject render_object;

    public ScenePrepare scene_prepare;

    void Start()
    {
        m_Material = render_object.GetComponent<Renderer>().material;

        render_object.GetComponent<Renderer>().material.SetTexture("_ColorTex", scene_prepare.color_texture);
        render_object.GetComponent<Renderer>().material.SetTexture("_PosTex", scene_prepare.position_texture);
        render_object.GetComponent<Renderer>().material.SetTexture("_NormalsTex", scene_prepare.normals_texture);
        
        render_object.transform.localScale = new Vector3(Camera.main.orthographicSize * 2.0f * Screen.width / Screen.height, Camera.main.orthographicSize * 2.0f, 0.1f);


        int totalVertexes = 0;
        int totalTriangles = 0;
        
        int object_i = 0;
        const int max_triangles_per_object = 2048;
        const int max_objects = 9;
        float[] triangles_per_object = new float[max_objects];
        Matrix4x4[] transform_matrices = new Matrix4x4[max_objects];
        Vector4[] transform_positions = new Vector4[max_objects];
        float[] aabbs = new float[max_objects * 6];
        Color[] colors = new Color[max_objects];

        Texture2DArray triangles_tex = new Texture2DArray(max_triangles_per_object, 3, max_objects, TextureFormat.RGBAFloat, false, true);
        m_Material.SetTexture("_TrianglesTex", triangles_tex);

        Texture2DArray triangle_normals_tex = new Texture2DArray(max_triangles_per_object, 1, max_objects, TextureFormat.RGBAFloat, false, true);
        m_Material.SetTexture("_TriangleNormalsTex", triangle_normals_tex);

        foreach (MeshFilter mf in FindObjectsOfType(typeof(MeshFilter)))
        {
            if (mf.gameObject.name == transform.GetChild(0).name)
            {
                continue;
            }

            print("Name: " + mf.name);
            print("Position: " + mf.transform.position);
            print("Transform Matrix: " + mf.transform.localToWorldMatrix);
            print("Vertices: " + mf.sharedMesh.vertexCount);
            print("Triangles: " + mf.sharedMesh.triangles.Length / 3);
            print("Normals: " + mf.sharedMesh.normals.Length);
            print("UVs: " + mf.sharedMesh.uv.Length);

            Color[] _triangles = new Color[max_triangles_per_object * 3];
            Color[] _normals = new Color[max_triangles_per_object];
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

                // HACKY normal calculation
                Vector3 normal = mf.sharedMesh.normals[mf.sharedMesh.triangles[i * 3]] + mf.sharedMesh.normals[mf.sharedMesh.triangles[i * 3 + 1]] + mf.sharedMesh.normals[mf.sharedMesh.triangles[i * 3 + 2]];
                normal /= 3.0f;
                _normals[i] = new Color(normal.x,
                    normal.y,
                    normal.z,
                    1.0f);
            }

            triangles_tex.SetPixels(_triangles, object_i);
            triangles_tex.Apply();

            triangle_normals_tex.SetPixels(_normals, object_i);
            triangle_normals_tex.Apply();

            triangles_per_object[object_i] = mf.sharedMesh.triangles.Length/3;
            transform_matrices[object_i] = mf.transform.localToWorldMatrix;
            transform_positions[object_i] = mf.transform.position;

            aabbs[object_i * 6] = mf.sharedMesh.bounds.min.x * 1.1f;
            aabbs[object_i * 6 + 1] = mf.sharedMesh.bounds.min.y * 1.1f;
            aabbs[object_i * 6 + 2] = mf.sharedMesh.bounds.min.z * 1.1f;
            aabbs[object_i * 6 + 3] = mf.sharedMesh.bounds.max.x * 1.1f;
            aabbs[object_i * 6 + 4] = mf.sharedMesh.bounds.max.y * 1.1f;
            aabbs[object_i * 6 + 5] = mf.sharedMesh.bounds.max.z * 1.1f;

            colors[object_i] = mf.GetComponent<Renderer>().material.GetColor("_Color");

            totalTriangles += mf.sharedMesh.triangles.Length/3;
            object_i++;
        }

        
        m_Material.SetInt("objects", object_i);
        m_Material.SetFloatArray("triangles_per_object", triangles_per_object);
        m_Material.SetMatrixArray("transform_matrices", transform_matrices);
        m_Material.SetVectorArray("transform_positions", transform_positions);
        m_Material.SetFloatArray("aabbs", aabbs);
        m_Material.SetColorArray("object_diffuse_colors", colors);

        print("Total Vertices: " + totalVertexes);
        print("Total Triangles: " + totalTriangles);
    }

    void Update()
    {
        m_Material.SetVector("light_pos", light.transform.position);

        /*var p = GL.GetGPUProjectionMatrix(GetComponent<Camera>().projectionMatrix, false);// Unity flips its 'Y' vector depending on if its in VR, Editor view or game view etc... (facepalm)
        p[2, 3] = p[3, 2] = 0.0f;
        p[3, 3] = 1.0f;
        var clipToWorld = Matrix4x4.Inverse(p * GetComponent<Camera>().worldToCameraMatrix) * Matrix4x4.TRS(new Vector3(0, 0, -p[2, 2]), Quaternion.identity, Vector3.one);
        m_Material.SetMatrix("clipToWorld", clipToWorld);*/

        m_Material.SetFloatArray("camera_pos", new float[] {transform.position.x, transform.position.y, transform.position.z});

        render_object.GetComponent<Renderer>().material.SetTexture("_ColorTex", scene_prepare.color_texture);
        render_object.GetComponent<Renderer>().material.SetTexture("_PosTex", scene_prepare.position_texture);
        render_object.GetComponent<Renderer>().material.SetTexture("_NormalsTex", scene_prepare.normals_texture);

        const int max_objects = 9;
        Matrix4x4[] transform_matrices = new Matrix4x4[max_objects];
        Color[] colors = new Color[max_objects];

        int object_i = 0;

        foreach (MeshFilter mf in FindObjectsOfType(typeof(MeshFilter)))
        {
            if (mf.gameObject.name == transform.GetChild(0).name)
            {
                continue;
            }

            transform_matrices[object_i] = mf.transform.localToWorldMatrix;
            colors[object_i] = mf.GetComponent<Renderer>().material.GetColor("_Color");

            object_i++;
        }

        m_Material.SetMatrixArray("transform_matrices", transform_matrices);
        m_Material.SetColorArray("object_diffuse_colors", colors);
    }
}
