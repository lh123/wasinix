# First-time setup

What a fresh machine needs before the wasinix CLI is fully useful, in the order
it comes up. `wasinix doctor` prints where you stand at any point.

## The CLI

`nix develop` puts `wasinix` on PATH; outside a dev shell,
`nix run .#wasinix -- <args>` is the same binary. Shell completions come from
`wasinix completions <shell>` (the dev shell installs them).

## Builders

Heavy builds go to a remote builder, never the local machine
(`docs/building.md`). `wasinix remote init` writes a commented `builders.toml`
template to `$XDG_CONFIG_HOME/wasinix/`; fill in a remote profile and verify it
with `wasinix remote doctor --ifd`. The `[local]` table in the same file holds
persistent local limits (`max_jobs`, `eval_workers`, `eval_memory`, and a
`capacity` bounding concurrent local runs).

## Push credentials

`NIX_SIGNING_KEY` plus S3 credentials (`AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`) let a build push to the shared cache; internal
contributors get them from the doppler `nix-builder` project. Everything builds
without them; with them, `--push-cache` and `wasinix cache push` save the next
CI run billable minutes (`docs/building.md`).

## The job catalog

Selector tab completion and `wasinix jobs` read a catalog the first `build`,
`spot`, or `diff` records as its evaluation finishes. Until then both report an
empty catalog by design.

## For agents

On first wasinix use in an environment, run `wasinix doctor` and read the table
instead of probing by trial and error. Ask the user only for what the machine
cannot answer: which remote to build on, and whether they hold the push
credentials; save both answers to memory, per the "ask where to build once" rule
in `docs/building.md`. Do not read the CLI's source to learn its behavior;
`--help` on any verb and the docs table in `README.md` are the supported
surfaces.
