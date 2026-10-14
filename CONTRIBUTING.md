# Reporting problems and contributing

## Raising an issue on GitHub

1. **Search first:** open the project's [Issues](https://github.com/z00p/AmiMSX/issues) page and search for the game or the symptom. If an issue already exists, add your details there.
2. **New issue:** otherwise click **New issue** and choose a template:
   - **Game problem:** a game doesn't start, looks wrong, sounds wrong or plays wrongly;
   - **Bug:** AmiMSX itself (menu, prefs, crashes, Workbench start);
   - **Feature request.**
3. **Fill in every section of the template.** Most problems depend on the machine and the settings, so those details matter more than anything else.
4. **Attach screenshots** where you can. Two pictures side by side help most: AmiMSX, and openMSX at the same moment.

Never attach or link ROM, disk or system ROM files: they are copyrighted. Name the game and its version, and give the file's SHA-1 checksum. On the Amiga, `C:Checksum` or any SHA-1 tool gives it; on Windows, `certutil -hashfile file SHA1`.

## What happens next

- **Labels:** issues are labelled by area (`compatibility`, `vdp`, `z80`, `sound`, `mapper`, `gui`, `performance`, ...) and by machine (`hardware: A1200`, `hardware: PiStorm`, ...).
- **`needs-info`:** something is missing to reproduce the problem.
- **`confirmed`:** the problem can be reproduced.
- **Regression titles:** a confirmed game problem is usually added to the regression titles (`tests/titles.csv`) with a key script, so it stays fixed (see `Docs/regression.md`).

## Contributing changes

- **Pull requests are welcome.** Please:
  - keep to one problem per pull request;
  - follow the surrounding code's style (Devpac syntax, comments in the existing mix of Spanish and English are fine);
  - build with `sh build.sh` (vasm). It refuses branches to `*+n`: use labels;
  - run the regression smoke tier (`python tools/regress.py smoke`) and say in the pull request which titles changed and why.
- **Accuracy over speed.** A fast 68030 or 68040 is the baseline. A change that makes a game more correct but slower is welcome, with its cost measured (`winuae/sc_perf_ab.ps1`).
