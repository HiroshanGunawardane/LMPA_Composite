% Script to Plot Combined Material Modulus vs Concentration with Exponential Fit
% ** Version with Multiplicative Fit Starting at Fixed 0% FM Eco Value **

clear; clc; close all;

% --- Configuration ---
outputDir = 'D:\Guien MEMS Lab Final\new_method\output_matlab'; % Directory containing the CSVs
statsOutputDir = fullfile(outputDir, 'statistical_analysis'); % Subdir for saving this specific plot

% Input filenames for INDIVIDUAL sample results
ss0IndividualFile = fullfile(outputDir, 'ss0_individual_modulus_data.csv');
fmIndividualFile = fullfile(outputDir, 'fm_dma_individual_modulus_data.csv');

% Output filename for the plot
outputPlotFile = fullfile(statsOutputDir, 'plot_combined_modulus_vs_concentration_expfit_multiplicative_offset.png'); % Updated filename

% Plotting Configuration
plotColor = [0.5 0 0.8]; % A distinct purple color
fitLineStyle = '--';
fitLineWidth = 1.5;
barWidth = 0.6;

fprintf('--- Plotting Combined Modulus vs. Concentration (Multiplicative Fit Starting at Fixed FM Eco Offset) ---\n');

% --- Create Output Directory ---
if ~isfolder(statsOutputDir), mkdir(statsOutputDir); fprintf('Created directory: %s\n', statsOutputDir); end

% --- Load Data ---
% (Loading code remains the same as the previous corrected version)
dataSS0 = []; dataFM = []; % Initialize
try
    opts_ss0 = detectImportOptions(ss0IndividualFile);
    opts_ss0 = setvartype(opts_ss0, {'Material', 'Concentration', 'SampleID'}, 'string');
    opts_ss0 = setvartype(opts_ss0, {'Individual_YoungModulus_MPa', 'R_Squared'}, 'double');
    dataSS0 = readtable(ss0IndividualFile, opts_ss0);
    fprintf('Loaded %d rows from %s\n', height(dataSS0), ss0IndividualFile);
catch ME_ss0
    warning('Failed to load SS0 individual data: %s\n%s', ss0IndividualFile, ME_ss0.message);
end
try
    opts_fm = detectImportOptions(fmIndividualFile);
    opts_fm = setvartype(opts_fm, {'Material', 'Concentration', 'SampleFileName'}, 'string'); % Adjust column name if needed
    opts_fm = setvartype(opts_fm, {'Individual_YoungModulus_MPa'}, 'double');
    dataFM = readtable(fmIndividualFile, opts_fm);
    fprintf('Loaded %d rows from %s\n', height(dataFM), fmIndividualFile);
    if ismember('SampleFileName', dataFM.Properties.VariableNames) && ~ismember('SampleID', dataFM.Properties.VariableNames), dataFM = renamevars(dataFM, 'SampleFileName', 'SampleID'); fprintf('Renamed "SampleFileName" to "SampleID" in FM data.\n'); end
    if ~ismember('R_Squared', dataFM.Properties.VariableNames), dataFM.R_Squared = NaN(height(dataFM), 1); fprintf('Added NaN "R_Squared" column to FM data.\n'); end
    if ~isempty(dataSS0) && ~ismember('SampleID', dataSS0.Properties.VariableNames), warning('Missing "SampleID" in SS0 data. Creating dummy IDs.'); dataSS0.SampleID = string(sprintfc('SS0_Sample_%d', 1:height(dataSS0))); end
catch ME_fm
    warning('Failed to load FM individual data: %s\n%s', fmIndividualFile, ME_fm.message);
end
if isempty(dataSS0) && isempty(dataFM), error('Failed to load data from both input files. Cannot proceed.'); end

% --- Combine and Preprocess Data ---
% (Preprocessing logic remains the same: Isolate FM Eco, remove others, combine, standardize)
% 1. Identify and Isolate FM Ecoflex data
dataFM_Eco = [];
if ~isempty(dataFM)
    fm_eco_idx = find(strcmpi(dataFM.Material, 'fm') & ...
                      (strcmpi(dataFM.Concentration, 'Ecoflex 50') | strcmpi(dataFM.Concentration, '0v')));
    if ~isempty(fm_eco_idx)
        dataFM_Eco = dataFM(fm_eco_idx, :);
        fprintf('Isolated %d Ecoflex samples from FM data.\n', height(dataFM_Eco));
        dataFM(fm_eco_idx, :) = [];
        fprintf(' -> Removed Ecoflex samples from main FM dataset.\n');
    else
        warning('No Ecoflex 50 or 0v samples found in FM data (%s).', fmIndividualFile);
    end
end
% 2. Remove any Ecoflex data from SS0 data
if ~isempty(dataSS0)
    ss0_eco_idx = find(contains(dataSS0.Material, 'ecoflex', 'IgnoreCase', true));
    if ~isempty(ss0_eco_idx)
        fprintf('Removing %d potential Ecoflex samples found in SS0 data.\n', length(ss0_eco_idx));
        dataSS0(ss0_eco_idx, :) = [];
    end
end
% 3. Combine the *remaining* (non-Ecoflex) data
commonCols = {'Material', 'Concentration', 'SampleID', 'Individual_YoungModulus_MPa'};
allIndividualData_NonEco = table();
if ~isempty(dataSS0)
    ss0_cols_to_use = intersect(commonCols, dataSS0.Properties.VariableNames, 'stable');
    allIndividualData_NonEco = [allIndividualData_NonEco; dataSS0(:, ss0_cols_to_use)];
end
if ~isempty(dataFM)
    fm_cols_to_use = intersect(commonCols, dataFM.Properties.VariableNames, 'stable');
    allIndividualData_NonEco = [allIndividualData_NonEco; dataFM(:, fm_cols_to_use)];
end
if isempty(allIndividualData_NonEco) && isempty(dataFM_Eco), error('No valid data remains after preprocessing.');
elseif isempty(allIndividualData_NonEco), warning('No non-Ecoflex data found. Plot will only show Ecoflex point if available.');
elseif isempty(dataFM_Eco), warning('No FM Ecoflex data found. Plot will only show non-Ecoflex data.'); end
fprintf('Combined non-Ecoflex data: %d rows.\n', height(allIndividualData_NonEco));
% 4. Preprocess the combined *non-Ecoflex* data
if ~isempty(allIndividualData_NonEco)
    nanModulusRows = isnan(allIndividualData_NonEco.Individual_YoungModulus_MPa);
    if any(nanModulusRows), fprintf('Removing %d non-Ecoflex rows with NaN Modulus values.\n', sum(nanModulusRows)); allIndividualData_NonEco(nanModulusRows, :) = []; end
    allIndividualData_NonEco.Material = categorical(allIndividualData_NonEco.Material);
    materialNames = categories(allIndividualData_NonEco.Material);
    materialMap = containers.Map('KeyType', 'char', 'ValueType', 'char'); needsRemap = false;
    for i = 1:length(materialNames)
        matLower = lower(strtrim(materialNames{i}));
        if strcmp(matLower, 'fm'), materialMap(matLower) = 'FM'; needsRemap = true;
        elseif contains(matLower, 'cerr_117'), materialMap(matLower) = 'Cerr 117'; needsRemap = true;
        elseif contains(matLower, 'cerr_158'), materialMap(matLower) = 'Cerr 158'; needsRemap = true;
        else, materialMap(matLower) = materialNames{i}; end
    end
    if needsRemap
        allIndividualData_NonEco.Material = cellfun(@(x) materialMap(lower(strtrim(x))), cellstr(allIndividualData_NonEco.Material), 'UniformOutput', false);
        allIndividualData_NonEco.Material = categorical(allIndividualData_NonEco.Material);
    end
    allIndividualData_NonEco = allIndividualData_NonEco(ismember(allIndividualData_NonEco.Material, ["Cerr 117", "Cerr 158", "FM"]), :);
    fprintf('Standardized non-Ecoflex material names.\n');
    numericConcentration = NaN(height(allIndividualData_NonEco), 1);
    for i = 1:height(allIndividualData_NonEco)
        concStr = lower(strtrim(allIndividualData_NonEco.Concentration{i}));
        if endsWith(concStr, 'v'), numPart = sscanf(concStr, '%fv'); if ~isempty(numPart), numericConcentration(i) = numPart; end
        else, warning('Non-Ecoflex row found with unexpected concentration format: "%s" for material %s. Skipping row.', allIndividualData_NonEco.Concentration{i}, char(allIndividualData_NonEco.Material(i))); end
    end
    allIndividualData_NonEco.ConcentrationNumeric = numericConcentration;
    nanConcRows = isnan(allIndividualData_NonEco.ConcentrationNumeric);
    if any(nanConcRows), fprintf('Removing %d non-Ecoflex rows where Concentration could not be parsed.\n', sum(nanConcRows)); allIndividualData_NonEco(nanConcRows, :) = []; end
    if isempty(allIndividualData_NonEco), warning('No valid non-Ecoflex data remaining after concentration parsing.'); end
    fprintf('Parsed non-Ecoflex concentrations.\n');
else, fprintf('Skipping non-Ecoflex data preprocessing as it is empty.\n'); end

% --- Aggregate Data ---
% (Aggregation logic remains the same, using isolated FM Eco for Conc 0)
if ~isempty(allIndividualData_NonEco), uniqueConcentrations = unique(allIndividualData_NonEco.ConcentrationNumeric); uniqueConcentrations = uniqueConcentrations(uniqueConcentrations > 0); else, uniqueConcentrations = []; end
if ~isempty(dataFM_Eco), uniqueConcentrations = [0; uniqueConcentrations]; end
uniqueConcentrations = sort(unique(uniqueConcentrations));
if isempty(uniqueConcentrations), error('No concentrations found to aggregate. Check input data.'); end
aggregatedResults = table('Size',[length(uniqueConcentrations), 4], 'VariableTypes', {'double', 'double', 'double', 'uint32'}, 'VariableNames', {'Concentration', 'MeanModulus_MPa', 'SEM_Modulus_MPa', 'N_Samples'});
fprintf('Aggregating data...\n');
for i = 1:length(uniqueConcentrations)
    conc = uniqueConcentrations(i); aggregatedResults.Concentration(i) = conc; dataSubset = [];
    if conc == 0
        if ~isempty(dataFM_Eco), dataSubset = dataFM_Eco.Individual_YoungModulus_MPa; fprintf('  Conc %d%%: Using %d FM Ecoflex samples.\n', conc, numel(dataSubset)); else, fprintf('  Conc %d%%: No FM Ecoflex data available.\n', conc); end
    else
        if ~isempty(allIndividualData_NonEco)
            materialsToCombine = ["Cerr 117", "Cerr 158", "FM"];
            dataSubset = allIndividualData_NonEco.Individual_YoungModulus_MPa(allIndividualData_NonEco.ConcentrationNumeric == conc & ismember(allIndividualData_NonEco.Material, materialsToCombine));
            fprintf('  Conc %d%%: Combining %d samples from Cerr117/Cerr158/FM.\n', conc, numel(dataSubset));
        else, fprintf('  Conc %d%%: No non-Ecoflex data available.\n', conc); end
    end
    dataSubset = dataSubset(~isnan(dataSubset)); n = numel(dataSubset); aggregatedResults.N_Samples(i) = n;
    if n > 0
        aggregatedResults.MeanModulus_MPa(i) = mean(dataSubset);
        if n > 1, aggregatedResults.SEM_Modulus_MPa(i) = std(dataSubset) / sqrt(n); else, aggregatedResults.SEM_Modulus_MPa(i) = NaN; fprintf('  -> Note: SEM is NaN for Conc %d%% (N=1).\n', conc); end
    else, aggregatedResults.MeanModulus_MPa(i) = NaN; aggregatedResults.SEM_Modulus_MPa(i) = NaN; warning('No valid data found for concentration %d%% during aggregation.', conc); end
end
disp('Aggregated Results:'); disp(aggregatedResults);
aggregatedResults = aggregatedResults(~isnan(aggregatedResults.MeanModulus_MPa), :);
if height(aggregatedResults) < 2, error('Insufficient aggregated data points (need at least 2) for plotting/fitting. Check aggregation results.'); end

% --- Perform Exponential Curve Fit with FIXED Offset using y = y_offset * exp(b*x) model ---
fprintf('Performing exponential fit (y = y_offset * exp(b*x))...\n');
xDataFit = aggregatedResults.Concentration;
yDataFit = aggregatedResults.MeanModulus_MPa;

% *** Get the fixed offset value (mean modulus at 0% from FM Eco) ***
idx_0_conc = find(aggregatedResults.Concentration == 0);
fixed_offset_value = NaN; % Default if 0% data is missing

if isempty(idx_0_conc)
    error('Cannot find 0%% concentration data in aggregated results. This model requires the 0%% value as a fixed offset.');
    % Note: We are not falling back to a different model type here.
else
    fixed_offset_value = aggregatedResults.MeanModulus_MPa(idx_0_conc(1));
    % Ensure offset is positive for this model type
    if fixed_offset_value <= 0
        error('The 0%% concentration modulus (%.4f) must be positive for the y=y0*exp(b*x) model.', fixed_offset_value);
    end
    fprintf('   Using fixed multiplier/offset (y_offset) = %.4f MPa (from aggregated 0%% FM Ecoflex data).\n', fixed_offset_value);

    % *** Define the Multiplicative FIXED offset exponential model type ***
    % y = y_offset * exp(b*x), where y_offset is known
    expFitType = fittype('y_offset * exp(b*x)', ...
                         'independent', 'x', ...
                         'problem', 'y_offset', ... % y_offset is known
                         'coefficients', {'b'});     % Only fit b

    opts = fitoptions(expFitType);
    % Provide start point only for 'b'
    opts.StartPoint = [0.01]; % Initial guess for rate 'b'
    opts.Lower = [0];         % Constrain b >= 0 (usually expect increase)
end

% --- Perform the fit ---
fitFailed = false;
expFitModel = []; gof = []; % Initialize
fitEquation = 'Fit Failed'; fitR2 = NaN; fitCoeffs = [];

% Check if we have the offset and enough data points (need at least 2 for 1 coeff)
if ~isnan(fixed_offset_value) && height(xDataFit) >= 2
    try
        [expFitModel, gof] = fit(xDataFit, yDataFit, expFitType, opts, 'problem', fixed_offset_value);
        fitCoeffs = coeffvalues(expFitModel); % Should be [b]
        fitR2 = gof.rsquare;
        fprintf('Fit successful (multiplicative fixed offset): b=%.4g, (y_offset=%.4g), R^2=%.4f\n', ...
                fitCoeffs(1), fixed_offset_value, fitR2);
        % *** Corrected Equation String for this model ***
        fitEquation = sprintf('y = %.3g*exp(%.3gx)', fixed_offset_value, fitCoeffs(1));
    catch ME_fit
        warning('Exponential fit failed: %s', ME_fit.message);
        fitFailed = true;
    end
else
    warning('Skipping fit: Offset value not available or insufficient data points (%d).', height(xDataFit));
    fitFailed = true;
end


% --- Generate Plot ---
fprintf('Generating plot...\n');
hFig = figure('Name', 'Combined Modulus vs Concentration (Multiplicative Fit)');
ax = axes('Parent', hFig);
hold(ax, 'on');

% 1. Bar Chart using Aggregated Data
bar(ax, aggregatedResults.Concentration, aggregatedResults.MeanModulus_MPa, barWidth, ...
    'FaceColor', plotColor, 'EdgeColor', 'k');

% 2. Error Bars using Aggregated Data
semToPlot = aggregatedResults.SEM_Modulus_MPa;
semToPlot(isnan(semToPlot) | semToPlot < 0) = 0;
errorbar(ax, aggregatedResults.Concentration, aggregatedResults.MeanModulus_MPa, semToPlot, ...
         'k.', 'LineWidth', 1, 'CapSize', 6, 'LineStyle', 'none');

% 3. Plot Exponential Fit Curve
legendEntryFitText = 'Exponential Fit'; % Default legend text
if ~fitFailed && ~isempty(expFitModel)
    xFitPlot = linspace(min(xDataFit), max(xDataFit), 200);
    yFitPlot = feval(expFitModel, xFitPlot); % Evaluate the fitted model
    plot(ax, xFitPlot, yFitPlot, 'Color', 'r', 'LineStyle', fitLineStyle, 'LineWidth', fitLineWidth); % Red fit line
    legendEntryFitText = sprintf('Fit (R^2 = %.3f)', fitR2);
    fprintf('Plotted fit curve.\n');
else
    warning('Skipping fit curve plot as fit failed or model is empty.');
    legendEntryFitText = 'Fit Failed';
end

% --- Customize Plot ---
xlabel(ax, 'Concentration (%)');
ylabel(ax, 'Young''s Modulus (MPa)');
title(ax, {'Combined Young''s Modulus vs. Concentration', '(Fit: y = y_0*exp(bx), y_0 Fixed to 0% FM Eco Value)'}); % Updated title
grid(ax, 'on');
ax.XTick = uniqueConcentrations;

if ~isempty(uniqueConcentrations)
    ax.XLim = [min(uniqueConcentrations)-5, max(uniqueConcentrations)+5];
else
    ax.XLim = [-5, 55];
end

maxYPlot = 0;
if ~isempty(aggregatedResults), maxYPlot = max(maxYPlot, max(aggregatedResults.MeanModulus_MPa + semToPlot, [], 'omitnan')); end
if ~fitFailed && ~isempty(expFitModel) && exist('yFitPlot', 'var'), maxYPlot = max(maxYPlot, max(yFitPlot, [], 'omitnan')); end
if maxYPlot <= 0, maxYPlot = 1; end
ax.YLim = [0, maxYPlot * 1.15];

% Add Fit Equation Annotation
if ~fitFailed
    textX = ax.XLim(1) + 0.05 * diff(ax.XLim);
    textY = ax.YLim(2) - 0.1 * diff(ax.YLim);
    text(ax, textX, textY, fitEquation, 'VerticalAlignment', 'top', 'FontSize', 9, 'BackgroundColor', 'w', 'EdgeColor', 'k');
end

legend(ax, {'Aggregated Data', legendEntryFitText}, 'Location', 'northwest');
hold(ax, 'off');

% --- Save Plot ---
try
    saveas(hFig, outputPlotFile);
    fprintf('Saved combined plot with multiplicative fixed offset fit to: %s\n', outputPlotFile);
catch ME_save
    warning('Failed to save plot: %s', ME_save.message);
end

fprintf('\n--- Combined Plotting Script Complete ---\n');