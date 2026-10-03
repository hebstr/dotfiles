#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#   "faster-whisper==1.2.1",
#   "av>=18,<19",
#   "numpy",
#   "pyannote.audio>=4,<5",
#   "torch",
#   "torchaudio",
# ]
#
# [[tool.uv.index]]
# name = "pytorch-cpu"
# url = "https://download.pytorch.org/whl/cpu"
# explicit = true
#
# [tool.uv.sources]
# torch = { index = "pytorch-cpu" }
# torchaudio = { index = "pytorch-cpu" }
# ///

"""Transcribe and diarize one recording, as the two stages the `transcribe` driver calls.

`asr` decodes the audio with faster-whisper and writes `<base>.json` and
`<base>.txt`, the transcript carrying the `[MM:SS.d]` lines of the 2026-09-29
pass. `diarize` reads that json back, runs pyannote on the same audio, and
rewrites both files with the speaker labels merged in, so it can be rerun
without decoding again.

Every heavy import sits inside its stage, which leaves the merge, the timestamp
rendering, the label renumbering and the target naming runnable under a bare
interpreter.

Usage:
    transcribe-payload.py asr --audio rec.3gpp.3ga --device cuda --compute-type float16
    transcribe-payload.py diarize --audio rec.3gpp.3ga --speakers 3
    transcribe-payload.py asr --audio rec.3gpp.3ga --print-target
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from collections.abc import Sequence

### DEFAULTS ----

ASR_MODEL = "dropbox-dash/faster-whisper-large-v3-turbo"
DIARIZE_MODEL = "pyannote/speaker-diarization-community-1"
LANGUAGE = "fr"
BEAM_SIZE = 5
MIN_SILENCE_MS = 1000
SPEECH_PAD_MS = 300
SAMPLE_RATE = 16000
PROGRESS_EVERY = 25

AUDIO_SUFFIXES = frozenset(
    {
        ".3ga",
        ".3gp",
        ".3gpp",
        ".aac",
        ".flac",
        ".m4a",
        ".mp3",
        ".mp4",
        ".ogg",
        ".opus",
        ".wav",
        ".wma",
    }
)


### PURE HELPERS ----


def stamp(seconds: float) -> str:
    """Render a segment start as `[MM:SS.d]`."""
    return f"[{int(seconds // 60):02d}:{seconds % 60:04.1f}]"


def target_base(audio: Path, out_dir: Path | None) -> Path:
    """Name the outputs after the audio stripped of its audio suffixes."""
    stem = audio.name
    while Path(stem).suffix.lower() in AUDIO_SUFFIXES:
        stem = Path(stem).stem
    return (out_dir or audio.parent) / stem


def overlap(start: float, end: float, other_start: float, other_end: float) -> float:
    """Length of time shared by two intervals."""
    return max(0.0, min(end, other_end) - max(start, other_start))


def assign_speakers(
    segments: Sequence[dict[str, Any]], turns: Sequence[dict[str, Any]]
) -> list[str | None]:
    """Give each segment the raw speaker whose turns cover most of it, or None."""
    assigned: list[str | None] = []
    for segment in segments:
        shares: dict[str, float] = {}
        for turn in turns:
            shared = overlap(segment["start"], segment["end"], turn["start"], turn["end"])
            if shared > 0:
                shares[turn["speaker"]] = shares.get(turn["speaker"], 0.0) + shared
        assigned.append(max(shares, key=lambda speaker: shares[speaker]) if shares else None)
    return assigned


def renumber(assigned: Sequence[str | None], turns: Sequence[dict[str, Any]]) -> dict[str, str]:
    """Map the raw pyannote labels to `S1..Sn` by order of first appearance."""
    order: list[str] = []
    for speaker in assigned:
        if speaker is not None and speaker not in order:
            order.append(speaker)
    for turn in sorted(turns, key=lambda turn: turn["start"]):
        if turn["speaker"] not in order:
            order.append(turn["speaker"])
    return {speaker: f"S{n}" for n, speaker in enumerate(order, start=1)}


def render(segments: Sequence[dict[str, Any]], labels: Sequence[str | None] | None) -> str:
    """Render the transcript, one `[MM:SS.d] S1: text` line per segment."""
    lines = []
    for n, segment in enumerate(segments):
        label = labels[n] if labels is not None else None
        prefix = f"{stamp(segment['start'])} "
        lines.append(
            f"{prefix}{label}: {segment['text']}" if label else f"{prefix}{segment['text']}"
        )
    return "".join(f"{line}\n" for line in lines)


### INPUT AND OUTPUT ----


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def write_outputs(base: Path, record: dict[str, Any], labels: Sequence[str | None] | None) -> None:
    """Write `<base>.json` and `<base>.txt` from one record."""
    Path(f"{base}.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    Path(f"{base}.txt").write_text(render(record["segments"], labels), encoding="utf-8")


def decode_waveform(audio: Path, threads: int) -> Any:
    """Decode the audio to the in-memory tensor pyannote 4 asks for."""
    import av
    import numpy as np
    import torch

    container = av.open(str(audio))
    resampler = av.AudioResampler(format="s16", layout="mono", rate=SAMPLE_RATE)
    blocks: list[Any] = []
    for frame in container.decode(container.streams.audio[0]):
        for resampled in resampler.resample(frame):
            blocks.append(resampled.to_ndarray().reshape(-1))
    container.close()
    samples = np.concatenate(blocks).astype(np.float32) / 32768.0
    torch.set_num_threads(threads)
    return torch.from_numpy(samples).unsqueeze(0)


### STAGES ----


def run_asr(args: argparse.Namespace) -> int:
    """Decode one recording and write the unlabelled transcript."""
    from faster_whisper import WhisperModel

    base = target_base(args.audio, args.out_dir)
    log(f"loading {args.model} on {args.device} ({args.compute_type}, {args.threads} threads)")
    model = WhisperModel(
        args.model,
        device=args.device,
        compute_type=args.compute_type,
        cpu_threads=args.threads,
    )
    vad_parameters = (
        None
        if args.no_vad
        else {"min_silence_duration_ms": args.min_silence, "speech_pad_ms": args.speech_pad}
    )
    stream, info = model.transcribe(
        str(args.audio),
        language=args.language,
        beam_size=args.beam_size,
        vad_filter=not args.no_vad,
        vad_parameters=vad_parameters,
        condition_on_previous_text=False,
    )
    log(f"{args.audio.name}: {info.duration / 60:.1f} min, decoding to {base}.txt")

    started = time.monotonic()
    segments: list[dict[str, Any]] = []
    for segment in stream:
        segments.append({"start": segment.start, "end": segment.end, "text": segment.text.strip()})
        if len(segments) % PROGRESS_EVERY == 0:
            share = segment.end / info.duration if info.duration else 0.0
            log(f"  {len(segments)} segments, {share:.0%} of the audio")
    elapsed = time.monotonic() - started

    record = {
        "audio": args.audio.name,
        "model": args.model,
        "language": info.language,
        "duration": info.duration,
        "device": args.device,
        "compute_type": args.compute_type,
        "segments": segments,
    }
    write_outputs(base, record, None)
    speed = info.duration / elapsed if elapsed else 0.0
    log(f"{base.name}: {len(segments)} segments in {elapsed / 60:.1f} min, {speed:.2f} x realtime")
    return 0


def run_diarize(args: argparse.Namespace) -> int:
    """Label the segments of an existing transcript with pyannote turns."""
    from pyannote.audio import Pipeline

    base = target_base(args.audio, args.out_dir)
    source = Path(f"{base}.json")
    if not source.is_file():
        log(f"no transcript to label at {source}, run asr first")
        return 1
    record = json.loads(source.read_text(encoding="utf-8"))

    waveform = decode_waveform(args.audio, args.threads)
    duration = waveform.shape[1] / SAMPLE_RATE
    log(f"{args.audio.name}: {duration / 60:.1f} min decoded, loading {args.model}")
    pipeline = Pipeline.from_pretrained(args.model)
    if pipeline is None:
        log(f"{args.model} did not load; the Hugging Face gate may not be accepted")
        return 1

    started = time.monotonic()
    asked = {"num_speakers": args.speakers} if args.speakers else {}
    output = pipeline({"waveform": waveform, "sample_rate": SAMPLE_RATE}, **asked)
    elapsed = time.monotonic() - started
    turns = [
        {"start": span.start, "end": span.end, "speaker": speaker}
        for span, _, speaker in output.exclusive_speaker_diarization.itertracks(yield_label=True)
    ]
    found = sorted({turn["speaker"] for turn in turns})
    log(
        f"{len(turns)} turns, {len(found)} speakers, in {elapsed / 60:.1f} min, "
        f"{duration / elapsed if elapsed else 0.0:.2f} x realtime"
    )
    if args.speakers and len(found) != args.speakers:
        log(f"warning: {args.speakers} speakers asked, {len(found)} returned by the audio")

    assigned = assign_speakers(record["segments"], turns)
    labels = renumber(assigned, turns)
    record["diarization"] = {
        "model": args.model,
        "speakers_asked": args.speakers,
        "speakers_found": len(found),
        "labels": labels,
        "turns": [{**turn, "label": labels[turn["speaker"]]} for turn in turns],
    }
    renumbered = [labels[speaker] if speaker is not None else None for speaker in assigned]
    unlabelled = sum(1 for label in renumbered if label is None)
    if unlabelled:
        log(f"{unlabelled} of {len(renumbered)} segments overlap no turn and stay unlabelled")
    write_outputs(base, record, renumbered)
    log(f"{base.name}: labels written for {len(record['segments'])} segments")
    return 0


### COMMAND LINE ----


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Transcribe and diarize one recording.")
    stages = parser.add_subparsers(dest="stage", required=True)

    asr = stages.add_parser("asr", help="decode the audio and write the transcript")
    asr.add_argument("--audio", required=True, type=Path)
    asr.add_argument("--out-dir", type=Path, default=None)
    asr.add_argument("--print-target", action="store_true", help="print the output base and exit")
    asr.add_argument("--model", default=ASR_MODEL)
    asr.add_argument("--language", default=LANGUAGE)
    asr.add_argument("--device", default="cpu", choices=("cpu", "cuda"))
    asr.add_argument("--compute-type", default="int8")
    asr.add_argument("--threads", type=int, default=12)
    asr.add_argument("--beam-size", type=int, default=BEAM_SIZE)
    asr.add_argument("--min-silence", type=int, default=MIN_SILENCE_MS)
    asr.add_argument("--speech-pad", type=int, default=SPEECH_PAD_MS)
    asr.add_argument("--no-vad", action="store_true")
    asr.add_argument("--force", action="store_true", help="overwrite an existing transcript")

    diarize = stages.add_parser("diarize", help="label the transcript with speaker turns")
    diarize.add_argument("--audio", required=True, type=Path)
    diarize.add_argument("--out-dir", type=Path, default=None)
    diarize.add_argument("--model", default=DIARIZE_MODEL)
    diarize.add_argument("--speakers", type=int, default=None)
    diarize.add_argument("--threads", type=int, default=12)

    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)

    if args.stage == "asr" and args.print_target:
        print(target_base(args.audio, args.out_dir))
        return 0

    if not args.audio.is_file():
        log(f"not a file: {args.audio}")
        return 1
    speakers = getattr(args, "speakers", None)
    if speakers is not None and speakers < 1:
        log(f"--speakers must be 1 or more, got {speakers}")
        return 1
    if args.out_dir is not None:
        args.out_dir.mkdir(parents=True, exist_ok=True)

    if args.stage == "asr":
        base = target_base(args.audio, args.out_dir)
        clashes = [p for p in (Path(f"{base}.json"), Path(f"{base}.txt")) if p.exists()]
        if clashes and not args.force:
            log(f"exists, pass --force to overwrite: {', '.join(str(p) for p in clashes)}")
            return 1
        return run_asr(args)
    return run_diarize(args)


if __name__ == "__main__":
    sys.exit(main())
