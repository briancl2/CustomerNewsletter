import argparse
import re
import sys
from pathlib import Path


def _error(message: str) -> None:
	sys.stderr.write(f"[ERROR] validate_skill.py: {message}\n")


def _validate_frontmatter(skill_md_content: str) -> bool:
	"""Perform minimal frontmatter validation for SKILL.md."""
	if not skill_md_content.lstrip().startswith("---"):
		_error("SKILL.md must start with YAML frontmatter ('---')")
		return False

	# Extract the first frontmatter block.
	parts = skill_md_content.split("---", 2)
	if len(parts) < 3:
		_error("SKILL.md frontmatter block is not properly closed with '---'")
		return False

	frontmatter = parts[1]
	ok = True

	if not re.search(r"^name:\s*\S+", frontmatter, flags=re.MULTILINE):
		_error("Frontmatter missing required field: name")
		ok = False
	if not re.search(r"^description:\s*.+", frontmatter, flags=re.MULTILINE):
		_error("Frontmatter missing required field: description")
		ok = False

	return ok


def validate_skill_dir(skill_dir: Path) -> bool:
	"""Minimal validation for a skill directory."""
	ok = True

	if not skill_dir.exists():
		_error(f"Skill directory does not exist: {skill_dir}")
		return False
	if not skill_dir.is_dir():
		_error(f"Skill path is not a directory: {skill_dir}")
		return False

	skill_md = skill_dir / "SKILL.md"
	if not skill_md.is_file():
		_error(f"Missing SKILL.md: {skill_md}")
		ok = False
	else:
		try:
			content = skill_md.read_text(encoding="utf-8")
		except OSError as exc:
			_error(f"Failed to read SKILL.md: {exc}")
			ok = False
		else:
			if not content.strip():
				_error(f"SKILL.md is empty: {skill_md}")
				ok = False
			else:
				ok = _validate_frontmatter(content) and ok

	return ok


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Validate a GitHub skill directory (minimal checks).")
	parser.add_argument("skill_dir", type=Path, help="Path to the skill directory to validate")
	return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
	args = _parse_args(argv)
	skill_dir: Path = args.skill_dir

	if validate_skill_dir(skill_dir):
		print(f"[OK] Skill validation passed for: {skill_dir}")
		return 0

	return 1


if __name__ == "__main__":
	raise SystemExit(main())
