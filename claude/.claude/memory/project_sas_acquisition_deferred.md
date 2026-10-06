---
name: SAS acquisition researched, decision deferred
description: 2026-10-06 research on getting SAS onto ju-TP (Ubuntu 24.04); no free local SAS exists any more, SAS 9.4 does not support Ubuntu, the only local path is the paid Analytics Pro container; user deferred the decision, the three voies are written up, do not redo the research
metadata:
  type: project
---

On 2026-10-06 the three ways to get SAS on ju-TP were researched in full and the decision was deferred by the user ("on fera ça plus tard").
Voies, concrete steps, host requirements and verified sources: `~/dotfiles/_meta/notes/sas-install-reco.md`.

**Why:** three facts close the space. SAS University Edition ended 2021-08-02, so no free local SAS exists. SAS 9.4 Foundation supports only RHEL, Oracle Enterprise Linux and SLES, never Ubuntu. The only local option left is the paid SAS Analytics Pro container (licence JWT from `my.sas.com`), whose supported host is RHEL 8.10/9.x with Docker Desktop or Podman, so Ubuntu 24.04 is out of support there too. The free path, SAS OnDemand for Academics, is browser-only, non-commercial, and sends data to SAS infrastructure, which rules it out for SNDS or any health data.

**How to apply:** when the subject returns, read the note instead of searching again. The recommendation on hold is: start with OnDemand for Academics to confirm SAS is actually needed, then, if real data is involved, quote SAS France for Analytics Pro and run the container in a Rocky 9 VM (4 GB of the machine's 15) rather than out of support on Ubuntu. Two things need a fresh check at that point: whether a free Altair SLC community edition still exists under Siemens, and the actual quote, since the ~$1,850/year figure comes from third-party aggregators and not from SAS. Same shape as [[project_autoresearch_skill_deferred]]; reading `.sas7bdat` without SAS needs only `haven::read_sas()`.
