---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
---

# Python

## Toolchain — detect, never assume

Check what the project actually uses before running anything:

- `pyproject.toml` with `[tool.uv]` → `uv run <cmd>`, `uv sync`
- `environment.yml`, or a conda / micromamba environment → activate it first
- `requirements.txt` alone → the project's own venv
- A new project with none of these → default to uv

Never run a bare `python` or `pytest`; it silently picks the wrong interpreter.

## Naming

- Functions, variables, modules: `snake_case`
- Classes: `PascalCase`; constants: `UPPER_SNAKE_CASE`
- A leading underscore means module-private — do not reach across for it
- Never shadow a builtin (`list`, `type`, `sum`, `id`, `input`)

## Errors must stay visible

- No bare `except:`, and no `except Exception: pass`. If an error really is
  ignorable, catch the specific exception and log why it is ignored.
- Never return a default on failure where the caller cannot tell a real value
  from a swallowed error.

## Habits

- Never `from x import *`.
- Imports at the top of the file. A local import needs a comment saying why:
  a cycle, a slow module, an optional dependency.
- No `print` left behind as debugging. Use the project's logger, or delete it.

## Types and version

Match the project's `requires-python`. Where it allows: `X | None` over
`Optional[X]`, stdlib `tomllib`, `pathlib` over `os.path`.
