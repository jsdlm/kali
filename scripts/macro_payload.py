#!/usr/bin/env python3
"""
Split a long encoded string into VBA-friendly concatenated chunks.

Usage:
    python macro_payload.py <encoded_string> [--chunk-size N] [--var-name NAME]
    echo "SQBFAFg..." | python macro_payload.py - [--chunk-size N] [--var-name NAME]
"""

import argparse
import sys


def split_payload(payload: str, chunk_size: int, var_name: str) -> list[str]:
    if not payload:
        raise ValueError("Payload string is empty.")
    if chunk_size < 1:
        raise ValueError("Chunk size must be at least 1.")

    lines = []
    first = True
    for i in range(0, len(payload), chunk_size):
        chunk = payload[i : i + chunk_size]
        if first:
            lines.append(f'{var_name} = "{chunk}"')
            first = False
        else:
            lines.append(f'{var_name} = {var_name} & "{chunk}"')
    return lines


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Split an encoded payload string into VBA macro-friendly chunks.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "payload",
        help='Encoded string to split, or "-" to read from stdin.',
    )
    parser.add_argument(
        "--chunk-size",
        "-n",
        type=int,
        default=50,
        metavar="N",
        help="Characters per chunk (default: 50).",
    )
    parser.add_argument(
        "--var-name",
        "-v",
        default="Str",
        metavar="NAME",
        help="VBA variable name to use (default: Str).",
    )
    parser.add_argument(
        "--output",
        "-o",
        metavar="FILE",
        help="Write output to FILE instead of stdout.",
    )

    args = parser.parse_args()

    # Read from stdin if "-" is passed
    if args.payload == "-":
        if sys.stdin.isatty():
            parser.error('No data piped to stdin. Provide a payload or pipe data with "-".')
        payload = sys.stdin.read().strip()
    else:
        payload = args.payload.strip()

    if not payload:
        parser.error("Payload is empty after stripping whitespace.")

    if '"' in payload:
        print(
            "[!] Warning: payload contains double-quotes — they will break VBA string literals.",
            file=sys.stderr,
        )

    try:
        lines = split_payload(payload, args.chunk_size, args.var_name)
    except ValueError as exc:
        parser.error(str(exc))

    output = "\n".join(lines)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output + "\n")
        print(f"[+] Written {len(lines)} lines to {args.output}", file=sys.stderr)
    else:
        print(output)

    print(
        f"[*] {len(payload)} chars → {len(lines)} chunks of ≤{args.chunk_size}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
