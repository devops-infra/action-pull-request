#!/usr/bin/env python3
"""Unit tests for split_content_bytes helper script."""

from __future__ import annotations

import pathlib
import subprocess
import tempfile


def read(path: pathlib.Path) -> str:
    """Read UTF-8 text file content."""
    return path.read_text(encoding="utf-8")


def main() -> int:
    """Run split-content helper validations."""
    script = (
        pathlib.Path(__file__).resolve().parents[2]
        / "scripts"
        / "split_content_bytes.py"
    )

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp = pathlib.Path(tmp_dir)
        source = tmp / "source.txt"
        main_out = tmp / "main.txt"
        prefix = str(tmp / "chunk")

        source.write_text(
            "line-01\nline-02\nline-03\nline-04\nline-05\n",
            encoding="utf-8",
        )

        result = subprocess.run(
            [
                "python3",
                str(script),
                str(source),
                str(main_out),
                prefix,
                "14",
                "12",
            ],
            check=True,
            capture_output=True,
            text=True,
        )

        chunk_count = int(result.stdout.strip())
        assert chunk_count >= 1

        combined = read(main_out)
        for index in range(1, chunk_count + 1):
            chunk_file = tmp / f"chunk-{index}.txt"
            assert chunk_file.exists()
            combined += read(chunk_file)

        assert combined == read(source)
        assert len(read(main_out).encode("utf-8")) <= 14
        for index in range(1, chunk_count + 1):
            chunk_file = tmp / f"chunk-{index}.txt"
            assert len(read(chunk_file).encode("utf-8")) <= 12

    print("split-content-bytes tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
