---
paths:
  - "**/*.m"
  - "**/*.mlx"
---

# MATLAB

## Toolchain — detect, never assume

Check what is actually available on this machine before claiming anything:

- Is there a `matlab` on PATH, and which release?
- Which toolboxes does the code need, and does `ver` show them?
- Is Octave a usable fallback, and does the code stay inside what it supports?

If MATLAB is not available here, follow the verification rule in AGENTS.md:
say so, and do not describe the code as working.

## Naming

- Functions and variables: `camelCase` (`rangeFFT`, `slowTimeIdx`)
- Classes: `PascalCase`, in `@ClassName/` folders
- A function's name must match its file name

## Errors must stay visible

- Use `error("pkg:id", ...)` with an identifier rather than a bare
  `error("...")`, so callers can match on it.
- No `try` / `catch` wrapped around a whole block that only prints and
  continues.
- Check dimensions and index bounds explicitly. Implicit expansion silently
  producing a wrong-sized result is the failure mode that costs the most here.

## Habits

- One function per file for anything called from elsewhere; local functions
  only for helpers used in that same file.
- No `disp` / `fprintf` left behind as debugging.
- Vectorise, but not past the point where a reader can still follow the
  dimensions.
