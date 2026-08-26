#!/usr/bin/env python3
"""Generate and cache the Vietnamese coach TTS evaluation set."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import unicodedata
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

API_URL = "https://api.openai.com/v1/audio/speech"
GENERATOR_VERSION = "1"


def normalize_text(text: str) -> str:
    """Use NFC and collapse Unicode whitespace without changing pronunciation."""
    return re.sub(r"\s+", " ", unicodedata.normalize("NFC", text)).strip()


def cache_material(*, text: str, language: str, profile: str, voice: str,
                   speed: float, provider: str, model: str,
                   experiment_version: str) -> dict:
    return {
        "normalized_text": normalize_text(text),
        "language": language,
        "voice_profile": profile,
        "voice": voice,
        "speed": speed,
        "tts_provider": provider,
        "tts_model": model,
        "version": experiment_version,
    }


def cache_key(material: dict) -> str:
    canonical = json.dumps(material, ensure_ascii=False, sort_keys=True,
                           separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def load_config(path: Path) -> dict:
    config = json.loads(path.read_text(encoding="utf-8"))
    required = {"experiment_version", "language", "provider", "model", "voice",
                "response_format", "profiles", "cues"}
    missing = required - config.keys()
    if missing:
        raise ValueError(f"Missing config fields: {', '.join(sorted(missing))}")
    ids = [cue["id"] for cue in config["cues"]]
    if len(ids) != len(set(ids)):
        raise ValueError("Cue ids must be unique")
    for cue in config["cues"]:
        if cue["profile"] not in config["profiles"]:
            raise ValueError(f"Unknown profile for {cue['id']}: {cue['profile']}")
    return config


def request_audio(api_key: str, payload: dict) -> bytes:
    request = Request(API_URL, data=json.dumps(payload).encode("utf-8"), method="POST",
                      headers={"Authorization": f"Bearer {api_key}",
                               "Content-Type": "application/json"})
    try:
        with urlopen(request, timeout=120) as response:
            return response.read()
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenAI API returned HTTP {error.code}: {detail}") from error
    except URLError as error:
        raise RuntimeError(f"Could not reach OpenAI API: {error.reason}") from error


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=Path(__file__).with_name("cues.json"))
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("output"))
    parser.add_argument("--dry-run", action="store_true", help="Validate and print the manifest only")
    parser.add_argument("--force", action="store_true", help="Regenerate existing cache entries")
    args = parser.parse_args()

    config = load_config(args.config)
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not args.dry_run and not api_key:
        print("OPENAI_API_KEY is not set. Use --dry-run or set it in your shell.", file=sys.stderr)
        return 2

    entries = []
    for cue in config["cues"]:
        profile = config["profiles"][cue["profile"]]
        material = cache_material(
            text=cue["text"], language=config["language"], profile=cue["profile"],
            voice=config["voice"], speed=profile["speed"], provider=config["provider"],
            model=config["model"], experiment_version=config["experiment_version"],
        )
        key = cache_key(material)
        extension = config["response_format"]
        relative_file = f"{cue['profile']}/{cue['id']}--{key[:16]}.{extension}"
        entries.append({"id": cue["id"], "text": cue["text"], "cache_key": key,
                        "cache_material": material, "file": relative_file})

        if args.dry_run:
            continue
        target = args.output / relative_file
        if target.exists() and not args.force:
            print(f"cached  {cue['id']} -> {target}")
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        payload = {"model": config["model"], "voice": config["voice"],
                   "input": normalize_text(cue["text"]), "instructions": profile["instructions"],
                   "speed": profile["speed"], "response_format": extension}
        audio = request_audio(api_key, payload)
        temporary = target.with_suffix(target.suffix + ".tmp")
        temporary.write_bytes(audio)
        temporary.replace(target)
        print(f"created {cue['id']} -> {target}")
        time.sleep(0.2)

    manifest = {"generator_version": GENERATOR_VERSION,
                "experiment_version": config["experiment_version"], "entries": entries}
    if args.dry_run:
        # ASCII escaping keeps dry-run output portable on legacy Windows consoles.
        print(json.dumps(manifest, ensure_ascii=True, indent=2))
    else:
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
