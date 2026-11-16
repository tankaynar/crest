# CREST for Molion

This branch (`molion`) is [crest-lab/crest](https://github.com/crest-lab/crest) at the v3.0.2
release, upstream commit `af7eb9927e2b36e24b14055f9eba3bea5be0014e`, built for
[Molion](https://github.com/tankaynar/molion), which ships it. Upstream has no Windows build
(crest-lab/crest#276).

## Changes to the sources

Each is one commit on this branch:

- **Windows** (MSYS2 UCRT64 gfortran, `-D_WIN32` to the Fortran preprocessor): the default
  conformer search, which runs GFN2 in process through tblite and so needs no xtb program and
  almost no shell commands. `mkdir`, `setenv` and `symlink` use their MSVCRT equivalents (a
  copy for `symlink`), `rm -rf` and `kill` go through `remove_tree` and `kill_process` (`del`,
  `rmdir /s`, `taskkill`), `command -v` and `/dev/null` become `where` and `NUL`, and every
  `rename` goes through `rename_file`, which replaces an existing target as POSIX does. The
  legacy, QCG, msreact and ConfSolv paths still run Unix shell commands and are not supported
  on Windows.
- **The command line's coordinates are read before an input file** (all platforms). v3.0.2
  read `--input` files before loading the structure named first on the command line, then
  oriented that structure with its atom count uninitialised: an input file that does not name
  the structure itself (`input = "..."`) made CREST allocate tens of gigabytes and die.
- **Windows: OpenMP teams are never nested.** MinGW's libgomp does not pool a nested team's
  threads, so a stage with fewer jobs than threads spent most of its time creating Windows
  threads (butane's extra MDs: 2-3 s each unnested, 2 min with 6 nested threads).

The branch also adds:

- `.github/workflows/molion-build.yml`: builds CREST for macOS arm64, Linux x64 and Windows
  x64, each into a folder that runs on its own, checks it, and publishes it as a release
  (upstream's own CI workflows are removed from this branch);
- `molion/`: this file and the scripts that workflow runs (`deps.txt` and `fetch-deps.sh` pin
  the libraries tblite would otherwise fetch at HEAD, `bundle.py` gathers the shared libraries
  on macOS and Linux, `licences.sh` the licence files, `check.sh` the checks).

## Releases

Each `molion-<n>` release holds `crest-<platform>.zip` (with its SHA-256) and
`crest-source.tar.xz`, the source of those builds: this tree with its submodules and the
libraries `molion/deps.txt` pins. CREST is LGPL-3.0-or-later, and the libraries linked into it
are LGPL-3.0-or-later or more permissive; each zip carries every licence under
`crest/licenses/` (the runtimes' by package, the sources' under `source/`), and
`crest/COMMIT.txt` names the commit it was built from.

macOS and Linux builds use conda-forge's gfortran and OpenBLAS (Linux: glibc 2.17 or newer),
their libraries in `crest/lib`; Windows uses MSYS2's UCRT64 gfortran and OpenBLAS, the DLLs
beside `crest.exe`. Each is checked from the bundle alone: a butane conformer search on one
and two threads, which must end normally with anti and gauche butane (gauche about
0.6 kcal/mol above), with and without an input file that names no structure.

To move to a new upstream release, merge its tag into `molion` (the branch is never rebased:
each release tag keeps its own history), push, and once the build is green tag the next
`molion-<n>`.
