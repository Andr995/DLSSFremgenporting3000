# External NVIDIA/Ampere backend

- Author/project: [sdli1995/dlssg_for_sm86](https://github.com/sdli1995/dlssg_for_sm86).
- Release identity: 0.3.5, pinned commit `9621db573e07ed54f50c15bbb585ed9a7bdfac28`.
- Original DLL: [version.dll at the pinned commit](https://github.com/sdli1995/dlssg_for_sm86/blob/9621db573e07ed54f50c15bbb585ed9a7bdfac28/version.dll).
- SHA-256: `C3934A09399F022504227C72DF0BF8C0DE55F9A08880DDDDE898C5262CEFA838` (30,021,920 bytes).
- [Author's README and licensing statement](https://github.com/sdli1995/dlssg_for_sm86/blob/9621db573e07ed54f50c15bbb585ed9a7bdfac28/README.en.md).
- [Original third-party notices](https://github.com/sdli1995/dlssg_for_sm86/blob/9621db573e07ed54f50c15bbb585ed9a7bdfac28/THIRD_PARTY_NOTICES.txt), preserved byte for byte in each package.

The DLL is an unchanged precompiled upstream binary. This repository adds packaging, deployment, restore and documentation; it does not claim authorship of the NVIDIA runtime or SM86 kernels. The local C++ Ada code is a separate project.

The author states GPLv3 for project source and separate third-party conditions for NVIDIA runtime/model/kernel assets. The MIT license of the local repository does not relicense those assets. The upstream snapshot does not contain the complete rebuildable source for this binary, and the `LICENSE.md` mentioned in its notice is absent at the pinned revision.

The original notice still describes an older 310.1 runtime. The bundled runtime actually selected in the verified local sessions is **NVIDIA DLSS-G 310.9.1**, SHA-256 `ff6e90eb78b827927dff5b4ecc6b1c870c2e9bca29ed9f48c7d348cc9e170b82`. The upstream notice is retained without silently editing this discrepancy.

The binary's self-signed publisher is `CN=DLSSG for SM86 (self-signed)`, certificate SHA-1 thumbprint `85BA66762F851E49148D706915D09026281418E6`. This is not an NVIDIA signature or a full security/source audit.
