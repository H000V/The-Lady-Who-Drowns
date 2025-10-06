using UnityEngine;
using UnityEngine.XR;
public class Bouncer : MonoBehaviour
{
    [SerializeField] float force = .5f;
    void Update()
    {
        InputDevice leftHand = InputDevices.GetDeviceAtXRNode(XRNode.LeftHand);
        bool xButtonPressed;
        if (leftHand.TryGetFeatureValue(CommonUsages.primaryButton, out xButtonPressed) && xButtonPressed)
        {
            GetComponent<Rigidbody>()?.AddForce(Vector3.up * force, ForceMode.Impulse);
        }
            
    }
}