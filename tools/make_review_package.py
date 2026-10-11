"""Build the private review package for the author (Docs/REVIEW_4.0.md):
release/review-<date>/ and release/AmiMSX4_review_<date>.zip.

  AmiMSX/       the program (build/AmiMSX), the presets (tools/make_presets.py),
                AmiMSX2.data built from C-BIOS, AmiMSX2.mapper, C-BIOS.txt, the guide
  Source/       the tracked source (git archive HEAD) without the original system
                ROMs, the 3.1 archive, third-party binaries and local WinUAE configs,
                plus AmiMSX_3.1_to_4.0.diff (the two .asm files against the import)
  Docs/         CHANGES_4.0.md, open_issues.md
  Screenshots/  build/review_shots/*.png, if any
  README.md     Docs/REVIEW_4.0.md

Refuses to finish if AmiMSX2.data isn't the C-BIOS build or if any packaged file
looks like a ROM, disk image or archive.
Usage: python tools/make_review_package.py [--date YYYYMMDD]"""
import argparse, datetime, glob, io, os, shutil, subprocess, sys, tarfile, zipfile

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMPORT = "1b4dcfd"                       # "Import AmiMSX v3.1 source as released"
EXCLUDE = {"AmiMSX2.data", "AmiMSX_asm.lha", "tools/vasmm68k_mot.exe", "tools/vobjdump.exe",
           # internal planning notes, not for the review copy
           "Docs/release_4.0.md", "Docs/gitlab_staging.md", "Docs/regression_candidates.md"}
EXCLUDE_GLOBS = ["winuae/*.uae"]         # local paths (Kickstart, drives)
BAD_EXT = {".rom", ".dsk", ".mvd", ".lha", ".lzh", ".adf", ".hdf", ".zip", ".exe"}


def git(*a):
    return subprocess.run(["git", *a], cwd=BASE, capture_output=True, check=True).stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", default=datetime.date.today().strftime("%Y%m%d"))
    a = ap.parse_args()
    if git("status", "--porcelain", "--", "AmiMSX_Main_v3.1.asm", "AmiMSX_Menu_v3.1.asm").strip():
        raise SystemExit("the .asm sources have uncommitted changes: commit, rebuild, then package")
    out = os.path.join(BASE, "release", f"review-{a.date}")
    if os.path.exists(out):
        raise SystemExit(f"{out} exists: use a new --date or remove it first")
    os.makedirs(out)

    # AmiMSX drawer
    drw = os.path.join(out, "AmiMSX")
    os.makedirs(drw)
    exe = os.path.join(BASE, "build", "AmiMSX")
    if os.path.getmtime(exe) < float(git("log", "-1", "--format=%ct").strip()):
        raise SystemExit("build/AmiMSX is older than the last commit: run sh build.sh")
    shutil.copy2(exe, drw)
    subprocess.run([sys.executable, os.path.join(BASE, "tools", "make_presets.py"), exe, drw], check=True)
    os.remove(os.path.join(drw, "presets.png"))
    cb = os.path.join(BASE, "build", "AmiMSX2_cbios.data")
    if b"data CB1" not in open(cb, "rb").read(64):
        raise SystemExit(f"{cb} isn't the C-BIOS build")
    shutil.copy2(cb, os.path.join(drw, "AmiMSX2.data"))
    shutil.copy2(os.path.join(BASE, "AmiMSX2.mapper"), drw)
    shutil.copy2(os.path.join(BASE, "tools", "openmsx", "doc", "cbios.txt"), os.path.join(drw, "C-BIOS.txt"))
    for f in ("AmiMSX.guide", "AmiMSX.guide.info"):
        shutil.copy2(os.path.join(BASE, "Docs", f), drw)

    # Source
    src = os.path.join(out, "Source")
    tar = tarfile.open(fileobj=io.BytesIO(git("archive", "--format=tar", "HEAD")))
    for m in tar.getmembers():
        if not m.isfile():
            continue
        if m.name in EXCLUDE or any(glob.fnmatch.fnmatch(m.name, g) for g in EXCLUDE_GLOBS):
            continue
        dst = os.path.join(src, *m.name.split("/"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as f:
            f.write(tar.extractfile(m).read())
    with open(os.path.join(src, "AmiMSX_3.1_to_4.0.diff"), "wb") as f:
        f.write(git("diff", IMPORT, "HEAD", "--", "AmiMSX_Main_v3.1.asm", "AmiMSX_Menu_v3.1.asm"))
    with open(os.path.join(src, "BUILDING.txt"), "w", encoding="utf-8") as f:
        f.write("Build: sh build.sh (needs vasm 2.0f, vasmm68k_mot, from http://sun.hasenbraten.de/vasm/,\n"
                "in tools/). Output: build/AmiMSX. The WinUAE test configs aren't included: they hold\n"
                "local paths. AmiMSX2.data isn't included: see AmiMSX/ for the C-BIOS build.\n")

    # Docs, screenshots, readme
    docs = os.path.join(out, "Docs")
    os.makedirs(docs)
    for f in ("CHANGES_4.0.md", "open_issues.md"):
        shutil.copy2(os.path.join(BASE, "Docs", f), docs)
    shots = sorted(glob.glob(os.path.join(BASE, "build", "review_shots", "*.png")))
    if shots:
        os.makedirs(os.path.join(out, "Screenshots"))
        for s in shots:
            shutil.copy2(s, os.path.join(out, "Screenshots"))
    shutil.copy2(os.path.join(BASE, "Docs", "REVIEW_4.0.md"), os.path.join(out, "README.md"))

    # Checks
    bad = []
    for root, _, files in os.walk(out):
        for f in files:
            p = os.path.join(root, f)
            rel = os.path.relpath(p, out).replace(os.sep, "/")
            if os.path.splitext(f)[1].lower() in BAD_EXT:
                bad.append(rel)
            if f.lower().endswith(".data") and b"data CB1" not in open(p, "rb").read(64):
                bad.append(rel + " (not C-BIOS)")
    if bad:
        raise SystemExit("refusing: " + ", ".join(bad))

    z = os.path.join(BASE, "release", f"AmiMSX4_review_{a.date}.zip")
    with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(out):
            for f in files:
                p = os.path.join(root, f)
                zf.write(p, os.path.join(f"AmiMSX4_review_{a.date}", os.path.relpath(p, out)))
    n = sum(len(fs) for _, _, fs in os.walk(out))
    print(f"{out}: {n} files; {z}: {os.path.getsize(z) // 1024} KB")


if __name__ == "__main__":
    main()
