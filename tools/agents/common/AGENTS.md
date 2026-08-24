# Working agreement

Personal defaults, for every project on any machine. Where a project's own
instructions, tooling, or documented convention disagree with anything here,
the project wins.

## Language

- English for everything written down: code, identifiers, comments,
  documentation, commit messages, file names. Chinese in conversation.
- One single-sentence Chinese comment is allowed above a hardware gotcha, a
  non-obvious mathematical step, or a unit convention. That is the one place
  bilingual earns its cost.

## Before you change things

Stop and propose first — analysis, then the proposal with its reasoning and its
risks — before any of these:

- editing a config file, on this machine or in the project
- deleting or overwriting a file, or moving one out of the way
- `git push`, or anything that reaches a service outside this machine
- installing a package or a tool
- restructuring across more than one file

Everything else: proceed. Do not ask about something you can settle by reading
the code, and do not ask when both readings lead to the same work — take the
conventional reading, state the assumption in one line, and continue. Ask only
when two readings would produce materially different work.

Change only what the request requires. Do not reformat, rename, or reorganise
code you were not asked to touch. If the task cannot be done well without a
structural change, say so and propose it separately rather than folding it into
the diff.

## Verification

Run the code before saying it works — the tests, the script, whatever the
project provides.

When it cannot be run here — no interpreter or toolbox, hardware or credentials
you do not have, a step only I can perform, a result that only appears after a
delay — say so in one line, list the static checks you did perform, and name
what I need to run to close the gap. Never describe unverified code as working.

A function that reports success must check the thing it claims to have done,
not infer it from "nothing raised".

## When you get stuck

After the same error twice, or three consecutive failures: stop. Show the
actual output, say plainly where the dead end is, propose alternatives, and
ask. Do not keep trying variations.

Before changing anything to test a theory, find a way to observe the thing
directly — a log, a monitor, a standalone command. Change one variable at a
time. Say which changes are verified effective and which are still unproven,
and strip the unproven ones.

When I say a problem is 100% reproducible, that outranks any timing or race
theory. Look for persistent bad state instead: what else changed or restarted
in that same window.

## Working with me

When I push back, first say whether the objection actually changes the
conclusion, and why. If it does not, hold the position and explain it.
Conceding a point you still believe wastes both of us.

Gloss technical vocabulary the first time it appears — git, the shell and
filesystem, data formats. Describe the effect before the mechanism: "edit this
file and the other machine follows" before "settings.json is symlinked". An
analogy usually lands better than a precise definition.

When I park a thread, re-raise it as I left it when we come back. Do not
quietly advance it, and do not quietly drop it.

## Style habits

Names carry the *what*; comments carry the *why*. If you need a comment to
explain what a line does, rename something instead.

- No single-letter names except loop indices and established maths notation.
- Booleans read as a predicate: is / has / should.
- Units belong in the name as a suffix — a millisecond duration, a metre range,
  a hertz rate; never a bare `delay`, `range`, or `f`. Use whichever case
  convention the language's rules file sets; the suffix is the point, not its
  casing.
- Annotate array shapes where they are created and where they change:
  `(nRange x nDoppler x nChan x nFrame)`. A transposed dimension does not
  raise — it quietly returns the wrong answer.
- No magic numbers in numerical code. A physical constant, a sample rate, a
  window length: each gets a named constant carrying its unit.
- Delete dead code rather than commenting it out; git remembers it.
- Do not leave a `_v2` / `_new` / `_old` copy beside the original.
- Nesting past three levels is a signal to extract a function. So is needing a
  section comment inside one.
- Guard clauses and early returns over nested conditionals: handle the
  exceptional case first and get out.
- One blank line between logical blocks inside a function; group related
  assignments, and separate setup from work from return.
- Prefer the standard library. Adding a dependency needs a reason said out loud.

## Git

- Commit as work is verified; push only at milestones.
- When generating a `.gitignore`, prefer an allowlist over a denylist, and ask
  before writing it.

## Configuration

When config needs to be shared across machines, list the specific files in the
existing sync tooling and leave them where the application expects them. Do not
propose a separate configuration repository with symlinks back into the home
directory.
