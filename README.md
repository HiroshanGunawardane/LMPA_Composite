# DMA Composite Material Analysis

MATLAB and Python scripts for processing dynamic mechanical analysis (DMA) data from composite elastomer samples, extracting Young’s modulus, comparing materials across filler concentrations, and fitting simple composite-modulus models.

This repository contains two main analysis pipelines:

1. **MEMS/CERR/Ecoflex pipeline** based on exported `.txt` files in `ss0`, `ss80`, and `ts`
2. **FM/Ecoflex pipeline** based on raw `.csv` files in `DMA_FM`

It also includes downstream scripts for:

- pooled material comparison plots
- statistical testing
- Guth and Tsai model fitting
- thesis/paper-ready summary figures

---

## What this code does

At a high level, the workflow is:

**raw DMA files → exported text/CSV → averaged curves → Young’s modulus summary tables → comparison plots → model fitting/statistics**

More specifically, the code can:

- batch-export DMA files from Universal Analysis using GUI automation
- load DMA stress-strain and temperature-sweep data
- group files by material, concentration, and test type
- average repeated samples onto a common strain or temperature axis
- estimate Young’s modulus from the linear part of room-temperature stress-strain curves
- calculate standard errors across samples
- generate publication-style plots
- fit simple analytical composite models (Guth and Tsai)
- run nonparametric statistical tests across materials/concentrations

---

## Main entry points

### 1) `mems_analysis.m`
Primary script for the **CERR 117 / CERR 158 / Ecoflex 50** dataset.

It:

- reads exported DMA `.txt` files from:
  - `ss0/export`
  - `ss80/export`
  - `ts/export`
- parses filenames to identify:
  - material
  - concentration
  - test type
  - sample number
- applies configured temperature offsets for selected materials
- averages repeated curves
- generates stress-strain and temperature-sweep plots
- calculates room-temperature Young’s modulus from `ss0`
- writes processed results into `output_matlab/`

### 2) `dma_analysis.m`
Primary script for the **FM/Ecoflex** dataset stored as `.csv` files in `DMA_FM/`.

It:

- parses FM filenames
- separates room-temperature stress-strain, elevated-temperature stress-strain, and temperature sweep tests
- calculates Young’s modulus from a configurable strain window
- saves combined plots and summary tables
- writes results into `output_matlab/`

### 3) `compare_E.m`
Combines the processed FM and CERR summary tables and generates cross-material modulus comparisons.

### 4) `FinalCodeFoeThesis.m`
Builds final grouped bar charts and compares experimental data against Guth and Tsai model predictions.

### 5) `StatTest.m` / `stat_test.m`
Runs statistical comparisons on Young’s modulus values.

### 6) `GuthFit*.m`, `TsaiFit*.m`, `GuthModelOptimizationAll.m`, `TsaiModelOptiizationAll.m`
Fits or optimizes parameters for composite modulus models for specific materials or combined datasets.

### 7) `automate_dma.py`
Optional helper script that uses `pyautogui` to automate **Universal Analysis** GUI export steps.

This is useful for bulk-exporting DMA raw files to `.txt`, but it is highly system-specific and usually needs editing before use.

---

## Repository structure

```text
.
├── ss0/
│   └── export/                  # exported room-temperature DMA text files
├── ss80/
│   └── export/                  # exported elevated-temperature DMA text files
├── ts/
│   └── export/                  # exported temperature-sweep DMA text files
├── DMA_FM/                      # FM/Ecoflex raw CSV files
├── output_matlab/               # processed tables and plots
├── output_python/               # previously generated Python-side plots
├── mems_analysis.m              # main MEMS/CERR/Ecoflex analysis
├── dma_analysis.m               # main FM analysis
├── compare_E.m                  # combined modulus comparison
├── FinalCodeFoeThesis.m         # thesis-ready summary figure generation
├── StatTest.m                   # statistical tests
├── GuthFit*.m / TsaiFit*.m      # model fitting scripts
├── automate_dma.py              # Universal Analysis GUI automation
└── README.md
```

---

## Requirements

### MATLAB
The MATLAB scripts use features associated with:

- base MATLAB
- Curve Fitting Toolbox (`fit`)
- Optimization Toolbox (`lsqnonlin`, `fminbnd` in optimization workflows)
- Statistics and Machine Learning Toolbox (`kruskalwallis`, `multcompare`)

### Python
Only required for `automate_dma.py`.

Python dependencies:

```bash
pip install pyautogui
```

---

## Input data expectations

## MEMS / CERR / Ecoflex text exports

`mems_analysis.m` expects exported `.txt` files under:

- `ss0/export`
- `ss80/export`
- `ts/export`

### Expected filename patterns

For CERR materials:

```text
cerr_117_10v_ss0_s1.txt
cerr_158_30v_ts_s2.txt
```

For Ecoflex:

```text
ecoflex_50_ss0_s1.txt
ecoflex_50_ts_s2.txt
```

### Parsed fields

From these filenames, the script extracts:

- `material`: `cerr_117`, `cerr_158`, or `ecoflex_50`
- `concentration`: `10v`, `20v`, `30v`, `40v`, `50v`, or `N/A` for Ecoflex
- `test type`: inferred from folder and filename (`ss0`, `ss80`, `ts`)
- `sample`: `s1`, `s2`, etc.

### File content assumptions

The exported text files are expected to:

- contain a `StartOfData` marker, or at least readable numeric rows after header lines
- have consistent column counts
- follow the column order hard-coded in `mems_analysis.m`

Important columns used by the script are:

- temperature
- storage modulus
- stress
- strain

---

## FM CSV files

`dma_analysis.m` expects `.csv` files in `DMA_FM/` with names similar to:

```text
20240823_fm10v_eco50_ss0room_s3_t2_gyan.csv
20240717_fm40v_eco50_ts30-80_s1_t1_gyan.csv
```

### What the parser expects

The script splits the filename on underscores and expects to find:

- a concentration token like `fm10v`, `fm20v`, etc.
- a test-type token such as:
  - `ss0room` → room-temperature stress-strain
  - `ss75` or similar nonzero `ss...` → elevated-temperature stress-strain
  - `ts30-80` → temperature sweep
- a sample token like `s1`

### Required CSV columns

For stress-strain processing, it looks for either:

- `Static Strain Corrected` and `Static Stress Corrected`

or, as a fallback:

- `Static Strain` and `Static Stress`

For temperature sweeps, it looks for:

- `Sample Temperature`
- `Storage Modulus`

---

## How to run

## Recommended order

### Step 1 — Optional export from Universal Analysis
If your raw DMA files have not yet been exported to text:

- edit paths inside `automate_dma.py`
- activate the Universal Analysis window
- run the script

```bash
python automate_dma.py
```

### Step 2 — Process CERR / Ecoflex text exports
Open MATLAB and run:

```matlab
mems_analysis
```

Before running, update the hard-coded `base_dir` near the top of the file.

### Step 3 — Process FM CSV data
In MATLAB:

```matlab
dma_analysis
```

Before running, update the hard-coded paths:

- `dataFolderPath`
- `outputCsvPath`

### Step 4 — Create combined comparison figures
After both summary tables exist:

```matlab
compare_E
```

### Step 5 — Run final fitting/statistics scripts as needed
Examples:

```matlab
FinalCodeFoeThesis
StatTest
GuthFitFM
TsaiFitFM
```

---

## Key outputs

The most important generated files are usually:

### From `mems_analysis.m`

- `output_matlab/ss0_young_modulus_results.csv`
- `output_matlab/ss0_individual_modulus_data.csv`
- stress-strain comparison plots for CERR materials
- temperature-sweep comparison plots for CERR materials
- per-material room-temperature modulus bar charts

### From `dma_analysis.m`

- `output_matlab/fm_dma.csv`
- `output_matlab/fm_dma_individual_modulus_data.csv`
- `FM_StressStrain_Combined.png`
- `FM_TempSweep_StorageModulus.png`
- `FM_YoungsModulus_BarChart.png`

### From downstream scripts

- `Combined_Material_Modulus_Comparison.png`
- `FinalCodeforThesis_data.csv`
- additional model-fit and summary plots

---

## Output table format

The main summary CSV files use this structure:

| Column | Meaning |
|---|---|
| `Material` | Material name |
| `Concentration` | Filler concentration label |
| `YoungModulus_MPa` | Mean Young’s modulus in MPa |
| `YoungModulus_SE` | Standard error of the mean |
| `N_Samples` | Number of samples used |

The individual-level output files store one modulus estimate per source file/sample.

---

## Important configuration points

Several scripts use **hard-coded absolute Windows paths**.

Before running on a new machine, update paths such as:

- `base_dir` in `mems_analysis.m`
- `dataFolderPath` in `dma_analysis.m`
- `outputCsvPath` in `dma_analysis.m`
- `outputFile` in `FinalCodeFoeThesis.m`
- `input_folder` in `automate_dma.py`

There are also material-specific settings embedded in the scripts, including:

- temperature offsets in `mems_analysis.m`
- modulus fit strain window in `dma_analysis.m`
- aspect ratio and matrix/filler modulus assumptions in the Guth/Tsai model scripts

---

## Known limitations

- The project is **filename-convention dependent**. Renaming files can break parsing.
- The main scripts are written as standalone analysis scripts, not as a packaged toolbox.
- Several workflows duplicate logic across scripts.
- `automate_dma.py` is fragile because it depends on GUI focus, menu order, and screen timing.
- Some outputs are overwritten or appended depending on existing files, so keeping backups is a good idea.
- Many plots and model parameters are tuned for this specific dataset and may need adjustment for new materials.

---

## Suggested cleanup before sharing publicly

If you plan to make this repository public, a good next step would be to:

1. replace hard-coded paths with relative paths or a config file
2. move reusable code into helper functions
3. add a single top-level runner script
4. separate raw data, processed data, and final figures more clearly
5. document the experimental naming convention in one place
6. remove intermediate or duplicate scripts once the final workflow is settled

---

## Minimal reproducible workflow

For most users, the shortest useful path is:

```matlab
% 1) Process MEMS/CERR text exports
mems_analysis

% 2) Process FM CSV data
dma_analysis

% 3) Compare all materials together
compare_E

% 4) Generate final summary/model figures
FinalCodeFoeThesis
```

---

## Notes

This repository appears to mix:

- core processing scripts
- one-off analysis scripts
- model fitting experiments
- thesis/paper figure generation

That is normal for an active research codebase, but it means the **main scripts to start with are `mems_analysis.m` and `dma_analysis.m`**.

