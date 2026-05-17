#!/usr/bin/env python3
"""Split UTF-8 text into byte-bounded main body and overflow chunks."""

from __future__ import annotations

import pathlib
import sys


def take_prefix_by_bytes(text: str, max_bytes: int) -> tuple[str, str]:
    """Return the largest UTF-8 prefix not exceeding max_bytes and the tail."""
    if max_bytes <= 0 or not text:
        return "", text

    used = 0
    index = 0
    for i, char in enumerate(text):
        size = len(char.encode("utf-8"))
        if used + size > max_bytes:
            break
        used += size
        index = i + 1
    return text[:index], text[index:]


def split_chunks(text: str, max_bytes: int) -> list[str]:
    """Split text into UTF-8 chunks bounded by max_bytes."""
    chunks: list[str] = []
    remaining = text

    while remaining:
        chunk, tail = take_prefix_by_bytes(remaining, max_bytes)
        if not chunk:
            # Fallback for invalid max_bytes/encoding edge cases.
            chunk = remaining[:1]
            tail = remaining[1:]

        if tail and "\n" in chunk:
            cut_index = chunk.rfind("\n") + 1
            if cut_index > 0:
                tail = chunk[cut_index:] + tail
                chunk = chunk[:cut_index]

        chunks.append(chunk)
        remaining = tail

    return chunks


def main() -> int:
    """Parse arguments, split input content, and write chunk files."""
    if len(sys.argv) != 6:
        print(
            "Usage: split_content_bytes.py <input_file> <main_output_file>"
            " <chunk_prefix> <max_main_bytes> <max_chunk_bytes>",
            file=sys.stderr,
        )
        return 1

    input_file = pathlib.Path(sys.argv[1])
    main_output_file = pathlib.Path(sys.argv[2])
    chunk_prefix = sys.argv[3]
    max_main_bytes = int(sys.argv[4])
    max_chunk_bytes = int(sys.argv[5])

    if max_main_bytes <= 0 or max_chunk_bytes <= 0:
        print(
            "max_main_bytes and max_chunk_bytes must be greater than zero",
            file=sys.stderr,
        )
        return 1

    content = input_file.read_text(encoding="utf-8")

    main_body, overflow = take_prefix_by_bytes(content, max_main_bytes)
    main_output_file.write_text(main_body, encoding="utf-8")

    chunks = split_chunks(overflow, max_chunk_bytes)
    for index, chunk in enumerate(chunks, start=1):
        pathlib.Path(f"{chunk_prefix}-{index}.txt").write_text(chunk, encoding="utf-8")

    print(len(chunks))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
