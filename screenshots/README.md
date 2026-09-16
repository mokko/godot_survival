# screenshots/ — first screenshots of each week

Convention (Maurice's): one folder per capture date, `screenshots/YYYYMMDD/`, holding the **first
screenshots of that week** — a visual record to look back on as the art develops. Add a new folder
the first time we take screenshots in a new week; don't keep every run.

## How these were taken

```bash
cd ~/snap/godot-4/common/survivalm
# needs a display: on this machine the session is Xwayland
env DISPLAY=:0 XAUTHORITY=/run/user/1000/.mutter-Xwaylandauth.* \
  snap run godot-4 --audio-driver Dummy --script res://tools/capture_views.gd
```

`tools/capture_views.gd` renders six fixed, deterministic poses (the biome ones are sampled with a
fixed RNG seed, so two builds can be compared shot for shot) and writes them to `user://shots`,
which on this machine is:

```
~/snap/godot-4/30/.local/share/godot/app_userdata/Survival M/shots/
```

Copy them here and note what changed. The window appears briefly while capturing.

Caveats worth remembering:

- Frames render at ~1 fps while the capture window is obscured on Xwayland, so the tool is slow
  (tens of seconds per pose). Run it from the desktop session, and don't be alarmed by the wait.
- The snap's `/tmp` is private: an output path under `/tmp` is invisible from outside the snap. Use
  the default `user://shots` (or another path under `$HOME`).
- Poses: `01` ground close-up at the spawn (floor texture + clutter), `02` coast looking out to sea,
  `03` inland, `04` Ezo massif, `05` caldera lake, `06` coast at night.

## Perf benchmark

`tools/perf_test.sh` writes the frame-rate benchmark for a build. Keep the output of the release run
here as `perf-YYYYMMDD.txt` so it travels with the screenshots of that date.

### How to read the benchmark numbers

- **Draw calls and primitives per frame are trustworthy**; they are per-frame render metrics.
- **Absolute fps from a shell outside your desktop session is not.** A window created by the agent
  (or by cron) is not properly part of the session, and its present/swap path gets throttled: the
  first recorded run measured **1.0 fps while issuing ~1700 draw calls and ~3.2M primitives**, which is
  far more GPU work than 1 fps on a Mali-G610 — i.e. the frame was *presented* slowly, not *drawn*
  slowly. For a meaningful frame rate, run `tools/perf_test.sh` from your own session (and close the
  Godot editor, which shares the GPU).
- If the probe reports `0 frames drawn`, nothing was presented at all and every number is void — it
  exits non-zero and says so.
- **The load is dominated by the flora.** Hidden-layer probe: everything 1665 draws / 3.17M prims;
  Plants hidden 308 / 0.71M; Animals hidden 1473 / 2.83M; Terrain hidden 1660 / 2.88M; Clutter hidden
  1665 / 3.17M. So ~1357 draws and ~2.46M prims are 464 plant instances, each 2-8 separate
  `MeshInstance3D` built from **default-resolution** Godot primitives (a default `SphereMesh` alone is
  ~4k triangles). Merging each species into one mesh per instance — or one MultiMesh per species — and
  dropping the segment counts are the two cheapest wins in the project.

### 20260916 (baseline — first recorded run)

Raw output: `perf-20260916.txt`. (Earlier ad-hoc SSAO/MSAA numbers taken through Wayland were
main-loop iterations rather than rendering, and are void — see "How to read" above.)
