import argparse
import base64
import json
import mimetypes
import os
import sys
import textwrap
from pathlib import Path

import anthropic

MODEL = "claude-sonnet-4-20250514"
MAX_TOKENS = 1000

SYSTEM_PROMPT = (
    "You are a fashion stylist and virtual try-on assistant. "
    "When given a photo of a person and a clothing item, you provide a vivid, "
    "detailed, and helpful try-on analysis. Structure your response in clear "
    "sections using markdown headers (##). Cover: Overall Look, Fit & Silhouette, "
    "Color Harmony, Style Notes, and Styling Tips. "
    "Be specific, warm, and fashion-forward. Use evocative language."
)

USER_TEXT = (
    "The first image is the person. The second image is the clothing item they "
    "want to try on. Please provide a detailed virtual try-on analysis — how would "
    "this outfit look on them? Describe the overall look, fit, color harmony, and "
    "give styling tips."
)

SECTIONS = [
    "Overall Look",
    "Fit & Silhouette",
    "Color Harmony",
    "Style Notes",
    "Styling Tips",
]

def load_image(path: str) -> tuple[str, str]:
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Image not found: {path}")
    mime_type, _ = mimetypes.guess_type(str(path))
    if not mime_type or not mime_type.startswith("image/"):
        mime_type = "image/jpeg"  # safe fallback

    with open(path, "rb") as f:
        data = base64.standard_b64encode(f.read()).decode("utf-8")
    return data, mime_type
def build_message_content(
    person_b64: str,
    person_mime: str,
    clothing_b64: str,
    clothing_mime: str,
) -> list[dict]:

    return [
        {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": person_mime,
                "data": person_b64,
            },
        },
        {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": clothing_mime,
                "data": clothing_b64,
            },
        },
        {
            "type": "text",
            "text": USER_TEXT,
        },
    ]

def call_claude(person_path: str, clothing_path: str) -> str:

    client = anthropic.Anthropic()
    person_b64, person_mime = load_image(person_path)
    clothing_b64, clothing_mime = load_image(clothing_path)
    message = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        system=SYSTEM_PROMPT,
        messages=[
            {
                "role": "user",
                "content": build_message_content(
                    person_b64, person_mime, clothing_b64, clothing_mime
                ),
            }
        ],
    )

    return "\n".join(
        block.text for block in message.content if hasattr(block, "text")
    )

def parse_sections(text: str) -> list[dict]:
    """
    Split the markdown response into named sections.
    Returns a list of {"title": str | None, "body": str} dicts.
    """
    sections = []
    current_title = None
    current_lines = []

    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("## "):
            if current_lines or current_title:
                sections.append(
                    {"title": current_title, "body": "\n".join(current_lines).strip()}
                )
            current_title = stripped[3:].strip()
            current_lines = []
        elif stripped.startswith("# "):
            if current_lines or current_title:
                sections.append(
                    {"title": current_title, "body": "\n".join(current_lines).strip()}
                )
            current_title = stripped[2:].strip()
            current_lines = []
        else:
            current_lines.append(line)

    if current_lines or current_title:
        sections.append(
            {"title": current_title, "body": "\n".join(current_lines).strip()}
        )

    return [s for s in sections if s["body"]]


def format_terminal(sections: list[dict]) -> str:
    """Render sections as readable terminal output."""
    width = min(os.get_terminal_size(fallback=(80, 24)).columns, 80)
    lines = []
    lines.append("=" * width)
    lines.append("  VIRTUAL TRY-ON ANALYSIS")
    lines.append("=" * width)

    for sec in sections:
        if sec["title"]:
            lines.append("")
            lines.append(f"▸ {sec['title'].upper()}")
            lines.append("-" * (len(sec["title"]) + 2))

        wrapped = textwrap.fill(sec["body"], width=width)
        lines.append(wrapped)

    lines.append("")
    lines.append("=" * width)
    return "\n".join(lines)

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Virtual Try-On: analyse how a clothing item would look on a person.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(
            """
            Examples:
              python virtual_tryon.py --person me.jpg --clothing tshirt.png
              python virtual_tryon.py --person me.jpg --clothing tshirt.png --json
              python virtual_tryon.py --person me.jpg --clothing tshirt.png --output result.txt

            Environment:
              ANTHROPIC_API_KEY   Your Anthropic API key (required)
            """
        ),
    )
    parser.add_argument("--person", required=True, help="Path to person image")
    parser.add_argument("--clothing", required=True, help="Path to clothing item image")
    parser.add_argument("--output", help="Save result to this file path (optional)")
    parser.add_argument(
        "--json", dest="as_json", action="store_true",
        help="Output as JSON (array of section objects)"
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("ERROR: ANTHROPIC_API_KEY environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    print("Sending images to Claude for analysis…", file=sys.stderr)

    try:
        raw = call_claude(args.person, args.clothing)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except anthropic.APIError as e:
        print(f"API ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    sections = parse_sections(raw)

    if args.as_json:
        output = json.dumps(sections, indent=2, ensure_ascii=False)
    else:
        output = format_terminal(sections)

    print(output)

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
        print(f"\nResult saved to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()