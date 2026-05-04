# mh-scripts

A collection of utility scripts for Monster Hunter Wilds.

---

<details>
<summary><strong>toxic_spill.rb</strong> — Toxic Spill entry calculator</summary>

## toxic_spill.rb

Tells you when you can enter the Toxic Spill based on your hunter rank, and prints the full pollution cycle schedule so you can plan ahead.

The pollution level cycles through eight stages at fixed durations. Once you record a single reference point, the script calculates the current stage automatically every time you run it — no need to re-enter the schedule manually.

**Stages (low → high)**

| Stage | Duration |
|---|---|
| Hero | 30 h |
| Knight | 16 h |
| Lord/Lady | 18 h |
| Baron/Baroness | 18 h |
| Count/Countess | 24 h |
| Duke/Duchess | 24 h |
| Grand Duke/Grand Duchess | 24 h |
| Archduke/Archduchess | 24 h |

### Requirements

Ruby (no gems required).

### First run

```
ruby toxic_spill.rb
```

On first run, the script asks for a one-time reference point — the current pollution level, direction (rising/falling), and when the next stage transition happens. This is saved to `.toxic_spill.yml` alongside the script and used to calculate the current stage on every subsequent run.

After setup, you are optionally asked for your hunter rank. Providing it adds a colour-coded Access column (✓ enter / ✗ locked) to the output and shows the next window when you can get in. Skipping it shows the plain cycle schedule instead.

### Subsequent runs

```
ruby toxic_spill.rb
```

Only asks for your hunter rank (skippable). Everything else is derived from the saved reference.

You can also pass your rank directly to skip all prompts:

```
ruby toxic_spill.rb --my-rank baron
```

### Flags

| Flag | Description |
|---|---|
| `--my-rank RANK` | Your hunter rank (optional) |
| `--current-level LEVEL` | Override: current pollution level |
| `--direction DIR` | Override: `rising` or `falling` |
| `--next-transition TIME` | Override: next stage change time (e.g. `18:00` or `May 6 04:00`) |
| `--reset` | Forget the saved reference and re-run first-time setup |
| `-h, --help` | Show usage |

Passing `--current-level`, `--direction`, and `--next-transition` together bypasses the saved reference entirely, which matches the original four-flag interface.

### Resetting the reference

If the schedule ever drifts (e.g. due to a game update or a login error), re-sync with:

```
ruby toxic_spill.rb --reset
```

</details>
