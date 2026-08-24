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

## Project documents

Four kinds of document, each answering a different question. **Not every project
needs all four** — create one only when there is something to put in it. What
matters is that when I ask you to write or maintain "the doc", you reach for the
right one instead of inventing a fifth.

| Document | Answers | Written for |
|---|---|---|
| `README.md` | How do I use this? | someone who just wants it to work |
| `DESIGN.md` | Why is it built this way? | someone about to change it |
| `devlog.md` | What went wrong getting here, and what did we already try? | a future session re-deriving a decision |
| `notes/<topic>.md` | What did I already decide about this one thing? | you, before proposing something I rejected |

**`README.md`** — usage. Install, run, the handful of commands that matter. No
rationale; if a reader has to understand the design to use it, that is a design
problem, not a documentation problem.

**`DESIGN.md`** — the shape of the thing and the principles behind it. Written
before or alongside the work: goals, scope, the constraints that fix the design,
and the rules that follow from them. Stable — it changes when the design changes,
not when the code does.

**`devlog.md`** — the development log, and the most valuable of the four, because
it is the only one that records what *did not* work:

- an alternative that was evaluated and rejected, with the reason
- a bug whose obvious explanation turned out to be wrong, and how that was found
- a constraint discovered the hard way

Append as the work happens. Never tidy history out of it: a theory that was later
disproved is exactly the content worth keeping — mark it corrected, do not delete
it. Someone who does not know an approach was already tried will try it again.

**`notes/<topic>.md`** — one file per topic, holding decisions already made so
they are not re-litigated. **Maintain these without asking me.** Read the
relevant file before proposing anything in that area; once I confirm a judgement,
append it with its date and its reason. This is the one document you own outright.

### When to write

The trigger is: **would this have to be re-derived otherwise?** If a future
session would burn the same hour reaching the same conclusion, write it down. If
not, do not.

Do not ask "should I update the docs?" at the end of a task — either the trigger
fired or it did not, and you can tell which. Asking every time turns into a
ritual I answer "no" to, which kills the convention.

Do not duplicate across the four. Version history is `git log`, not a changelog
section. Usage is `README.md`, not a comment block. When two of them would say
the same thing, the more specific one says it and the other links to it.

## Git

- Commit as work is verified; push only at milestones.
- When generating a `.gitignore`, prefer an allowlist over a denylist, and ask
  before writing it.

## Configuration

When config needs to be shared across machines, list the specific files in the
existing sync tooling and leave them where the application expects them. Do not
propose a separate configuration repository with symlinks back into the home
directory.
