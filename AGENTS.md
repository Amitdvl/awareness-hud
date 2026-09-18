

## Publication safety

Before every commit or push, run `python3 .agents/publication-safety/guard.py scan --repo . --scope all`; resolve findings without printing values. Never bypass hooks with `--no-verify`. Before public release, run an independent history-capable secret scanner, the official `codex-security:security-scan` against the frozen candidate, and review non-code surfaces.
