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

### 20260916 (baseline — first recorded run)

| configuration | avg FPS | worst | draw calls/frame | primitives/frame |
|---|---|---|---|---|
| msaa x2 + ssao + clutter | 117.8 | 74.0 | — | — |
| ssao off | 138.1 | 136.0 | — | — |
| ssao off + msaa off | 134.0 | 121.0 | — | — |
| ssao + msaa, clutter hidden | 128.4 | 112.0 | — | — |

⚠ Those four rows were measured **before** the display problem was understood: they were taken
through Wayland, where this machine never presents frames, so the numbers are main-loop iterations
rather than rendering cost (draw calls were 0). Treat them as void; the first valid benchmark is the
one produced by `tools/perf_test.sh` on Xwayland, recorded in `perf-20260916.txt`.
