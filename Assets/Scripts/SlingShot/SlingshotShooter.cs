// SlingshotAuto_v1_3.cs — Fixed: Disables XR interactables on projectiles to prevent grab interference
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.XR.Interaction.Toolkit.Interactables;
using UnityEngine.XR.Interaction.Toolkit.Interactors;

[DefaultExecutionOrder(-10)]
public class SlingshotAuto_v1_3 : MonoBehaviour
{
    [Header("Auto-finds if empty")]
    [SerializeField] Transform frame;          // cylinder
    [SerializeField] Transform pouchSphere;    // sphere to pull
    [SerializeField] Transform spawnPoint;     // aim = forward
    [SerializeField] Transform pouchRest;      // rest position
    [SerializeField] Transform pullAnchor;     // center to pull from

    [Header("Projectile (assign prefab asset if you have one)")]
    [SerializeField] Rigidbody projectilePrefab;         // MUST have a Collider
    [SerializeField] bool autoMakeTestProjectileIfNone = true;
    [SerializeField] float testProjectileScale = 0.06f;

    [Header("Tuning")]
    [SerializeField] float maxPullDistance = 0.35f;
    [SerializeField] float launchForcePerMeter = 1800f;
    [SerializeField] float returnSpeed = 10f;
    [SerializeField] float spawnForwardOffset = 0.08f;   // extra distance in front of spawnPoint

    [Header("Visuals")]
    [SerializeField] bool addTrailToProjectile = true;
    [SerializeField] float trailTime = 1.0f;

    [Header("Projectile Interaction")]
    [SerializeField] bool allowGrabbingProjectilesAfterFiring = false;
    [SerializeField] float delayBeforeProjectileGrabbable = 1.0f;

    XRGrabInteractable frameGrab;
    XRSimpleInteractable pouchInteractable;
    Collider pouchCol;

    bool pouchHeld;
    XRBaseInteractor pouchInteractor;

    readonly List<Collider> frameColliders = new List<Collider>();
    Rigidbody runtimeTemplate; // optional test projectile template

    void Reset() { AutoWire(); }
    void Awake()
    {
        AutoWire();
        AutoConfigure();
        Hook(true);

        Debug.Log($"[Slingshot] Awake: frame={(frame ? frame.name : "NULL")} pouch={(pouchSphere ? pouchSphere.name : "NULL")} spawnPoint={(spawnPoint ? spawnPoint.name : "NULL")} pullAnchor={(pullAnchor ? pullAnchor.name : "NULL")}");
        Debug.Log($"[Slingshot] Projectile prefab set? {(projectilePrefab ? projectilePrefab.name : "NONE")}  (autoMakeTestProjectileIfNone={autoMakeTestProjectileIfNone})");
    }
    void OnDestroy() { Hook(false); ReenableFrameColliders(); }

    void Update()
    {
        // follow hand while held
        if (pouchHeld && pouchInteractor)
        {
            Transform attach = pouchInteractor.GetAttachTransform(pouchInteractable);
            Vector3 target = attach ? attach.position : pouchInteractor.transform.position;
            pouchSphere.position = target;

            if (pullAnchor)
            {
                Vector3 dir = pouchSphere.position - pullAnchor.position;
                float d = dir.magnitude;
                if (d > maxPullDistance) pouchSphere.position = pullAnchor.position + dir.normalized * maxPullDistance;
            }
        }
        else if (pouchSphere && pouchRest)
        {
            pouchSphere.position = Vector3.Lerp(pouchSphere.position, pouchRest.position, Time.deltaTime * returnSpeed);
        }
    }

    // ---------- setup ----------
    void AutoWire()
    {
        if (!frame) frame = transform.Find("Cylinder") ?? transform;
        if (!pouchSphere) pouchSphere = transform.Find("SlingShot/Sphere") ?? transform.Find("Sphere");
        if (!spawnPoint) spawnPoint = transform.Find("SlingShot/SpawnPoint") ?? transform.Find("SpawnPoint");
        if (!pouchRest) pouchRest = transform.Find("SlingShot/PouchRest") ?? transform.Find("PouchRest");
        if (!pullAnchor) pullAnchor = transform.Find("SlingShot/PullAnchor") ?? transform.Find("PullAnchor");

        if (!spawnPoint)
        {
            spawnPoint = new GameObject("SpawnPoint").transform;
            spawnPoint.SetParent(transform, false);
            spawnPoint.localPosition = Vector3.forward * 0.2f;
            spawnPoint.localRotation = Quaternion.identity;
            Debug.Log("[Slingshot] Created SpawnPoint");
        }
        if (!pouchRest && pouchSphere)
        {
            pouchRest = new GameObject("PouchRest").transform;
            pouchRest.SetParent(transform, false);
            pouchRest.position = pouchSphere.position;
            Debug.Log("[Slingshot] Created PouchRest");
        }
        if (!pullAnchor)
        {
            pullAnchor = new GameObject("PullAnchor").transform;
            pullAnchor.SetParent(transform, false);
            pullAnchor.position = spawnPoint.position;
            Debug.Log("[Slingshot] Created PullAnchor");
        }
    }

    void AutoConfigure()
    {
        // FRAME
        frameGrab = frame.GetComponent<XRGrabInteractable>();
        if (!frameGrab) frameGrab = frame.gameObject.AddComponent<XRGrabInteractable>();
        frameGrab.throwOnDetach = false;
        frameGrab.selectMode = InteractableSelectMode.Multiple;

        if (!frame.TryGetComponent<Collider>(out var fc)) fc = frame.gameObject.AddComponent<CapsuleCollider>();
        fc.isTrigger = false;

        if (!frame.TryGetComponent<Rigidbody>(out var frb)) frb = frame.gameObject.AddComponent<Rigidbody>();
        frb.useGravity = false; frb.isKinematic = false;

        frameColliders.Clear(); frame.GetComponents(frameColliders);

        // POUCH
        if (!pouchSphere) { Debug.LogError("[Slingshot] Missing pouchSphere."); return; }
        pouchInteractable = pouchSphere.GetComponent<XRSimpleInteractable>();
        if (!pouchInteractable) pouchInteractable = pouchSphere.gameObject.AddComponent<XRSimpleInteractable>();
        pouchCol = pouchSphere.GetComponent<Collider>() ?? pouchSphere.gameObject.AddComponent<SphereCollider>();
        pouchCol.isTrigger = true;

        // Ensure projectile prefab or make a test one
        if (!projectilePrefab && autoMakeTestProjectileIfNone)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            go.name = "RuntimeTestProjectile";
            go.transform.localScale = Vector3.one * testProjectileScale;
            var rb = go.AddComponent<Rigidbody>();
            rb.useGravity = true;
            rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
            runtimeTemplate = rb;
            projectilePrefab = rb;
            go.SetActive(false); // template only
            Debug.Log("[Slingshot] Created runtime test projectile template (sphere).");
        }
    }

    void Hook(bool on)
    {
        if (frameGrab)
        {
            if (on) { frameGrab.selectEntered.AddListener(OnFrameGrab); frameGrab.selectExited.AddListener(OnFrameRelease); }
            else { frameGrab.selectEntered.RemoveListener(OnFrameGrab); frameGrab.selectExited.RemoveListener(OnFrameRelease); }
        }
        if (pouchInteractable)
        {
            if (on) { pouchInteractable.selectEntered.AddListener(OnPouchGrab); pouchInteractable.selectExited.AddListener(OnPouchRelease); }
            else { pouchInteractable.selectEntered.RemoveListener(OnPouchGrab); pouchInteractable.selectExited.RemoveListener(OnPouchRelease); }
        }
    }

    // ---------- events ----------
    void OnFrameGrab(SelectEnterEventArgs _) { /* no-op */ }
    void OnFrameRelease(SelectExitEventArgs _) { /* no-op */ }

    void OnPouchGrab(SelectEnterEventArgs args)
    {
        pouchHeld = true;
        DisableFrameColliders(); // prevent hand switch
        if (args.interactorObject is XRBaseInteractor xri) pouchInteractor = xri;

        Debug.Log("[Slingshot] Pouch grabbed.");
    }

    void OnPouchRelease(SelectExitEventArgs _)
    {
        Debug.Log("[Slingshot] Pouch released. Attempting to fire…");
        TryFire();
        pouchHeld = false;
        pouchInteractor = null;
        ReenableFrameColliders();
    }

    // ---------- fire ----------
    void TryFire()
    {
        if (!spawnPoint) { Debug.LogError("[Slingshot] No SpawnPoint."); return; }
        if (!pullAnchor) { Debug.LogError("[Slingshot] No PullAnchor."); return; }
        if (!pouchSphere) { Debug.LogError("[Slingshot] No PouchSphere."); return; }
        if (!projectilePrefab) { Debug.LogError("[Slingshot] No projectile prefab (and auto-make OFF)."); return; }

        Vector3 pullVec = pullAnchor.position - pouchSphere.position;
        float pull = Mathf.Clamp(pullVec.magnitude, 0f, maxPullDistance);
        Debug.Log($"[Slingshot] Pull magnitude = {pull:F3} m (max {maxPullDistance}).");

        if (pull <= 0.01f)
        {
            Debug.LogWarning("[Slingshot] Pull too small — not firing.");
            return;
        }

        Vector3 pos = spawnPoint.position + spawnPoint.forward * spawnForwardOffset;
        Quaternion rot = spawnPoint.rotation;

        Rigidbody rb = Instantiate(projectilePrefab, pos, rot);
        EnsureRB(rb);
        if (addTrailToProjectile) EnsureTrail(rb);

        // FIX: Disable any XR interactables on the projectile to prevent immediate grabbing
        DisableProjectileInteractables(rb.gameObject);

        // temporarily ignore collisions with frame & pouch to avoid instant hits
        Collider projCol = rb.GetComponent<Collider>();
        foreach (var fc in frameColliders) if (fc && projCol) Physics.IgnoreCollision(projCol, fc, true);
        if (pouchSphere && projCol && pouchSphere.TryGetComponent<Collider>(out var pc))
            Physics.IgnoreCollision(projCol, pc, true);

        rb.linearVelocity = Vector3.zero; rb.angularVelocity = Vector3.zero;
        float impulse = pull * launchForcePerMeter;
        rb.AddForce(spawnPoint.forward * impulse, ForceMode.Impulse);

        Debug.Log($"[Slingshot] SPAWNED '{rb.name}' at {pos}  impulse={impulse:F1}  dir={spawnPoint.forward}");

        StartCoroutine(ReenableAfter(projCol, rb.gameObject));
    }

    void EnsureRB(Rigidbody rb)
    {
        rb.useGravity = true;
        rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;

        // Fix bad MeshColliders (require convex), ensure at least one collider exists
        var mcs = rb.GetComponentsInChildren<MeshCollider>();
        foreach (var mc in mcs) if (mc && !mc.convex) mc.convex = true;

        if (!rb.GetComponent<Collider>() && mcs.Length == 0)
        {
            var sc = rb.gameObject.AddComponent<SphereCollider>();
            sc.radius = 0.03f;
        }
    }

    void EnsureTrail(Rigidbody rb)
    {
        if (!rb.GetComponent<TrailRenderer>())
        {
            var tr = rb.gameObject.AddComponent<TrailRenderer>();
            tr.time = trailTime;
            tr.widthCurve = AnimationCurve.Linear(0, 0.02f, 1, 0.0f);
            tr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            tr.receiveShadows = false;
            tr.minVertexDistance = 0.01f;
        }
    }

    // NEW: Disable XR interactables on projectile to prevent grab interference
    void DisableProjectileInteractables(GameObject proj)
    {
        var interactables = proj.GetComponentsInChildren<XRBaseInteractable>();
        foreach (var interactable in interactables)
        {
            if (interactable)
            {
                interactable.enabled = false;
                Debug.Log($"[Slingshot] Disabled {interactable.GetType().Name} on projectile to prevent grab interference.");
            }
        }
    }

    // NEW: Optionally re-enable interactables after delay
    IEnumerator ReenableAfter(Collider projCol, GameObject proj)
    {
        yield return new WaitForSeconds(0.3f);

        // Re-enable collision with frame/pouch
        foreach (var fc in frameColliders) if (fc && projCol) Physics.IgnoreCollision(projCol, fc, false);
        if (pouchSphere && projCol && pouchSphere.TryGetComponent<Collider>(out var pc))
            Physics.IgnoreCollision(projCol, pc, false);

        // Optionally re-enable interactables after additional delay
        if (allowGrabbingProjectilesAfterFiring && proj)
        {
            yield return new WaitForSeconds(delayBeforeProjectileGrabbable - 0.3f);
            var interactables = proj.GetComponentsInChildren<XRBaseInteractable>();
            foreach (var interactable in interactables)
            {
                if (interactable) interactable.enabled = true;
            }
        }
    }

    // ---------- collider toggles ----------
    void DisableFrameColliders() { foreach (var c in frameColliders) if (c) c.enabled = false; }
    void ReenableFrameColliders() { foreach (var c in frameColliders) if (c) c.enabled = true; }

    // ---------- gizmos ----------
    void OnDrawGizmosSelected()
    {
        if (pullAnchor) { Gizmos.color = Color.yellow; Gizmos.DrawWireSphere(pullAnchor.position, maxPullDistance); }
        if (spawnPoint) { Gizmos.color = Color.cyan; Gizmos.DrawRay(spawnPoint.position, spawnPoint.forward * 0.25f); }
    }
}