using UnityEngine;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.XR.Interaction.Toolkit.Interactables;

public class SlingshotFire : MonoBehaviour
{
    [Header("References")]
    public XRGrabInteractable pouch;
    public Transform pouchRest;
    public Transform spawnPoint;
    public Rigidbody projectilePrefab;

    [Header("Tuning")]
    public float strength = 30f;
    public float minStretch = 0.01f;

    void Awake()
    {
        if (!pouch) pouch = GetComponent<XRGrabInteractable>();
        pouch.selectExited.RemoveListener(OnRelease);
        pouch.selectExited.AddListener(OnRelease);
        Debug.Log("[SlingshotFire] Awake: wired selectExited");
    }

    void OnRelease(SelectExitEventArgs _)
    {
        if (!pouchRest || !spawnPoint || !projectilePrefab)
        {
            Debug.LogWarning("[SlingshotFire] Missing reference");
            return;
        }

        float stretch = Vector3.Distance(transform.position, pouchRest.position);
        Debug.Log("[SlingshotFire] Release. stretch=" + stretch);

        if (stretch < minStretch) return;

        Vector3 dir = (pouchRest.position - transform.position).normalized;

        Rigidbody proj = Instantiate(projectilePrefab, spawnPoint.position, spawnPoint.rotation);
        proj.linearVelocity = dir * stretch * strength;
        Debug.Log("[SlingshotFire] Spawned projectile with speed " + (stretch * strength));
    }
}
