#!/usr/bin/env bash
# Mirror an external-drive folder into this repo and push, so cloud sessions can see it.
# Usage: sync/sync.sh [-n|--dry-run] [--no-push] [-m "message"] [-c path/to/sync.conf]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$REPO/sync/sync.conf"; DRY=0; PUSH=1; MSG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY=1 ;;
    --no-push)    PUSH=0 ;;
    -m)           MSG="$2"; shift ;;
    -c)           CONF="$2"; shift ;;
    -h|--help)    sed -n '2,3p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac; shift
done

# shellcheck disable=SC1090
source "$CONF"
DEST="$REPO/$DEST_SUBDIR"
[[ -d "$SRC" ]] || { echo "SRC not found (is the drive mounted?): $SRC" >&2; exit 1; }
cd "$REPO"; mkdir -p "$DEST"

HAVE_LFS=0; git lfs version >/dev/null 2>&1 && HAVE_LFS=1
sha() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
size_mb() { echo $(( ($(wc -c < "$1") + 1048575) / 1048576 )); }

# 1. Mirror (additive: never deletes in the repo)
excluded() { # match any path component against EXCLUDES (rsync-style, simplified)
  local rel="$1" pat part
  for pat in "${EXCLUDES[@]}"; do
    pat="${pat%/}"
    IFS=/ read -ra parts <<< "$rel"
    for part in "${parts[@]}"; do [[ $part == $pat ]] && return 0; done
  done; return 1
}
echo ">> mirroring $SRC/ -> $DEST/"
if command -v rsync >/dev/null; then
  RS=(-a --update --prune-empty-dirs --exclude="OVERSIZE.tsv" --exclude="FILES.txt")
  for p in "${EXCLUDES[@]}"; do RS+=(--exclude="$p"); done
  [[ $DRY -eq 1 ]] && RS+=(-n -v)
  rsync "${RS[@]}" "$SRC/" "$DEST/"
else  # fallback for Git Bash / minimal systems without rsync
  echo "(rsync not found; using cp fallback)"
  while IFS= read -r -d '' f; do
    rel="${f#"$SRC"/}"; excluded "$rel" && continue
    if [[ $DRY -eq 1 ]]; then echo "$rel"; continue; fi
    [[ "$f" -nt "$DEST/$rel" || ! -e "$DEST/$rel" ]] || continue
    mkdir -p "$DEST/$(dirname "$rel")"; cp -p "$f" "$DEST/$rel"
  done < <(find "$SRC" -type f -print0)
fi
[[ $DRY -eq 1 ]] && { echo "(dry run: nothing committed)"; exit 0; }

# 2. Size tiers
OVERSIZE="$DEST/OVERSIZE.tsv"; printf 'path\tmb\tsha256\n' > "$OVERSIZE"
EXCL="$REPO/.git/info/exclude"; mkdir -p "$(dirname "$EXCL")"; touch "$EXCL"
while IFS= read -r -d '' f; do
  rel="${f#"$REPO"/}"; mb=$(size_mb "$f")
  if (( mb > LFS_MAX_MB )) || { (( mb > GIT_MAX_MB )) && [[ $HAVE_LFS -eq 0 ]]; }; then
    printf '%s\t%s\t%s\n' "$rel" "$mb" "$(sha "$f")" >> "$OVERSIZE"
    grep -qxF "/$rel" "$EXCL" || echo "/$rel" >> "$EXCL"
    [[ -n "$RCLONE_REMOTE" ]] && rclone copyto "$f" "$RCLONE_REMOTE/${rel#"$DEST_SUBDIR"/}" --progress
  elif (( mb > GIT_MAX_MB )); then
    git lfs track "$rel" >/dev/null
  fi
done < <(find "$DEST" -type f -not -name OVERSIZE.tsv -not -name FILES.txt -size +"${GIT_MAX_MB}"M -print0)

# 3. File index for humans, Copilot, and cloud sessions
( cd "$DEST" && find . -type f -not -name FILES.txt | sort ) > "$DEST/FILES.txt"

# 4. Commit + push
git add -A
if git diff --cached --quiet; then echo ">> nothing to commit"; exit 0; fi
git commit -q -m "${MSG:-$COMMIT_PREFIX: $(date -u +%Y-%m-%dT%H:%MZ) ($(git diff --cached --numstat | wc -l | tr -d ' ') files)}"
if [[ $PUSH -eq 1 ]]; then
  for d in 0 2 4 8 16; do
    sleep "$d"; git push -u origin "HEAD:$BRANCH" && { echo ">> pushed to $BRANCH"; exit 0; }
  done
  echo "push failed after retries" >&2; exit 1
fi
