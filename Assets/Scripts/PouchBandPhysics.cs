using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class PouchBandPhysics : MonoBehaviour
{
    public Transform leftAnchor;
    public Transform rightAnchor;
    public LineRenderer bandRenderer;

    private Rigidbody pouchRb;
    private SpringJoint leftSpring;
    private SpringJoint rightSpring;

    void Start()
    {
        pouchRb = GetComponent<Rigidbody>();

        if(bandRenderer != null)
        {
            bandRenderer.positionCount = 3;
        }

        leftSpring = gameObject.AddComponent<SpringJoint>();
        leftSpring.autoConfigureConnectedAnchor = false;
        leftSpring.connectedAnchor = leftAnchor.position;
        leftSpring.spring = 900f;
        leftSpring.damper = 15f;
        leftSpring.connectedBody = leftAnchor.GetComponent<Rigidbody>();

        rightSpring = gameObject.AddComponent<SpringJoint>();
        rightSpring.autoConfigureConnectedAnchor = false;
        rightSpring.connectedAnchor = rightAnchor.position;
        rightSpring.spring = 900f;
        rightSpring.damper = 15f;
        rightSpring.connectedBody = rightAnchor.GetComponent<Rigidbody>();
    }

    private void FixedUpdate()
    {
        leftSpring.connectedAnchor = leftAnchor.position;
        rightSpring.connectedAnchor = rightAnchor.position;
    }

    void Update()
    {
        if(bandRenderer != null)
        {
            bandRenderer.SetPosition(0, leftAnchor.position);
            bandRenderer.SetPosition(1, transform.position);
            bandRenderer.SetPosition(2, rightAnchor.position);
        }
    }
}
