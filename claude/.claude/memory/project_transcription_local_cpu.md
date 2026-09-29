---
name: project_transcription_local_cpu
description: Meeting-recording transcription decided 2026-09-29 to run on ju-TP's CPU, not on ju-TP2's GPU; OpenWhispr rejected, Handy kept for dictation
metadata:
  type: project
---

Transcribing the user's `.3gpp.3ga` meeting recordings was designed on 2026-09-29 and settled as: `faster-whisper` run ephemerally with `uv` on `ju-TP`'s CPU for the batch, Handy (already installed, `canary-1b-v2`, `ctrl+alt+space`) alone for dictation, OpenWhispr not installed, and **no inference delegated to `ju-TP2`'s GPU**. Full reasoning, measurements and rejected ways in `~/dotfiles/.claude/DESIGN-TRANSCRIPTION.md`; do not redo the comparison.

**Why:** the delegation pattern of `~/dotfiles/.claude/DESIGN-GPU-REMOTE.md` (opencode on `ju-TP`, `llama-server` on `ju-TP2`) is the house reflex and will be reproposed by default, but it does not apply here: whisper.cpp publishes no prebuilt CUDA binary for Linux (the Ubuntu release job carries no `GGML_CUDA`, CUDA assets are Windows-only) and `ju-TP2` has no CUDA toolkit, so a GPU path means a toolkit plus a compile or a whole second stack, for a one-off of a few hours of audio. `faster-whisper` also needs no system ffmpeg: its PyAV dependency reads the `3gp` container directly, verified 2026-09-29. Despite the `.3gpp.3ga` extension the recordings are **AAC 48 kHz mono, not AMR-NB 8 kHz**, so there is no narrowband quality ceiling to work around: check the codec before assuming one.

**How to apply:** when transcription comes up again, start from the note rather than from `llama-session`. If the quality disappoints, the next move is a larger model or a `/workflow:reco` on French ASR models, not another topology. If meetings become recurrent rather than one-off, that is when a `bin/transcribe` script with its bats suite earns its place. See [[project_ju_tp2_receiveonly]] for what may never be written on `ju-TP2`.
