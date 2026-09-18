

## Publication safety

Before every commit or push, run `python3 .agents/publication-safety/guard.py scan --repo . --scope all`; resolve findings without printing values. Never bypass hooks with `--no-verify`. Before public release, run the independent history scanner and review non-code surfaces.
