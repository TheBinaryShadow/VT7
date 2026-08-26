## Summary

What does this change, and what user or engineering problem does it solve?

## Related issues

Closes #

## Windows 7 reasoning

- Which Windows 7 APIs, prerequisites, or compatibility boundaries matter here?
- Does this add any post-Windows 7 import, SDK assumption, runtime dependency,
  or packaging requirement?
- Why is the selected approach appropriate for VT7?

## Validation

List automated tests and manual checks. For Windows 7 testing, include:

- Physical machine or virtual machine.
- Windows edition, architecture, and update tier.
- GPU, driver, hardware D3D or WARP, and DPI where relevant.
- Shell or remote application and exact version.
- Session backend.

## Provenance and licensing

Identify any code adapted from Microsoft Terminal or another source.
Include the source repository, file, commit, license or permission, and a summary
of modifications. Write `None` if the change contains no adapted code.

## Checklist

- [ ] The change is focused and matches the VT7 roadmap.
- [ ] Tests were added or updated where practical.
- [ ] Documentation was updated where behavior or requirements changed.
- [ ] Windows 7 compatibility was tested or the missing test coverage is stated.
- [ ] New dependencies and imported APIs were reviewed for the Windows 7 floor.
- [ ] Third-party provenance and notices are complete.
- [ ] No secrets, private data, generated build output, or unrelated changes are included.
- [ ] No Unicode U+2014 em dash character was added.
