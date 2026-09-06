# Universal RTX 30 & 40 MFG Unlocker

Universal DLSS Multi Frame Generation enabler and experimental Ampere bridge for supported Windows x64 games on **NVIDIA GeForce RTX 30 Series (Ampere)** and **RTX 40 Series (Ada Lovelace)** GPUs. 

Adds Follow game, fixed 2X through the verified maximum (up to 6X), and Dynamic controls to games that already provide Streamline DLSS Frame Generation.

The same build supports DirectX 12 and Vulkan. It combines NVIDIA's listed maximum for each game with the active Streamline wrapper capacity, exposing up to 6X when both allow it and falling back to a supported lower maximum. It does not add DLSS Frame Generation to games that do not already support it.

> [!WARNING]
> This is unsupported research software. Multi-frame generation and the experimental Ampere (RTX 30 Series) FP8 $\to$ FP16 software emulation bridge are experimental and may cause visual artifacts, frame pacing variance, or crashes depending on the game engine and driver version.

---

## Features & RTX 30 Series Porting

1. **Universal Build:** Supports DirectX 12 and Vulkan games under a single binary set.
2. **RTX 30 Series (Ampere) Support:**
   - **Extended GPU Detection:** Accepts Compute Capability 8.6 and 8.0 (`VerifyAdaAdapter` extended for Ampere chips like GA102, GA104, GA106, GA100).
   - **Dynamic Fatbin & PTX Retargeting:** Intercepts the temporal intermediate scatter kernel fatbin and rewrites `.target sm_89` to `.target sm_86`, updating the architecture header in real time for CUDA JIT execution.
   - **FP8 $\to$ FP16 Software Emulation Bridge:** Software emulation layer (`ampere_fp8_emulator`) providing branchless LUT conversions for `E4M3` and `E5M2` FP8 tensors and matrix multiply-accumulate (MMA) tile emulation for hardware lacking native 4th-gen Tensor Core instructions.
3. **Live ReShade Controls:** Live fixed and Dynamic multiplier selection in the in-game ReShade overlay with real-time pipeline telemetry.
4. **Ada Temporal Correction:** Patches the hardcoded $t = 0.5f$ midpoint bias in DLSS-G to support arbitrary temporal positions for 3X, 4X, and 6X multipliers.

---

## Installation

Requires Windows x64, an **NVIDIA GeForce RTX 30 or 40 Series GPU**, a game with working Streamline DLSS Frame Generation, [Ultimate ASI Loader](https://github.com/ThirteenAG/Ultimate-ASI-Loader), and [ReShade](https://reshade.me/) with add-on support.

Copy these compiled files beside the game's main executable:

```text
RTX40MFGCore.dll
RTX40MFG.asi
RTX40MFG-UI.addon64
```

Install Ultimate ASI Loader under a supported proxy name that the game loads early (such as `dinput8.dll` or `version.dll`). Merge any supplied `global.ini` values into the matching loader configuration file (`dinput8.ini` or `version.ini`).

### DirectX 12
Install ReShade for DirectX 10/11/12 (which usually creates `dxgi.dll`). Install Ultimate ASI Loader under a different proxy name (commonly `dinput8.dll` or `version.dll`). Never install both loaders under the same filename.

### Vulkan
Select Vulkan in the ReShade installer. Use Ultimate ASI Loader under an early proxy name that the Vulkan executable imports (such as `dinput8.dll`, `version.dll`, or `winmm.dll`).

---

## Usage

1. Launch the game and press the **Home** key to open the ReShade menu.
2. Navigate to the **DLSS MFG** tab.
3. Choose **Follow game**, a fixed multiplier (2X, 3X, 4X, 6X), or **Dynamic**.
4. The panel displays output FPS and the active status of the `Ampere FP8->FP16 Bridge`.

---

## Troubleshooting

### Frozen image or black screen above 2x
1. Close the game.
2. Open the game's profile in the **NVIDIA App**. Under **DLSS Override - Model Presets**, set **Frame Generation** to **Preset B** and apply.
3. Restart the game and test the desired multiplier.

### ReShade status flicker
Try renaming the Ultimate ASI Loader proxy to `dinput8.dll` if `version.dll` causes UI overlay flicker.

---

## Automated CI & Local Build

### Automated Build (GitHub Actions)
A pre-configured GitHub Actions workflow is included at [`.github/workflows/build.yml`](.github/workflows/build.yml). Pushing to your repository automatically builds:
- `RTX40MFGCore.dll`
- `RTX40MFG.asi`
- `RTX40MFG-UI.addon64`

Download the resulting ZIP archive directly from the **Actions $\to$ Artifacts** tab.

### Local Build (Windows)
Requires Visual Studio 2022 with Desktop C++ workload and MASM (`ml64.exe`):
Run [`build.bat`](build.bat) from the project root. The script automatically fetches dependencies (Streamline SDK, ReShade, ImGui) and outputs compiled binaries to the `dist/` folder.

---

## How It Works

`RTX40MFG.asi` imports `RTX40MFGCore.dll`, ensuring early injection before the main game creates its first DLSS pipeline. The core hooks Streamline (`sl.dlss_g.dll`) and NGX (`nvngx_dlssg.dll`), un-clamps the requested frame capacity, adjusts the CUDA fatbin headers and PTX code for the detected GPU architecture, and runs the software emulation bridge when executing on Ampere GPUs.

Logs are written to:
- `%TEMP%\MfgUnlock-<PID>.log`
- `%TEMP%\MfgUnlock-intervals-<PID>.csv`

---

## License

Original code in this repository is licensed under the [MIT License](LICENSE). NVIDIA Streamline, NGX, ReShade, and MinHook remain subject to their respective licenses.
