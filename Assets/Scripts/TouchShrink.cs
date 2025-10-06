using System.Numerics;
using Unity.VisualScripting;
using UnityEngine;
using Vector3 = UnityEngine.Vector3;

public class ScaleOnTouch : MonoBehaviour
{
    [SerializeField] Vector3 newScale = new Vector3(10f, 10f, 0f); // target scale
    [SerializeField] Vector3 changeScale = new Vector3(2f, 2f, 0f);

    void OnCollisionEnter(Collision collision)
    {
        transform.localScale = newScale;
        newScale = newScale - changeScale;
    }
}
