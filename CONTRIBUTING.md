# Contributing

Thanks for looking. Batteries Not Included is open: everything that decides a match is in this
repository.

## Licences

- **Code** is under the GNU General Public License v3.0 or later (GPL-3.0-or-later). By
  contributing code you agree to license it that way.
- **Art and sound** (`assets/`, `art/`) are under Creative Commons Attribution-ShareAlike 4.0
  (CC BY-SA 4.0).
- **Third-party code** keeps its own licence: `addons/gut` is MIT.

## Contributor agreement

A contributor licence agreement (CLA) will be required before any outside pull request is
merged. It lets us ship the same code in builds the GPL does not fit, like some app stores,
and it promises the code stays available under the GPL. The text is coming; until it is
published, outside pull requests can be opened and reviewed but not merged.

## How to work

- Godot 4.7.2, typed GDScript, the Compatibility renderer.
- **The sim decides, the view draws.** Rules go in `src/sim/`, reading every number from the
  ruleset. Read [docs/architecture.md](docs/architecture.md) first.
- **No numbers in rules code.** A new tuning value is a row in `RulesetSchema`, a field on
  `Ruleset` and a line in `data/rulesets/standard/`.
- **Tests.** Run `tools/test.sh` before you push. A rule change comes with a test that proves
  it, named after the criterion it meets.
- **Commits.** Conventional commits, lowercase: `feat(sim): ...`, `fix(view): ...`.
- **Nothing from other games.** Our code, art, sound, names and maps are our own.
