#!/bin/bash
# Verify remove_legacy_foot_shim only ever deletes the shim this project shipped.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
ok()   { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=1; }

# The exact wrapper v0.2 installed at ~/.local/bin/foot.
legacy_wrapper() {
  cat <<'WRAP'
#!/bin/bash
# Intercept the packaged screensaver launcher, which hardcodes JetBrains Mono.
screensaver=0
for arg in "$@"; do
  case "$arg" in
    --app-id=org.omarchy.screensaver|org.omarchy.screensaver) screensaver=1 ;;
  esac
done

if ((screensaver)); then
  exec "$HOME/.config/omarchy/screensaver-overlay/run-foot.sh"
fi

exec /usr/bin/foot "$@"
WRAP
}

# Run the migration in isolation against a throwaway HOME.
run_migration() {
  local home="$1" script="$2"
  HOME="$home" bash -c '
    source /dev/stdin <<<"$(sed -n "/^remove_legacy_foot_shim() {/,/^}$/p" "$1")"
    remove_legacy_foot_shim
  ' _ "$ROOT/$script" >/dev/null 2>&1
}

for script in install.sh uninstall.sh; do
  echo "$script"

  # 1. our own shim -> removed
  h=$(mktemp -d); mkdir -p "$h/.local/bin"; legacy_wrapper >"$h/.local/bin/foot"
  run_migration "$h" "$script"
  [[ -e $h/.local/bin/foot ]] && bad "legacy shim should be removed" || ok "legacy shim removed"
  rm -rf "$h"

  # 2. unrelated user file -> preserved
  h=$(mktemp -d); mkdir -p "$h/.local/bin"
  printf '#!/bin/bash\n# my own foot wrapper\nexec /usr/bin/foot "$@"\n' >"$h/.local/bin/foot"
  run_migration "$h" "$script"
  [[ -f $h/.local/bin/foot ]] && ok "foreign file preserved" || bad "foreign file was deleted"
  rm -rf "$h"

  # 3. symlink -> preserved, even when it points at our own content
  h=$(mktemp -d); mkdir -p "$h/.local/bin"; legacy_wrapper >"$h/target"
  ln -s "$h/target" "$h/.local/bin/foot"
  run_migration "$h" "$script"
  [[ -L $h/.local/bin/foot && -e $h/target ]] && ok "symlink preserved" || bad "symlink or its target was touched"
  rm -rf "$h"

  # 4. path replaced by another program after install -> preserved
  h=$(mktemp -d); mkdir -p "$h/.local/bin"
  printf '#!/bin/bash\nexec /usr/bin/footclient "$@"\n' >"$h/.local/bin/foot"
  run_migration "$h" "$script"
  [[ -f $h/.local/bin/foot ]] && ok "replaced path preserved" || bad "replaced path was deleted"
  rm -rf "$h"

  # 5. nothing there -> no error
  h=$(mktemp -d); mkdir -p "$h/.local/bin"
  run_migration "$h" "$script" && ok "absent path is a no-op" || bad "absent path errored"
  rm -rf "$h"
done

((fail)) && { echo "FAILED"; exit 1; }
echo "all checks passed"
