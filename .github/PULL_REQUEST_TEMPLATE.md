## Summary

What does this change, and what user or engineering problem does it solve?

## Related issues

Closes #

## Scope and priority

Which roadmap checkpoint or required workflow does this serve? Explain whether
it fixes a port/release blocker or is an approved optional improvement. Record
new non-blocking observations in Milestone 7 with evidence and follow-up, rather
than expanding this change. Identify any intentional departure from upstream.

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
- Exact build configuration/native ABI, artifact filename and SHA256 where available.
- Test profile, process exit status, complete/partial/not-run evidence, and retained failures.
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
- [ ] The development handoff and relevant validation record distinguish implemented work, verified results, open failures and the next task.
- [ ] Windows 7 compatibility was tested or the missing test coverage is stated.
- [ ] New dependencies and imported APIs were reviewed for the Windows 7 floor.
- [ ] Third-party provenance and notices are complete.
- [ ] No secrets, private data, generated build output, or unrelated changes are included.
- [ ] No Unicode U+2014 em dash character was added.
