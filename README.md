# MATLAB workflow for DMA composite analysis

This repository contains a MATLAB-based workflow for processing dynamic mechanical analysis (DMA) data from soft composite materials, extracting Young's modulus, and comparing experimental trends with simple composite models.

At a high level, the MATLAB code does three things:

1. **Reads raw DMA exports** from multiple test conditions and materials.
2. **Converts replicate experiments into summary modulus values** and publication-style plots.
3. **Combines those summary results** for cross-material comparison, model fitting, and statistical analysis.

## Recommended MATLAB entry-point scripts

If you only want the main MATLAB workflow, these are the files to run.

### 1) `mems_analysis.m`
Main processing script for the MEMS / Cerro / Ecoflex dataset.

**What it does**
- Reads DMA `.txt` exports from the `ss0`, `ss80`, and `ts` folders.
- Parses filenames to identify material, filler concentration, test type, and sample ID.
- Applies configured temperature offsets where needed.
- Aggregates replicate curves and generates summary plots.
- Computes Young's modulus from the `ss0` tests.

**Main outputs**
- `output_matlab/ss0_young_modulus_results.csv`
- `output_matlab/ss0_individual_modulus_data.csv`
- stress-strain / temperature-sweep figures for the Cerro datasets
- modulus bar charts for the MEMS-derived materials

### 2) `dma_analysis.m`
Main processing script for the FM composite DMA dataset.

**What it does**
- Reads DMA `.csv` files from `DMA_FM/`.
- Separates stress-strain and temperature-sweep tests from filename metadata.
- Calculates Young's modulus from a defined low-strain region.
- Aggregates replicate data and exports summary tables.
- Generates FM-specific summary figures.

**Main outputs**
- `output_matlab/fm_dma.csv`
- `output_matlab/fm_dma_individual_modulus_data.csv`
- `FM_StressStrain_Combined.png`
- `FM_TempSweep_StorageModulus.png`
- `FM_YoungsModulus_BarChart.png`

### 3) `compare_E.m`
Main comparison script for combining processed results across material systems.

**What it does**
- Loads the processed outputs from `mems_analysis.m` and `dma_analysis.m`.
- Combines modulus values across Cerr 117, Cerr 158, FM, and Ecoflex.
- Adds theoretical/reference curves based on Guth and Tsai formulations.
- Produces a high-level comparison figure across concentration.

**Typical output**
- `Combined_Material_Modulus_Comparison.png`

## Optional downstream MATLAB scripts

These scripts are useful after the main processed CSV files have been created.

### Model-fitting scripts
Use these when you want fitted composite-model parameters rather than only the raw comparison plots.

- `GuthFitFM.m`
- `GuthFitCerr117.m`
- `GuthFitCerr158.m`
- `TsaiFitFM.m`
- `TsaiFitCerr117.m`
- `TsaiFitCerr158.m`
- `GuthModelOptimizationAll.m`
- `TsaiModelOptiizationAll.m`
- `model_fit.m`
- `FinalCodeFoeThesis.m`

These scripts all sit **downstream** of the processed modulus CSV files and are best thought of as analysis/fitting/final-figure scripts rather than raw-data processing scripts.

### Statistical analysis scripts
- `stat_test.m` — more complete statistical workflow using individual-sample modulus tables.
- `StatTest.m` — simpler comparison workflow based on the summary modulus tables.

## High-level analysis approach

The MATLAB pipeline follows this overall logic:

### Step 1: Organize raw DMA files by experiment type
The code expects the raw files to already be grouped by test type, for example:

- `ss0/` for near-room-temperature stress-strain tests
- `ss80/` for elevated-temperature stress-strain tests
- `ts/` for temperature sweeps
- `DMA_FM/` for the FM CSV dataset

### Step 2: Use filenames as metadata
The scripts rely heavily on filenames to recover:
- material identity
- filler concentration
- test type
- sample number

That means filename consistency is important for the workflow to run correctly.

### Step 3: Convert raw curves into modulus values
For each material/concentration group, the code:
- reads the raw stress-strain or storage-modulus data
- groups replicate measurements
- computes Young's modulus from the low-strain region
- stores both individual-sample and grouped summary results

### Step 4: Compare material systems
Once the summary CSV files exist, the comparison scripts combine the FM and MEMS-derived datasets into a single figure and compare them against simple composite models.

### Step 5: Fit models or run statistics
Optional scripts can then be used to:
- fit Guth model parameters
- fit Tsai model parameters
- generate thesis/paper figures
- perform nonparametric statistical tests

## Minimal run order

For a simple end-to-end MATLAB workflow, run:

1. `mems_analysis.m`
2. `dma_analysis.m`
3. `compare_E.m`

Then optionally run any of the fitting or statistical analysis scripts.

## Notes before running

- Some scripts contain **hard-coded local paths** and may need to be edited before running on a new machine.
- The code assumes the expected folder structure already exists.
- The analysis depends on consistent filename formatting.
- Several scripts are alternate or thesis-specific versions of the same downstream idea, so the most important files are still:
  - `mems_analysis.m`
  - `dma_analysis.m`
  - `compare_E.m`

## In one sentence

This MATLAB codebase turns raw DMA experiments into processed modulus tables, summary plots, and cross-material comparison figures for soft composite systems.
