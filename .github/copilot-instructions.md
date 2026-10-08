# Repository context for Copilot / coding agents

- This repo mirrors a researcher's external-drive project folder into `workspace/` via `sync/sync.sh`. Do not hand-edit `workspace/FILES.txt` or `workspace/OVERSIZE.tsv` (generated).
- Language: R is primary (tidyverse, vegan, FD-style functional diversity metrics). Prefer reproducible scripts, `renv`, and relative paths via `here::here()`.
- Outputs may go to USGS / Chesapeake Bay Program partners: state units, methods, and uncertainty explicitly; no silent filtering of sites or taxa.
- Files listed in `workspace/OVERSIZE.tsv` are not in git. Reference them by path and sha256; do not assume they exist in cloud sessions.
- To change what syncs, edit `sync/sync.conf` (paths, size tiers, excludes), not `sync.sh`.
- Never commit credentials, `.env`, or raw data flagged as restricted.
