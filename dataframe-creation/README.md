# dataframe-creation

Export the LDEO_IX **preprocessed** LADCP data (steps 1–13 of
`process_cast.m`, i.e. the super-ensemble data exactly as the inversion
sees them) to long-form CSV files readable with `pandas.read_csv`, instead
of running the inversion. Useful for building custom inversions or
analyses outside MATLAB.

## Usage

```matlab
cd dataframe-creation
% edit set_dataframe_params.m for your cruise first (paths, file layouts)
create_dataframes(4)                  % one station
failed = batch_create_dataframes(2:25);   % many stations, keeps going on errors
```

`set_dataframe_params.m` plays the role of `set_cast_params.m` (same
`f.*`/`p.*` fields, see `Processing_HowTo.pdf`) plus a `p_df` block for
export settings. `create_dataframes.m` mirrors `process_cast.m` steps 1–13
verbatim — including the preliminary `getinv` passes of the outlier
removal — then writes four CSVs per cast (plus `step13_state.mat` with the
`d`/`di`/`p`/`f` structures for debugging, if `p_df.save_state`).

In Python:

```python
import pandas as pd
ld = pd.read_csv('dataframes/004/ladcp.csv', parse_dates=['t_clock'])
```

## Common conventions

- All four frames share **`t_seconds`**: seconds since the first LADCP
  super-ensemble of the cast. Rows before that time are dropped.
- `*_t_clock` columns are ISO 8601 strings (`yyyy-mm-ddTHH:MM:SS.FFF`).
- Depths are in meters, **positive down**.
- Velocities are m/s, east/north components. Sign conventions:
  - **ladcp.csv `u`,`v`** — ocean **minus** instrument velocity (the raw
    relative measurement, magnetic-declination corrected)
  - **btrack.csv `bot_u`,`bot_v`** — **instrument velocity over ground**
  - **sadcp.csv `u`,`v`** — absolute ocean velocity
  
  so at bottom-tracked timesteps, absolute ocean velocity = `u + bot_u`.
- Rows where both velocity components are NaN are dropped. A frame with no
  valid data is written header-only (schema stays constant).

## ladcp.csv — one row per (super-ensemble, bin)

| column | meaning |
|---|---|
| `t_step` | 0-based super-ensemble index (equal `t_clock` ⇔ equal `t_step`) |
| `t_clock` | time stamp |
| `t_seconds` | common time base (see above) |
| `dt` | seconds since previous super-ensemble (NaN for the first) |
| `bin_idx` | signed bin number: `+1..+N` downlooker, `-1..-M` uplooker, 1 = nearest the instrument |
| `depth` | depth of the measurement (instrument depth + bin offset, from `di.izm`) |
| `u`, `v` | relative velocity (ocean − instrument) |

## gps.csv — ship position while the instrument is near the surface

One row per super-ensemble with instrument depth < `p_df.surface_depth`
(set it to `Inf` to dump the ship track at every super-ensemble). Ship
positions come from `f.nav` interpolated onto the ADCP time base
(`loadnav.m`), median-averaged per super-ensemble (`prepinv.m`).

| column | meaning |
|---|---|
| `gps_t_step` | 0-based row counter |
| `gps_t_clock`, `t_seconds` | time |
| `instrument_depth` | m, positive down |
| `gps_dt` | seconds since previous row (NaN first) |
| `total_displacement_x/y` | m East/North of the first row (flat-earth, same formula as `prepinv.m` ship drift) |
| `rel_displacement_x/y` | m East/North of the previous row (NaN first) |

## btrack.csv — bottom-tracked instrument velocity

| column | meaning |
|---|---|
| `t_step` | super-ensemble index, **same numbering as ladcp.csv** (join on it) |
| `bot_t_clock`, `t_seconds` | time |
| `bot_u`, `bot_v` | instrument velocity over ground |

## sadcp.csv — shipboard ADCP, one row per (profile, depth bin)

Read directly from `f.sadcp` (the `.mat` built by `mkSADCP.m`), windowed
to the cast time span exactly like `loadsadcp.m` (± `p.sadcp_dtok`), with
the same 0.1°-colocation sanity check.

| column | meaning |
|---|---|
| `sadcp_t_step` | 0-based in-window profile index |
| `sadcp_t_clock`, `t_seconds` | time |
| `depth` | bin depth |
| `u`, `v` | absolute ocean velocity |

## Caveats

- **Casts that never surface** (tow-yo/yoyo segments): set `p.cut = 0` in
  `set_dataframe_params.m`. With the default `p.cut > 0`, `loadctd.m`
  rejects the CTD pressure series of a cast whose first pressure is deep
  ("WARNING ignore pressure time series") — depth then silently comes from
  integrated vertical velocity *relative to the cast start* — and returns
  early without setting the start/end positions `p.poss`/`p.pose`, which
  can corrupt the preliminary inversion's ship-drift constraint.
- `ladcp.csv` velocities are **relative**, not ocean velocities: the
  instrument motion is not removed (that is the inversion's job).
- The preliminary `getinv` passes (steps 11–12) are part of the standard
  preprocessing and are kept, so `di` matches what `process_cast.m` feeds
  the inversion; if they fail, the tool warns and continues with the
  un-narrowed super-ensembles.
