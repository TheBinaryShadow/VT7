# VT7 and inherited OpenConsole tools

For the Windows 7 port, start with [BUILDING.md](../BUILDING.md), the
[documentation index](../doc/vt7/README.md) and [current handoff](../doc/vt7/HANDOFF.md).
The `*-VT7*.ps1` scripts operate on `VT7.sln` and its separate artifact tree.
The inherited OpenConsole tools documented afterward are not the VT7 build or
Windows 7 acceptance workflow.

## VT7 command reference

Run these PowerShell scripts from the repository root. Build and test defaults
use `Debug`; test/verification runners accept `-Configuration Release` and
`-BinaryDirectory <folder>` where indicated. A binary-directory override does
not redirect their fixed report paths under `artifacts/vt7/reports`, so preserve
existing evidence before a relevant regression run.

| Script | Purpose and relevant options |
| --- | --- |
| `Build-VT7.ps1` | Builds `VT7.sln` for x64; `-Configuration` selects `Debug` or `Release`; `-NoRestore` uses a verified dependency restore. |
| `Restore-VT7Dependencies.ps1` | Verifies pinned WIL/GSL/fmt archive hashes and re-extracts their headers. |
| `Verify-VT7.ps1` | x64 PE/version/import audit; `-Configuration`, `-BinaryDirectory`, and mutually exclusive `-RendererProbeOnly` / `-AtlasProofOnly`. |
| `Verify-VT7Fonts.ps1` | Verifies pinned fonts/licenses; `-FontDirectory` selects the asset folder. |
| `Test-VT7.ps1` | Native/core diagnostics and viewport checks; `-Configuration`, `-BinaryDirectory`, `-Renderers`, `-SkipNegative`. |
| `Test-VT7AtlasRepaint.ps1` | Exact repaint/cursor checks; `-Configuration`, `-BinaryDirectory`, `-Renderers`; retains its expected-failure control. |
| `Test-VT7AtlasRecovery.ps1` | Controlled recovery scenarios; `-Configuration`, `-BinaryDirectory`. |
| `Test-VT7AtlasSettings.ps1` | Font/settings checks; `-Configuration`, `-BinaryDirectory`, `-ExpectedSystemDpi` accepts `0`, `96`, `120` or `144`. Zero leaves the actual DPI unasserted. |
| `Test-VT7AtlasStability.ps1` | Quick by default; `-Lifecycle` and `-Soak` are mutually exclusive; `-Renderer` accepts `both`, `atlas-d3d-hardware` or `atlas-d3d-warp`; `-Configuration`, `-BinaryDirectory`. |
| `Test-VT7RendererProbe.ps1` / `Test-VT7AtlasProof.ps1` | Independent historical harness regressions; `-Configuration`, `-BinaryDirectory`. |

The current application source reports 0.3.5/ABI 8 and includes resource-isolation
diagnostics absent from the issued 0.3.5 archive. These opt-in host CLI controls
are documented in the [stability record](../doc/vt7/validation/2026-09-13-atlas-stability.md);
the stability runner does not expose a resource-isolation parameter. The separate
native comparison 0.1 has its own packaged launcher and reuses the issued native
DLL. Both modes grow on Windows 7; exit 0 means measurement completion. The
integrated WARP lifecycle gate remains open. No unchanged-suite repeat or timed
soak is requested; the next recreate-versus-reuse control is a proposed design.

`Package-VT7Proof.ps1`, `Package-VT7RendererProbe.ps1` and
`Package-VT7AtlasProof.ps1` delete/recreate fixed package folders and archives
for viewport 0.3.5, probe 0.13 and backend proof 0.1 respectively. They expose
only `-SkipBuild`, not a destination override. Do not run them over issued
artifacts during this investigation. Future packaging needs distinct paths and
identity first. Packaging success and quick gates are not full target acceptance.

## Inherited OpenConsole workflow

These are a collection of tools and scripts to make your life building the
OpenConsole project easier. Many of them are designed to be functional clones of
tools that we used to use when developing inside the Windows build system.

## Razzle

This is a script that quickly sets up your environment variables so that these
tools can run easily. It's named after another script used by Windows developers
to similar effect.
 - It adds msbuild to your path.
 - It adds the tools directory to your path as well, so all these scripts are
 easily available.
 - It executes `\tools\.razzlerc.cmd` to add any other personal configuration to
 your environment as well, or creates one if it doesn't exist.
 - It sets up the default build configuration to be 'Debug'. If you'd like to
 manually specify a build configuration, pass the parameter `dbg` for Debug, and
 `rel` for Release.

## bcz

`bcz` can quick be used to clean and build the project. By default, it builds
the `%DEFAULT_CONFIGURATION%` configuration, which is `Debug` if you use `razzle.cmd`.

 - `bcz dbg` can be used to manually build the Debug configuration.
 - `bcz rel` can be used to manually build the Release configuration.


## opencon (and openbash, openps)

`opencon` can be used to launch the **last built** OpenConsole binary. If given an
argument, it will try and run that program in the launched window. Otherwise, it
will default to cmd.exe.

`openbash` is similar, it immediately launches bash.exe (the Windows Subsystem
for Linux entrypoint) in your `~` directory.

Likewise, `openps` launches powershell.

## runformat & runxamlformat

`runxamlformat` will format `.xaml` files to match our coding style. `runformat`
will format the c++ code (and will also call `runxamlformat`). **`runformat`
should be called before making a new PR**, to ensure that code is formatted
correctly. If it isn't, the CI will prevent your PR from merging.

The C++ code is formatted with `clang-format`. Many editors have built-in
support for automatically running clang-format on save.

Our XAML code is formatted with
[XamlStyler](https://github.com/Xavalon/XamlStyler). I don't have a good way of
running this on save, but you can add a `git` hook to format before committing
`.xaml` files. To do so, add the following to your `.git/hooks/pre-commit` file:

```sh
# XAML Styler - xstyler.exe pre-commit Git Hook
# Documentation: https://github.com/Xavalon/XamlStyler/wiki
# Originally from https://github.com/Xavalon/XamlStyler/wiki/Git-Hook

# Define path to xstyler.exe
XSTYLER_PATH="dotnet tool run xstyler --"

# Define path to XAML Styler configuration
XSTYLER_CONFIG="XamlStyler.json"

echo "Running XAML Styler on committed XAML files"
git diff --cached --name-only --diff-filter=ACM  | grep -e '\.xaml$' | \
# Wrap in brackets to preserve variable through loop
{
    files=""
    # Build list of files to pass to xstyler.exe
    while read FILE; do
        if [ "$files" == "" ]; then
            files="$FILE";
        else
            files="$files,$FILE";
        fi
    done

    if [ "$files" != "" ]; then
        # Check if external configuration is specified
        [ -z "$XSTYLER_CONFIG" ] && configParam="" || configParam="-c $XSTYLER_CONFIG"

        # Format XAML files
        $XSTYLER_PATH -f "$files" $configParam

        for i in $(echo $files | sed "s/,/ /g")
        do
            #strip BOM
            sed -i '1s/^\xEF\xBB\xBF//' $i
            unix2dos $i
            # stage updated file
            git add -u $i
        done
    else
        echo "No XAML files detected in commit"
    fi

    exit 0
}
```

## testcon, runut, runft
`runut` will automatically run all of the unit tests through TAEF. `runft` will
run the feature tests, and `testcon` runs all of them. They'll pass any
arguments through to TAEF, so you can more finely control the testing.

A recommended workflow is the following command:
```
bcz dbg && runut /name:*<name of test>*
```
Where `<name of test>` is the name of the test testing the relevant feature area
you're working on. For example, if I was working on the VT Mouse input support,
I would use `MouseInputTest` as that string, to isolate the mouse input tests.
If you'd like to run all the tests, just ignore the `/name` param:
`bcz dbg && runut`

To make sure your code is ready for a pull request, run the build, then launch
the built console, then run the tests in it. The built console will inherit all
of the razzle environment, so you can immediately start using the macros:
 1. `bcz`
 2. `opencon`
 3. `testcon` (in the new console window)
 4. `runformat`

If they all come out green, then you're ready for a pull request!
