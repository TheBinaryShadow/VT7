# Platform baseline, DLL loader, runtimes and packaging

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P0. Relevant project boundaries: native DLL startup, .NET host startup, renderer/plugin dependencies, and the portable package.

## Baseline is a contract, not an OS version check

VT7 currently names Windows 7 SP1 x64, KB2670838, loader support from KB2533623 or superseding servicing, SHA-2/servicing prerequisites, UCRT, and .NET Framework 4.8. It distinguishes the required floor from ESU and unofficial later NT 6.1 update tiers. [1]

Documented facts:

- .NET Framework 4.8 is listed for Windows 7 SP1. Do not replace its targeting pack with 4.8.1 and assume the deployment floor is unchanged. [2]
- The UCRT was initially delivered to older Windows via KB2999226; central deployment is the documented preferred route, while app-local deployment has restrictions. UCRT is a different component from the versioned MSVC C++ runtime. [3]
- Current Visual C++ redistributable guidance uses moving download links and requires a runtime at least as new as the toolset that built the application. Those links are not a stable Windows 7 dependency pin. [4]
- Historical .NET-on-Windows guidance names KB3063858 for Windows 7. This matters to a PowerShell 7 child even though VT7's WPF host uses .NET Framework. **Open question:** establish whether the declared loader prerequisite/superseding rollup satisfies this in each tested image. Do not silently add or remove a requirement. [5]

**Recommendation:** distinguish four records: developer SDK/toolset; host prerequisites; optional shell prerequisites; and exact shipped DLLs. A working developer PC proves none of the latter three on a clean target.

## Loader APIs and failure timing

SetDefaultDllDirectories and the LOAD_LIBRARY_SEARCH flags require KB2533623 on Windows 7; Microsoft instructs downlevel callers to resolve SetDefaultDllDirectories with GetProcAddress. Added user directories do not have a specified search order. [6]

LoadLibraryExW can restrict dependency lookup to the loaded DLL's directory and System32. LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR requires an absolute DLL path. Loading with DONT_RESOLVE_DLL_REFERENCES is not an executable compatibility test: normal dependency resolution and initialization are intentionally skipped. [7]

**Recommended startup design:**

1. Resolve the application's own directory independently of the current working directory.
2. Establish the intended DLL search policy before loading optional native components.
3. Dynamically detect optional exports; fail with an actionable prerequisite message for mandatory missing capabilities.
4. Load the real dependency graph and exercise required COM interfaces and methods.
5. Record actual loaded module paths and versions so accidental developer-machine resolution is visible.

An unresolved ordinary import can prevent the module loading before its own error UI runs. Therefore a bootstrap that is supposed to explain a missing capability must not itself require that capability through a mandatory import. This is a design inference from loader behavior, not a claim that the existing host already has such a bootstrap. [7]

## Build flags do not provide missing implementations

The inspected Core.props defines WINVER/_WIN32_WINNT 0x0601 and NTDDI_VERSION 0x06010100. BUILDING.md pins VS 2022 17.14, MSVC 14.44.35207, and SDK 10.0.26100.0. Newer declarations are temporarily exposed for the isolated renderer. These are source/build controls, not an emulation layer. [8][9]

**Recommendation:** audit EXE/DLL imports, delay imports, dynamically named modules/exports, static initializers, shader compilers, framework assemblies, COM QueryInterface requests, and flags on existing APIs. A denylist of known modern functions is useful but cannot prove completeness.

Keep all expensive work out of DllMain: Windows invokes it under loader lock. Renderer threads, font discovery, managed callbacks, and process creation belong in explicit initialization after loading. [10]

## Packaging and acceptance

Proposed package ledger:

| Item | Record |
| --- | --- |
| Every native binary | Architecture, file version, hash, source revision, runtime linkage and imports |
| Runtime redistributables | Exact version and permitted redistribution source; no unreviewed moving download |
| OS prerequisites | Capability provided, applicable official update/supersedence, restart requirement |
| Managed dependencies | Target framework, native dependency closure, startup behavior on 4.8 |
| Fonts/shaders | Origin, license, version, hash, generated-source provenance |
| Diagnostics | Missing prerequisite, actual module path, HRESULT/Win32 code and failed stage |

Test portable extraction under a Unicode path, a path with spaces, a read-only application directory, and an unrelated current directory. Test from a VM with no developer SDK or build tools. Test Debug and Release separately; debug graphics layers and debug CRTs must not become unexplained user prerequisites.

The accepted proof's runtime files should remain pinned until a new exact package passes Windows 7 acceptance. A vendor's current support statement and a historical binary's observed execution are different claims. [4][9]

Observed package pin: both inspected packaging scripts require the Visual Studio redistributable directory version **14.44.35112** and copy msvcp140.dll, vcruntime140.dll and vcruntime140_1.dll. This is separate from the compiler/toolset version **14.44.35207**. Keep those component identifiers distinct in run manifests; do not replace the package's DLLs from a moving download just because the major runtime names match. The UCRT remains a separately declared OS prerequisite. [1][11]

## Sources

- [1] [VT7 prerequisite and tier contract](../../../ROADMAP.md).
- [2] Microsoft, [.NET Framework system requirements](https://learn.microsoft.com/en-us/dotnet/framework/get-started/system-requirements).
- [3] Microsoft, [Universal CRT deployment](https://learn.microsoft.com/en-us/cpp/windows/universal-crt-deployment?view=msvc-170).
- [4] Microsoft, [Visual C++ redistributable guidance](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170).
- [5] Microsoft, [Install .NET on Windows: historical Windows 7 prerequisites](https://learn.microsoft.com/en-us/dotnet/core/install/windows#windows-7--81--server-2012).
- [6] Microsoft, [SetDefaultDllDirectories](https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-setdefaultdlldirectories).
- [7] Microsoft, [LoadLibraryExW](https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-loadlibraryexw).
- [8] [Core.props](../../../src/vt7/VT7.Core/Core.props) and [renderer build notes](../../../src/vt7/VT7.Renderer/README.md).
- [9] [BUILDING.md](../../../BUILDING.md).
- [10] Microsoft, [DLL best practices](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-best-practices).
- [11] [Proof packaging and runtime pin](../../../tools/Package-VT7Proof.ps1) and [renderer-probe packaging](../../../tools/Package-VT7RendererProbe.ps1).
