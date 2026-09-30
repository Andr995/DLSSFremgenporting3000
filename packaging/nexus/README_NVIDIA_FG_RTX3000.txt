NVIDIA FRAME GENERATION FOR CYBERPUNK 2077 / RTX 30 SERIES
Integration 0.3.5-cp2077.2 — nikecatania95/Andr995
https://github.com/Andr995/DLSSFremgenporting3000

Experimental integration of sdli1995/dlssg_for_sm86 0.3.5.
The precompiled upstream backend is unchanged. Frame generation uses an adapted
NVIDIA DLSS-G runtime. This is not official NVIDIA RTX 30-series support.

CHOOSE ONE PACKAGE
CET-ASI: requires a working Cyber Engine Tweaks/compatible ASI loader.
Standalone: for installations without CET and without another version.dll.
NVIDIA-FG-RTX3000-Docs/VARIANT.txt identifies this archive. Never install both.

CET-ASI INSTALLATION
1. Close the game. Back up existing FG files/configuration outside its folder.
2. Install a CET version compatible with your game from the official release:
   https://github.com/maximegmd/CyberEngineTweaks/releases
   CET is a separate dependency and is not included in this archive.
3. If the previous FG release overwrote bin/x64/version.dll, restore CET's
   original version.dll from your backup or reinstall CET.
4. Move the OLD FG backend/INI out of bin/x64. Identify the FG DLL by SHA-256;
   never remove a loader solely because its filename is version.dll.
5. Extract this archive into the game folder containing bin. Final FG paths:
   bin/x64/plugins/dlssg_sm86.asi
   bin/x64/plugins/dlssg_sm86.ini
   Keep CET's original bin/x64/version.dll and cyber_engine_tweaks.asi.
   Do NOT put FG inside plugins/cyber_engine_tweaks.

STANDALONE INSTALLATION
Use only without CET or another version.dll. Close the game and back up originals.
Extract the Standalone archive into the game folder containing bin:
   bin/x64/version.dll
   bin/x64/dlssg_sm86.ini
Do not leave an ASI copy active in plugins.

FOR BOTH VARIANTS
- Back up and disable competing NGX/FSR frame-generation bridges, including
  nvngx.dll, dlssg_to_fsr3_amd_is_better.dll and old RTX40MFG components.
  Preserve the game's original nvngx_dlss*.dll runtimes, ReShade and CET.
- Check Hardware-accelerated GPU scheduling (HAGS) in Windows Settings >
  System > Display > Graphics. Restart Windows if you enable it.
- Select DLSS Frame Generation in the game, apply and restart the game when
  requested. Start at 2x and keep Reflex enabled. Then test 3x/4x separately. Restart after changing graphics settings before comparing results.
- Optimized=0 and MaxGeneratedFrames=3 preserve the earlier test configuration.
  Select the actual multiplier in the game. Do not force 6x.
- Manual installation is documented. Vortex deployment has not been tested.

TROUBLESHOOTING
Run the included read-only diagnostic from the game root in PowerShell:
.\NVIDIA-FG-RTX3000-Docs\tools\diagnose-ampere.ps1 -GameExecutable '.\bin\x64\Cyberpunk2077.exe' -OutputPath '.\fg-diagnostic.json'

Choose a new report filename if one already exists. The report checks file
placement/hashes, duplicates, loader layout, HAGS configuration, GPU/driver and
recent log samples. It does not change the registry, drivers or game settings.
ConfiguredOn is not proof of a completed reboot; Unknown is not proof HAGS is off.
Read the report before sharing it. Personal absolute paths/saves/raw logs are
not collected by this script.

Log directories (unless you changed Logging.Directory):
CET-ASI: bin/x64/plugins/dlssg_sm86/logs
Standalone: bin/x64/dlssg_sm86/logs
Match the PID and timestamp of the session you tested. An old log, an unlocked
menu or an FPS counter alone does not prove current NVIDIA FG execution.

If CET stopped working, repair its original root version.dll and use CET-ASI.
If FG does not appear, verify the loader, adjacent INI, HAGS after restart,
driver/game versions and competing mods. The RTX 3070m report remains unresolved:
we need that user's current-session diagnostics to establish the cause.

UNINSTALL
Close the game. Remove ONLY the two FG files of your chosen variant and restore
your own originals if applicable. Do not delete CET's loader, CET files, or the
whole plugins folder. If you used the separate Tools installer, use its printed
restore.json manifest with scripts/restore-ampere.ps1. Graphics menu settings
are separate from file restoration. Game-file verification may leave added
third-party DLLs in place.

EVIDENCE AND CREDITS
Historical RTX 3060 Ti benchmarks and the new CET/ASI execution check are in NVIDIA-FG-RTX3000-Docs/VALIDATION_EN.md. CET 1.37.1 and NVIDIA FG executed together in the test session; different presets produced different results and need separate verification.
No universal compatibility or new FPS gain is promised by this packaging update.
Backend: sdli1995/dlssg_for_sm86, commit 9621db573e07ed54f50c15bbb585ed9a7bdfac28.
NVIDIA: original DLSS runtime/model/kernel assets, subject to their own terms.
Integration/history licenses do not relicense third-party components.
Preserved notices and BACKEND_PROVENANCE.md explain origin and limitations.
Original C++ research lineage: Michael Robles / dashdogy (MIT), separate from
the Ampere DLL distributed here.
Community CET guidance: nicklasz; confirmation: dak002. Thanks to all reporters.

SHA-256 (identical for the upstream version.dll and renamed dlssg_sm86.asi):
C3934A09399F022504227C72DF0BF8C0DE55F9A08880DDDDE898C5262CEFA838

Italian instructions: NVIDIA-FG-RTX3000-Docs/INSTALL_IT.md.
