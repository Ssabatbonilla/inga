# Drive -> GitHub -> cloud sessions

1. One-time (your computer): `git clone` this repo, edit `sync/sync.conf` (set `SRC` to the external-drive folder), optionally `git lfs install`.
2. Whenever you want cloud sessions to see changes: plug in the drive, run `sync/sync.sh` (add `-n` for a dry run, `--no-push` to commit only).
3. Start a cloud session on this repo; files are under `workspace/`. `workspace/FILES.txt` lists everything; `workspace/OVERSIZE.tsv` lists files too big for git (path, MB, sha256).
4. Copilot reads `.github/copilot-instructions.md`; edit it to change project conventions. Ask Copilot Chat in the terminal (`gh copilot suggest`) or VS Code to tweak `sync.conf`.

Tiers: small -> git, medium -> Git LFS, huge -> OVERSIZE.tsv (+ optional `RCLONE_REMOTE`).
Schedule it: cron `0 * * * * /path/to/repo/sync/sync.sh` (needs drive mounted).
