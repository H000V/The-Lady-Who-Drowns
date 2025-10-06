using UnityEngine;
public class HitLogger : MonoBehaviour
{
    void OnCollisionEnter(Collision c) { Debug.Log("Hit " + c.collider.name); }
}
