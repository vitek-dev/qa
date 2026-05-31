#!/usr/bin/env bash
#
# Publish the current `main` to every php/* release branch.
#
# In this repo each php/X.Y branch is byte-identical to main; the branch name
# alone selects the PHP version (.github/workflows/build.yaml substitutes the
# %%PHP_VERSION%% placeholder at build time and publishes ghcr.io/vitek-dev/qa:vX.Y).
# A push to a php/* branch is what triggers that build, so "publishing main"
# means moving every php/* branch up to main's commit and pushing it — which
# kicks off one image build per branch.
#
# Usage: ./publish-php-branches.sh [-n] [-y] [-f] [-r remote] [-s source]
#
#   -n  dry run: show what would be pushed, push nothing
#   -y  skip the confirmation prompt
#   -f  force-update php/* branches that have diverged from the source branch
#   -r  remote to read/publish on (default: origin)
#   -s  source branch to publish (default: main)

set -euo pipefail

REMOTE="${REMOTE:-origin}"
SOURCE="${SOURCE:-main}"
DRY_RUN=0
ASSUME_YES=0
FORCE=0

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; }

while getopts ":nyfr:s:h" opt; do
  case "$opt" in
    n) DRY_RUN=1 ;;
    y) ASSUME_YES=1 ;;
    f) FORCE=1 ;;
    r) REMOTE="$OPTARG" ;;
    s) SOURCE="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
    :)  echo "Option -$OPTARG requires an argument" >&2; exit 2 ;;
  esac
done

# Refresh our view of the remote so the branch list and SHAs are current.
echo "Fetching ${REMOTE}..."
git fetch --quiet "$REMOTE"

# Resolve the commit we're publishing.
if ! source_sha="$(git rev-parse --verify --quiet "${SOURCE}^{commit}")"; then
  echo "Source branch '${SOURCE}' not found." >&2
  exit 1
fi

# Heads-up if the local source branch isn't what's on the remote.
if remote_source_sha="$(git rev-parse --verify --quiet "${REMOTE}/${SOURCE}^{commit}")"; then
  if [ "$source_sha" != "$remote_source_sha" ]; then
    echo "Note: local ${SOURCE} (${source_sha:0:7}) differs from ${REMOTE}/${SOURCE} (${remote_source_sha:0:7})." >&2
    echo "      Publishing your local ${SOURCE}." >&2
  fi
fi

# Discover php/* branches on the remote (picks up new ones like php/8.6 automatically).
# Plain read loop rather than `mapfile` so this runs on macOS's bash 3.2.
branches=()
while IFS= read -r b; do
  [ -n "$b" ] && branches+=("$b")
done < <(git ls-remote --heads "$REMOTE" 'refs/heads/php/*' | sed 's#.*refs/heads/##' | sort -V)

if [ "${#branches[@]}" -eq 0 ]; then
  echo "No php/* branches found on ${REMOTE}." >&2
  exit 1
fi

echo
echo "Publishing ${SOURCE} (${source_sha:0:7}) to ${REMOTE}:"

to_push=()
diverged=0
for b in "${branches[@]}"; do
  remote_sha="$(git rev-parse --verify --quiet "${REMOTE}/${b}^{commit}" || true)"

  if [ "$remote_sha" = "$source_sha" ]; then
    printf '  %-14s up to date\n' "$b"
    continue
  fi

  from="new"
  [ -n "$remote_sha" ] && from="${remote_sha:0:7}"

  # A branch whose tip is NOT an ancestor of source would be moved backwards or
  # rewritten — that needs an explicit force.
  if [ -n "$remote_sha" ] && ! git merge-base --is-ancestor "$remote_sha" "$source_sha"; then
    if [ "$FORCE" -eq 1 ]; then
      printf '  %-14s %s -> %s  (force)\n' "$b" "$from" "${source_sha:0:7}"
      to_push+=("$b")
    else
      printf '  %-14s %s -> %s  DIVERGED (skipped; use -f)\n' "$b" "$from" "${source_sha:0:7}"
      diverged=1
    fi
  else
    printf '  %-14s %s -> %s\n' "$b" "$from" "${source_sha:0:7}"
    to_push+=("$b")
  fi
done

if [ "${#to_push[@]}" -eq 0 ]; then
  echo
  echo "Nothing to publish."
  [ "$diverged" -eq 1 ] && echo "(Diverged branches were skipped — rerun with -f to overwrite them.)"
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "Dry run — would push to: ${to_push[*]}"
  exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  echo
  read -r -p "Push ${SOURCE} to ${#to_push[@]} branch(es) on ${REMOTE}? Triggers a CI image build each. [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

refspecs=()
for b in "${to_push[@]}"; do
  refspecs+=("${source_sha}:refs/heads/${b}")
done

push_args=(push)
[ "$FORCE" -eq 1 ] && push_args+=(--force)

echo
git "${push_args[@]}" "$REMOTE" "${refspecs[@]}"

echo
echo "Done. Published ${SOURCE} to: ${to_push[*]}"
