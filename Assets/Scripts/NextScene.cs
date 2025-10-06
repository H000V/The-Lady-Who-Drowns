using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.XR.Interaction.Toolkit.Interactables;
using UnityEngine.XR.Interaction.Toolkit.Interactors;
public class NextScene : MonoBehaviour
{
    private XRBaseInteractable interactable;
    void Start()
    {
        interactable = GetComponent<XRBaseInteractable>();
        interactable.hoverEntered.AddListener(loadingTime);
    }

    public void loadingTime(BaseInteractionEventArgs poke)
    {
        if (poke.interactableObject is XRPokeInteractor)
        {
            SceneManager.UnloadSceneAsync("MenuArea");
            SceneManager.LoadScene("Playground");
        }
    }
}
