# How I write VT7 documentation

I write the project documentation in first person, as the person making the
decisions and doing the hands-on testing. I want it to read like clear working
notes for a serious project: direct, specific, and easy to use.

## Voice

- Use "I chose", "I tested", and "I still need to verify" for my decisions,
  observations, and unfinished work. Avoid referring to me as "the owner",
  "the user", or "the tester".
- Keep technical facts direct: "VT7 requires .NET Framework 4.8."
  Do not force every sentence into first person.
- Attribute evidence accurately. "The automated checks passed" is different
  from "I tested resizing on LEOPARD." Do not turn automation or someone else's
  observations into a claim that I personally performed the work.
- Address readers directly in procedures: "Run the launcher" and "Keep the
  complete Logs directory." State prerequisites, expected results, and evidence
  to collect before background detail.
- Explain decisions and limitations in plain language. Keep exact technical
  terms when they carry meaning, including file ownership and session ownership.
- Do not use em dashes (Unicode U+2014). Use a comma, colon, parentheses, a
  normal hyphen, or a new sentence.

## Structure

Keep the README introductory, the handoff focused on the next action, and the
roadmap focused on delivery requirements. Put detailed contracts in architecture
documents and results in dated validation records. Link to their primary home
instead of copying the same history into every page.

Lead a validation record with its outcome and scope. Separate automated results
from my live observations. Then record the environment, exact package identity,
procedure, failures and corrections, evidence, and remaining limits. An older
failed candidate stays failed after its successor passes.

Use short paragraphs, meaningful headings, and tables for comparisons. A
technical specification may need substantial detail; organize it so readers
can find that detail without reading every historical checkpoint first.

## Evidence and attribution

Preserve versions, hashes, commands, measured results, citations, and uncertainty.
Keep raw logs, transcripts, quoted source material, upstream documentation, and
license text verbatim. First-person project prose does not change their authorship.

Issued ZIPs, manifests, and test evidence are immutable records. Later editorial
changes apply to source documentation and future packages. Describe source-hash
comparisons as issue-time checks when documenting a frozen candidate.
