#!/usr/bin/env bash
# Corre os testes unitários (GUT) em headless. Exit code != 0 se algum falhar
# ou se o GUT ignorar silenciosamente um ficheiro (parse error / load failure).
set -uo pipefail
cd "$(dirname "$0")"
godot --headless --path . --import >/dev/null 2>&1 || true
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@" 2>&1 | tee "$out"
code=${PIPESTATUS[0]}
if grep -qiE 'Parse Error|SCRIPT ERROR|could not load|failed to load' "$out"; then
  echo "run_tests.sh: erros de script/carregamento detectados no output do GUT" >&2
  [ "$code" -eq 0 ] && code=1
fi
exit "$code"
