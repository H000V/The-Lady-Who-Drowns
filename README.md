# 📂 Opening and Running an Existing Meta Quest 3 Unity Project

## 1. Local Environment Setup

Ensure your local machine meets the following criteria before opening the project:

1.  **Unity Editor Version:**
    * Open **Unity Hub**.
    * Find the **Editor Version** required by the project (often listed in the project's root `ProjectSettings/ProjectVersion.txt`).
    * If you don't have it, install the correct version (e.g., 2022.3 LTS).
2.  **Android Build Support:**
    * Verify the required Unity Editor version has the **Android Build Support** module installed, including **Android SDK & NDK Tools** and **OpenJDK**. (Manage Installs > Add Modules).
3.  **Meta Quest Prerequisites:**
    * Ensure your **Meta Quest 3** headset has **Developer Mode** enabled.
    * Install **Meta Quest Link** for editor testing.

## 2. Opening the Project

1.  **Open Unity Hub:** Use the "Add" button and select the root directory of the cloned project.
2.  **Open Project:** Launch the project using the **correct Unity Editor version** identified in Step 1.

---

## 3. Package Restoration and Verification

The packages required for VR are often included in the repository, but Unity may need to re-index them.

1.  **Check Packages:** Go to **Window** > **Package Manager**.
    * Verify that the following essential packages are listed and loaded (if not, install them from the Unity Registry):
        * `XR Plugin Management`
        * `OpenXR Plugin`
        * `XR Interaction Toolkit`
        * `Meta XR All-in-One SDK` (if used by the project)

## 4. Platform and Player Settings Verification

The core build settings should be automatically loaded, but it is critical to verify the Android target setup.

1.  **Verify Platform:** Go to **File** > **Build Settings...**
    * Confirm **Android** is selected and is the active platform (or click **Switch Platform** if needed).

2.  **Verify Player Settings:** Go to **Edit** > **Project Settings** > **Player** (Android tab).
    * **Scripting Backend:** Should be **IL2CPP**.
    * **Target Architectures:** **ARM64** must be checked.
    * **Graphics API:** **Vulkan** should be present/first.

## 5. OpenXR Configuration Check

Verify the OpenXR feature set is correctly enabled for the Meta Quest 3.

1.  Go to **Edit** > **Project Settings** > **XR Plug-in Management**.
2.  **Android Tab:**
    * Confirm the **OpenXR** box is checked under Plug-in Providers.
    * Click on the **OpenXR** section below and ensure the **Oculus Touch Controller Profile** is added under Interaction Profiles.
3.  **Windows/Mac/Linux Tab (Editor Link Test):**
    * Confirm the **OpenXR** box is checked.

## 6. Run the Project

1.  Start **Meta Quest Link** or **Air Link** on your PC.
2.  In Unity, press the **Play** button. Your headset should enter VR mode and display the scene.