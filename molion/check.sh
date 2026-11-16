#!/usr/bin/env bash
# Checks a bundled CREST on its own: its version, then a conformer search on n-butane run the
# way Molion runs it (the environment qc_tools.environment gives a run), on one thread and on
# two. Each must end normally with anti and gauche butane, gauche about 0.6 kcal/mol above
# anti. Every run is tried; any failure fails the check.
#
#     molion/check.sh <path to crest/bin/crest or crest.exe>
#
# CHECK_INPUT, when set, is written to each run's folder as input.toml and passed with --input.
set -uo pipefail

crest="$1"; shift
export OMP_MAX_ACTIVE_LEVELS=1 OPENBLAS_NUM_THREADS=1 OMP_STACKSIZE=512M
# Unbuffered, so a crash's log shows how far the run got
export GFORTRAN_UNBUFFERED_ALL=1
work="$(mktemp -d)"
cd "$work"

"$crest" --version | grep -i 'version' || { echo 'crest --version failed'; exit 1; }

cat > butane.xyz <<'XYZ'
14
n-butane
C  -1.95 -0.37  0.00
C  -0.64  0.40  0.00
C   0.64 -0.40  0.00
C   1.95  0.37  0.00
H  -2.79  0.33  0.00
H  -2.03 -1.02  0.88
H  -2.03 -1.02 -0.88
H  -0.59  1.06  0.88
H  -0.59  1.06 -0.88
H   0.59 -1.06  0.88
H   0.59 -1.06 -0.88
H   2.79 -0.33  0.00
H   2.03  1.02  0.88
H   2.03  1.02 -0.88
XYZ

failed=0
for threads in 1 2; do
  run="butane-T$threads"
  rm -rf "$run" && mkdir "$run" && cp butane.xyz "$run/input.xyz"
  extra=()
  if [ -n "${CHECK_INPUT:-}" ]; then
    printf '%s\n' "$CHECK_INPUT" > "$run/input.toml"
    extra=(--input input.toml)
  fi
  started=$SECONDS
  code=0
  (cd "$run" && OMP_NUM_THREADS=$threads "$crest" input.xyz --gfn2 --chrg 0 --uhf 0 -T "$threads" ${extra[@]+"${extra[@]}"} > output.log 2>&1) || code=$?
  seconds=$((SECONDS - started))
  count=0
  [ -f "$run/crest_conformers.xyz" ] && count=$(grep -cE '^\s*14\s*$' "$run/crest_conformers.xyz")
  if [ "$code" = 0 ] && grep -q 'CREST terminated normally' "$run/output.log" && [ "$count" -ge 2 ] && [ "$count" -le 4 ]; then
    # Each frame's comment line (after its atom count) starts with its energy in hartree
    gauche=$(awk 'after { energies[++n] = $1; after = 0; next } /^ *14 *$/ { after = 1 }
                  END { printf "%.2f", (energies[2] - energies[1]) * 627.509 }' "$run/crest_conformers.xyz")
    echo "-T $threads: $count conformers, gauche +${gauche} kcal/mol, ${seconds} s"
  else
    failed=1
    echo "-T $threads FAILED (exit $code, $count conformers, ${seconds} s); the log's last 40 lines:"
    tail -40 "$run/output.log"
  fi
done
exit $failed
