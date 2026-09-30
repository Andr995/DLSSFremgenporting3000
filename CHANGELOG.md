# Changelog

## 0.3.5-cp2077.2 — 2026-09-30
Integration/package update. The pinned sdli1995 backend remains unchanged at 0.3.5.

- Added a CET-ASI main package: FG is loaded from bin/x64/plugins/dlssg_sm86.asi, with its INI beside it. CET's original bin/x64/version.dll is preserved.
- Kept a separate Standalone alternative for installations without CET or a conflicting version.dll. Install one variant only.
- Installer selects ASI when a recognized loader/CET layout is available. Unknown proxies are rejected, rather than overwritten.
- The recognized old root FG backend is backed up during ASI migration to avoid loading both copies.
- Added nested-path backups, reversible restoration, legacy manifest support, and rejection of linked or tampered paths.
- Added read-only diagnostics for loader/config placement, duplicate backend, competing bridges, GPU/driver, HAGS configuration and recent log samples.
- Documented recovery from the initial CET loader conflict, both log locations, restart requirements and a useful bug-report procedure.
- Added regression tests for CET preservation, migration prerequisites, standalone/ASI restore, legacy restore, tampering, conflicts, malformed logs and junction protection.
- Updated English/Italian installation guides, Nexus BBCode, credits and verified ZIP/RAR variants.

Known unresolved case: an RTX 3070m user reported no FG menu. HAGS was suggested in the thread, but the user has not confirmed a resolution. No universal RTX 30-series support or new performance improvement is claimed.

Community reports:
https://www.nexusmods.com/cyberpunk2077/mods/34477?tab=posts
ASI placement guidance: nicklasz; confirmation: dak002.
Backend: https://github.com/sdli1995/dlssg_for_sm86
Integration: https://github.com/Andr995/DLSSFremgenporting3000

### Runtime verification
CET 1.37.1 and the FG ASI were validated together on RTX 3060 Ti / Cyberpunk 2.31:
19,296 evaluations, 172 successful samples, zero sampled launch errors/fallbacks,
clean exit. See evidence/cyberpunk-cet-asi-validation.json.
Two different graphics configurations reported 119.69 and 45.02 FPS; they are
not an A/B comparison. The low second result needs a controlled restart test.
Restart the game after changing graphics settings and verify current-session logs.
