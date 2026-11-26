#!/usr/bin/env python3
"""Runs KTBT's GdUnit4 tests headless, in several Godots at once (shards), and puts the results
back together: one pass or fail, the failures with their messages, the slowest files, and a line
in reports/test_runs.log for every run.

    python tools/run_tests.py                  # every test, in 3 shards
    python tools/run_tests.py --quick          # leaving out the slow checks (QUICK_SKIP below)
    python tools/run_tests.py --shards 1       # one Godot, in the project itself
    python tools/run_tests.py test_menu test_rules   # just these files

Why shards work: most of a scene test is waiting for the night's (scaled-down) time to pass, not
the CPU, so three Godots side by side take little longer than one. A big file (test_visit) is
split between them too: each shard adds the file and leaves out (-i) the others' tests.

Each shard past the first runs in its own copy of the project (in the system's temp folder,
kept and brought up to date each run, so only what's changed is copied), with an override.cfg
giving it a user folder of its own: the tests' saves, stats and settings never clash. The first
shard runs in the project itself, as the tests always have.

The Godot: --godot, else GODOT_BIN, else tools/godot_path.txt (this PC's own, as autoplay.bat).
Each test's time is kept in reports/test_times.json and used to share them out evenly next time.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "tests"
REPORTS = ROOT / "reports"
TIMES = REPORTS / "test_times.json"
RUN_LOG = REPORTS / "test_runs.log"

# The slow checks --quick leaves out: each splits whole pictures again (against the Python's on the
# library's pictures, or in one piece against many), which only matters when the split
# (rules/portrait_split.gd) or the art changes.
# The full run (no --quick) always has them, and is what counts before anything's called done.
QUICK_SKIP = [
    "test_portrait_split:test_the_library_picks_split_into_the_faces_in_the_game",
    "test_portrait_split:test_the_split_matches_the_pythons_on_library_pictures",
    "test_reaction_split:test_the_whole_reaction_split_is_near_the_pythons_and_picks_the_same",
    "test_reaction_split:test_the_reaction_split_of_the_pythons_close_ups_is_the_pythons",
    "test_portrait_split:test_a_split_is_the_same_in_one_piece_or_many",
]

# Left out of a shard's copy of the project: the image model's raw pictures (2 GB, no test needs
# them), git, the reports and logs, and the editor's own state.
SKIP_DIRS = {".git", "reports", "logs", "__pycache__", ".vscode"}
SKIP_PATHS = {("art", "raw"), (".godot", "editor")}
UNKNOWN_TIME = 0.3  # seconds, for a test not timed yet


def godot_binary(given):
    path = given or os.environ.get("GODOT_BIN", "")
    if not path and (ROOT / "tools" / "godot_path.txt").exists():
        path = (ROOT / "tools" / "godot_path.txt").read_text(encoding="utf-8").strip().strip('"')
    if not path or not Path(path).is_file():
        sys.exit("No Godot found: pass --godot <path>, set GODOT_BIN, or put its path in tools/godot_path.txt")
    return path


def discover(files):
    """{suite: [test names]} for every tests/test_*.gd (or just the files asked for)."""
    wanted = {f.replace(".gd", "").split("/")[-1] for f in files}
    found = {}
    for path in sorted(TESTS.glob("test_*.gd")):
        if wanted and path.stem not in wanted:
            continue
        found[path.stem] = re.findall(r"^func (test_\w+)\s*\(", path.read_text(encoding="utf-8"), re.M)
    missing = wanted - set(found)
    if missing:
        sys.exit("No such test file: " + ", ".join(sorted(missing)))
    return found


def share_out(suites, shards, times, skip):
    """Each shard's work: [(suite, [its tests here], all its tests)], about the same time each
    (by last run's times). Whole files where they fit; a file longer than half a shard's share is
    split into pieces of about that much."""
    def took(suite, test):
        return times.get("%s:%s" % (suite, test), UNKNOWN_TIME)

    pieces = []  # (seconds, suite, tests)
    total = sum(took(s, t) for s, tests in suites.items() for t in tests if "%s:%s" % (s, t) not in skip)
    most = max(total / shards / 2.0, 1.0)
    for suite, tests in suites.items():
        tests = [t for t in tests if "%s:%s" % (suite, t) not in skip]
        if not tests:
            continue
        seconds = sum(took(suite, t) for t in tests)
        if shards == 1 or seconds <= most:
            pieces.append((seconds, suite, tests))
            continue
        # Split by time, longest first round-robin, so each piece has a mix.
        count = min(len(tests), int(seconds // most) + 1)
        parts = [[0.0, []] for _ in range(count)]
        for t in sorted(tests, key=lambda t: -took(suite, t)):
            part = min(parts, key=lambda p: p[0])
            part[0] += took(suite, t)
            part[1].append(t)
        for seconds_here, part_tests in parts:
            pieces.append((seconds_here, suite, part_tests))
    work = [[0.0, []] for _ in range(shards)]
    for seconds, suite, tests in sorted(pieces, key=lambda p: -p[0]):
        shard = min(work, key=lambda w: w[0])
        shard[0] += seconds
        shard[1].append((suite, tests))
    out = []
    for seconds, got in work:  # (two pieces of one file in the same shard are one -a: each leaving out the other's tests left out all of them)
        joined = {}
        for suite, tests in got:
            joined.setdefault(suite, []).extend(tests)
        if joined:
            out.append([seconds, [(suite, tests, suites[suite]) for suite, tests in joined.items()]])
    return out


def _skipped_path(parts):
    return tuple(parts[:2]) in SKIP_PATHS


def raw_imports():
    """The .godot/imported files that belong to art/raw's pictures (not copied)."""
    names = set()
    raw = ROOT / "art" / "raw"
    if raw.is_dir():
        for imp in raw.rglob("*.import"):
            for m in re.finditer(r'res://\.godot/imported/([^"]+)', imp.read_text(encoding="utf-8", errors="ignore")):
                names.add(m.group(1))
    return names


def sync_copy(target, skip_imports):
    """Brings a shard's copy of the project up to date: new and changed files copied, ones gone
    from the project removed. How many files it copied, and how many of them were the project's
    own (not Godot's caches in .godot/, which change every run)."""
    copied = 0
    own = 0
    seen = set()
    for folder, dirs, files in os.walk(ROOT):
        rel = Path(folder).relative_to(ROOT)
        parts = rel.parts
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not _skipped_path(parts + (d,))]
        for name in files:
            if parts == (".godot", "imported") and name in skip_imports:
                continue
            if not parts and name == "override.cfg":
                continue
            src = Path(folder) / name
            dst = target / rel / name
            seen.add(rel / name)
            s = src.stat()
            if dst.exists():
                d = dst.stat()
                if d.st_size == s.st_size and int(d.st_mtime) == int(s.st_mtime):
                    continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            copied += 1
            own += 0 if parts[:1] == (".godot",) else 1
    for folder, dirs, files in os.walk(target):
        rel = Path(folder).relative_to(target)
        dirs[:] = [d for d in dirs if d not in {"reports", ".godot"} or rel.parts]
        if rel.parts[:1] in ((".godot",), ("reports",)):
            continue  # (Godot's own cache and the shard's reports stay)
        for name in files:
            if (rel / name) not in seen and not (not rel.parts and name == "override.cfg"):
                (Path(folder) / name).unlink()
    return copied, own


def shard_folder(k, skip_imports):
    target = Path(tempfile.gettempdir()) / "ktbt_test_shards" / str(k)
    target.mkdir(parents=True, exist_ok=True)
    copied, own = sync_copy(target, skip_imports)
    (target / "override.cfg").write_text(
        "[application]\n\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=\"KTBT_test_shard_%d\"\n" % k,
        encoding="utf-8")
    return target, copied, own


def latest_results(report_dir):
    reports = sorted(report_dir.glob("report_*/results.xml"), key=lambda p: int(p.parent.name.split("_")[1]))
    return reports[-1] if reports else None


def read_results(path):
    """(cases: [(suite, test, seconds, problem or None)])."""
    cases = []
    for case in ET.parse(path).getroot().iter("testcase"):
        problem = None
        for child in case:
            if child.tag in ("failure", "error"):
                problem = (child.get("message") or child.text or "").strip()
        cases.append((case.get("classname"), case.get("name"), float(case.get("time", 0)), problem))
    return cases


def main():
    ap = argparse.ArgumentParser(description="Run KTBT's tests in several Godots at once.")
    ap.add_argument("files", nargs="*", help="test files to run (test_menu or tests/test_menu.gd); every one if none")
    ap.add_argument("--shards", type=int, default=3, help="how many Godots at once (default 3)")
    ap.add_argument("--quick", action="store_true", help="leave out the slow library checks (QUICK_SKIP)")
    ap.add_argument("--godot", default="", help="the Godot to run (else GODOT_BIN or tools/godot_path.txt)")
    args = ap.parse_args()

    godot = godot_binary(args.godot)
    suites = discover(args.files)
    times = json.loads(TIMES.read_text(encoding="utf-8")) if TIMES.exists() else {}
    skip = set(QUICK_SKIP) if args.quick else set()
    work = share_out(suites, max(1, args.shards), times, skip)
    REPORTS.mkdir(exist_ok=True)
    started = time.time()
    skip_imports = raw_imports() if len(work) > 1 else set()

    folders = [ROOT]
    importing = []
    for k in range(1, len(work)):
        folder, copied, own = shard_folder(k, skip_imports)
        folders.append(folder)
        print("Shard %d: its copy of the project brought up to date (%d files copied)" % (k, copied), flush=True)
        if own:  # (Godot's own look over what's changed, as opening the project would: a fresh copy failed to compile GdUnit without it)
            importing.append(subprocess.Popen([godot, "--headless", "--path", str(folder), "--import"],
                                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    for p in importing:
        p.wait()

    runs = []
    for k, (seconds, pieces) in enumerate(work):
        folder = folders[k]
        report_dir = REPORTS / ("shard_%d" % k)  # (this run's output, Godot's log and results, in the project's reports/)
        report_dir.mkdir(parents=True, exist_ok=True)
        gdunit_dir = folder / "reports" / ("shard_%d" % k)  # (GdUnit's own reports: -rd is from the project's folder)
        cmd = [godot, "--path", str(folder), "-s", "-d", "--remote-debug", "tcp://127.0.0.1:0",
               "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"]
        count = 0
        for suite, tests, everything in pieces:
            cmd += ["-a", "res://tests/%s.gd" % suite]
            count += len(tests)
            for t in everything:
                if t not in tests:
                    cmd += ["-i", "res://tests/%s.gd:%s" % (suite, t)]
        cmd += ["-rd", "reports/shard_%d" % k, "-c", "--headless", "--ignoreHeadlessMode",
                "--log-file", str(report_dir / "godot.log")]
        log = open(report_dir / "output.txt", "w", encoding="utf-8", errors="replace")
        files = sorted({p[0] for p in pieces})
        print("Shard %d: %d tests (%s), about %.0fs" % (k, count, ", ".join(files) if len(files) <= 4 else "%d files" % len(files), seconds), flush=True)
        (report_dir / "command.txt").write_text(subprocess.list2cmdline(cmd), encoding="utf-8")
        runs.append({"k": k, "count": count, "dir": report_dir, "gdunit": gdunit_dir, "log": log, "out": report_dir / "output.txt",
                     "proc": subprocess.Popen(cmd, cwd=str(folder), stdout=log, stderr=subprocess.STDOUT)})

    # Every 10 seconds, how far each shard's got (from its output).
    while any(r["proc"].poll() is None for r in runs):
        time.sleep(10)
        bits = []
        for r in runs:
            done = len(re.findall(r" (PASSED|FAILED|ERROR|SKIPPED)", r["out"].read_text(encoding="utf-8", errors="replace")))
            bits.append("shard %d %d/%d%s" % (r["k"], min(done, r["count"]), r["count"], " (done)" if r["proc"].poll() is not None else ""))
        print("%3.0fs: %s" % (time.time() - started, ", ".join(bits)), flush=True)

    wall = time.time() - started
    cases, broken = [], []
    for r in runs:
        r["log"].close()
        found = latest_results(r["gdunit"])
        if found is None:
            broken.append("shard %d wrote no results (exit %s): see %s" % (r["k"], r["proc"].returncode, r["out"]))
            continue
        here = read_results(found)
        if len(here) < r["count"]:
            broken.append("shard %d ran %d of its %d tests (exit %s): see %s" % (r["k"], len(here), r["count"], r["proc"].returncode, r["out"]))
        cases += here
        if found.parent.parent != r["dir"]:
            shutil.copy2(found, r["dir"] / "results.xml")  # (a copy beside its output, to read)

    for suite, test, seconds, _ in cases:
        times["%s:%s" % (suite, test)] = round(seconds, 3)
    TIMES.write_text(json.dumps(times, indent=0, sort_keys=True), encoding="utf-8")

    failed = [c for c in cases if c[3] is not None]
    by_file = {}
    for suite, _, seconds, _ in cases:
        by_file[suite] = by_file.get(suite, 0.0) + seconds
    print()
    print("Slowest files: " + ", ".join("%s %.1fs" % kv for kv in sorted(by_file.items(), key=lambda kv: -kv[1])[:6]))
    for suite, test, _, problem in failed:
        print("FAILED %s > %s\n    %s" % (suite, test, problem.replace("\n", "\n    ")[:1200]))
    for line in broken:
        print("PROBLEM " + line)
    ok = not failed and not broken
    summary = "%s: %d tests, %d failed%s, in %.0fs (%d shards%s; the tests' own time %.0fs)" % (
        "PASSED" if ok else "FAILED", len(cases), len(failed), ", %d shard problems" % len(broken) if broken else "",
        wall, len(runs), ", quick" if args.quick else "", sum(by_file.values()))
    print(summary)
    with open(RUN_LOG, "a", encoding="utf-8") as f:
        f.write("%s  %s%s\n" % (time.strftime("%Y-%m-%d %H:%M"), summary,
                                "  [" + " ".join(args.files) + "]" if args.files else ""))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
