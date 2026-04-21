clc; clear; close all;
dataFolderPath = 'C:\Users\12369\Sync\UoW\Paper9 RAL ThemoE\2025_05_DMA_Final\finalCode\new_method\DMA_FM';
materialIdentifier = 'fm';
outputCsvPath = 'C:\Users\12369\Sync\UoW\Paper9 RAL ThemoE\2025_05_DMA_Final\finalCode\new_method\output_matlab\fm_dma.csv';
outputPlotPrefix = 'FM';
processFMData(dataFolderPath, materialIdentifier, outputCsvPath, outputPlotPrefix);
function processFMData(dataFolderPath, materialIdentifier, outputCsvPath, outputPlotPrefix)
% Processes DMA data for FM-Ecoflex composites from CSV files using strsplit.
% Combines Room Temp and Elevated Temp Stress-Strain curves onto one plot.
% Uses plot + fill for standard error visualization.
% Calculates and saves both summary (mean/SEM) and individual Young's Modulus results.
% Handles original CSV headers and provides compatibility for older MATLAB versions.
%
% Args:
%   dataFolderPath (char): Path to the directory containing the CSV data files.
%   materialIdentifier (char): Base name for the material (e.g., 'fm').
%   outputCsvPath (char): Full path for the output *summary* CSV file.
%   outputPlotPrefix (char): Prefix for saving plot filenames.

% --- Configuration ---
strainForModulusFit = [1.0, 3.0]; % Strain range [%] for Young's Modulus
commonStrainPoints_SS = 100;
commonTempPoints_TS = 100;
plotFaceAlpha = 0.2; % Transparency for the fill region

% --- Initialization ---
fprintf('Starting DMA data processing for: %s\n', dataFolderPath);
rawData = struct();
files = dir(fullfile(dataFolderPath, '*.csv'));
if isempty(files), error('No CSV files found in: %s', dataFolderPath); end

% --- Define Columns (Use original header names) ---
staticStrainColName = 'Static Strain Corrected'; staticStressColName = 'Static Stress Corrected';
sampleTempColName = 'Sample Temperature'; storageModColName = 'Storage Modulus';
altStaticStrainColName = 'Static Strain'; altStaticStressColName = 'Static Stress';

try
    opts = detectImportOptions(fullfile(files(1).folder, files(1).name), 'VariableNamingRule', 'preserve'); availableCols = opts.VariableNames;
catch ME_opts, error('Could not read first CSV file: %s\n%s', fullfile(files(1).folder, files(1).name), ME_opts.message); end

if ismember(staticStrainColName, availableCols) && ismember(staticStressColName, availableCols), actualStaticStrainCol = staticStrainColName; actualStaticStressCol = staticStressColName; fprintf('Using columns: "%s", "%s" for Stress-Strain\n', actualStaticStrainCol, actualStaticStressCol);
elseif ismember(altStaticStrainColName, availableCols) && ismember(altStaticStressColName, availableCols), actualStaticStrainCol = altStaticStrainColName; actualStaticStressCol = altStaticStressColName; fprintf('Using columns: "%s", "%s" for Stress-Strain\n', actualStaticStrainCol, actualStaticStressCol);
else error('Could not find required Static Strain/Stress columns ("%s" or "%s").', staticStrainColName, altStaticStrainColName); end
if ismember(sampleTempColName, availableCols) && ismember(storageModColName, availableCols), actualSampleTempCol = sampleTempColName; actualStorageModCol = storageModColName; fprintf('Using columns: "%s", "%s" for Temp Sweep\n', actualSampleTempCol, actualStorageModCol);
else error('Could not find required Temp Sweep columns ("%s", "%s").', sampleTempColName, storageModColName); end

fprintf('Found %d potential CSV files. Parsing filenames...\n', length(files));

% --- File Parsing and Data Loading ---
parsedFileCount = 0; skippedFileCount = 0;
for i = 1:length(files)
    fname = files(i).name; baseFname = strrep(fname, '.csv', ''); parts = strsplit(baseFname, '_');
    if length(parts) < 5, skippedFileCount = skippedFileCount + 1; fprintf('Skipping %s: Not enough parts.\n', fname); continue; end
    try
        % Adjusted Parsing: Expects format like 'fm_fmXXv_...'
        concPart = parts{2};
        if ~startsWith(concPart, 'fm') || ~endsWith(concPart, 'v'), skippedFileCount = skippedFileCount + 1; fprintf('Skipping %s: Conc part "%s" format error.\n', fname, concPart); continue; end
        concValue = sscanf(concPart, 'fm%dv'); if isempty(concValue), skippedFileCount = skippedFileCount + 1; fprintf('Skipping %s: Could not extract conc value from "%s".\n', fname, concPart); continue; end
        concentrationLabel = sprintf('%dv', concValue); concentrationField = sprintf('v%d', concValue);

        testTypeRaw = parts{4}; samplePart = parts{5}; if ~startsWith(samplePart, 's'), skippedFileCount = skippedFileCount + 1; fprintf('Skipping %s: Sample part "%s" format error.\n', fname, samplePart); continue; end
        sampleNum = sscanf(samplePart, 's%d'); if isempty(sampleNum), skippedFileCount = skippedFileCount + 1; fprintf('Skipping %s: Could not extract sample number from "%s".\n', fname, samplePart); continue; end

        parsedFileCount = parsedFileCount + 1;
        if contains(testTypeRaw, 'ts', 'IgnoreCase', true), testType = 'ts';
        elseif contains(testTypeRaw, 'ss0', 'IgnoreCase', true), testType = 'ss0';
        elseif contains(testTypeRaw, 'ss', 'IgnoreCase', true) && ~contains(testTypeRaw, 'ss0', 'IgnoreCase', true), testType = 'ss_elevated'; % Ensure it's not ss0
        else, skippedFileCount = skippedFileCount + 1; parsedFileCount = parsedFileCount -1; fprintf('Skipping %s: Unknown test type "%s".\n', fname, testTypeRaw); continue; end % Decrement parsed if skipping here

        if ~isfield(rawData, concentrationField), rawData.(concentrationField) = struct('label', concentrationLabel); end
        if ~isfield(rawData.(concentrationField), testType), rawData.(concentrationField).(testType) = struct('samples', {{}}, 'filenames', {{}}); end

        filePath = fullfile(files(i).folder, fname);
        try
            opts = detectImportOptions(filePath, 'VariableNamingRule', 'preserve');
            if strcmp(testType, 'ts'), selectedCols = {actualSampleTempCol, actualStorageModCol}; else, selectedCols = {actualStaticStrainCol, actualStaticStressCol}; end
            if ~all(ismember(selectedCols, opts.VariableNames)), skippedFileCount = skippedFileCount + 1; parsedFileCount = parsedFileCount -1; fprintf('Skipping %s: Missing required columns.\n', fname); continue; end % Decrement parsed

            opts.SelectedVariableNames = selectedCols; varTypes = repmat({'double'}, 1, length(opts.SelectedVariableNames));
            opts = setvartype(opts, opts.SelectedVariableNames, varTypes); opts = setvaropts(opts, 'FillValue', NaN);
            T = readtable(filePath, opts); if isempty(T) || all(all(ismissing(T))), skippedFileCount = skippedFileCount + 1; parsedFileCount = parsedFileCount -1; fprintf('Skipping %s: Empty or all missing data.\n', fname); continue; end % Decrement parsed

            sampleIdx = length(rawData.(concentrationField).(testType).samples) + 1;
            rawData.(concentrationField).(testType).samples{sampleIdx} = T; rawData.(concentrationField).(testType).filenames{sampleIdx} = fname;
        catch ME_read, fprintf('  ERROR reading file %s: %s. Skipping.\n', fname, ME_read.message); skippedFileCount = skippedFileCount + 1; parsedFileCount = parsedFileCount -1; continue; end % Decrement parsed
    catch ME_parse, fprintf('  ERROR parsing/processing file %s: %s. Skipping.\n', fname, ME_parse.message); skippedFileCount = skippedFileCount + 1; parsedFileCount = parsedFileCount -1; continue; end % Decrement parsed
end
fprintf('Successfully parsed %d filenames. Skipped %d files.\n', parsedFileCount, skippedFileCount);
if parsedFileCount == 0, error('No files matched the expected naming pattern "%s_fmXXv_...". Check filenames.', materialIdentifier); end
fprintf('Finished loading data. Processing and plotting...\n');

% --- Data Processing and Plotting ---
concFields = fieldnames(rawData); concNumeric = zeros(length(concFields), 1); concLabelsMap = containers.Map;
for i = 1:length(concFields), field = concFields{i}; concNumeric(i) = sscanf(field, 'v%d'); if isfield(rawData.(field),'label'), concLabelsMap(field) = rawData.(field).label; else, concLabelsMap(field) = strrep(field,'v',''); if ~strcmp(concLabelsMap(field),'0'), concLabelsMap(field) = [concLabelsMap(field), 'v']; end; end; end
[~, sortIdx] = sort(concNumeric); concFieldsSorted = concFields(sortIdx);

% Colormap
baseCmap = autumn(10);  % Changed from summer to autumn
customCmap = baseCmap(max(1,end-8):end-2, :);
numColorsNeeded = length(concFieldsSorted); % Adjusted for FM only

if numColorsNeeded > 0 && size(customCmap, 1) < numColorsNeeded
    customCmap = interp1(linspace(0, 1, size(customCmap, 1)), customCmap, ...
                         linspace(0, 1, numColorsNeeded), 'linear');
    fprintf('Warning: Interpolating colormap.\n');
end

colors = containers.Map;
colorIdx = 6;

for i = 1:length(concFieldsSorted)
    field = concFieldsSorted{i};
    label = concLabelsMap(field);
    if colorIdx <= size(customCmap, 1)
        colors(label) = customCmap(colorIdx,:);
        colorIdx = colorIdx + 1;
    else
        colors(label) = rand(1,3);
        fprintf('Warning: Using random color for %s.\n', label);
    end
end

% Initialize Results Storage
youngModulusResults = table('Size', [0, 5], 'VariableTypes', {'string', 'string', 'double', 'double', 'uint8'}, 'VariableNames', {'Material', 'Concentration', 'YoungModulus_MPa', 'YoungModulus_SE', 'N_Samples'});
resultsSS0 = struct(); % For temporary storage of individual moduli per group
individual_modulus_data_fm = {}; % *** NEW: For storing individual results ***

% --- 1. Process and Plot COMBINED Stress-Strain (Using FILL for SE) ---
hFigSS = figure('Name', 'Combined Stress Strain', 'Position', [100, 400, 700, 500]);
axSS = axes('Parent', hFigSS); hold(axSS, 'on'); grid(axSS, 'off');
xlabel(axSS, 'Strain (%)'); ylabel(axSS, 'Stress (MPa)');
legendEntriesSS = {}; plotHandlesSS = []; maxStrainOverallSS = 0; maxStressOverallSS = 0;

for i = 1:length(concFieldsSorted)
    concField = concFieldsSorted{i}; concLabel = concLabelsMap(concField);

    % --- Process SS0 (Room Temp) ---
    if isfield(rawData, concField) && isfield(rawData.(concField), 'ss0') && ~isempty(rawData.(concField).ss0.samples)
        samples = rawData.(concField).ss0.samples; numSamples = length(samples);
        allStrains_ss0 = cell(1, numSamples); allStresses_ss0 = cell(1, numSamples); individualModuli = []; % Temp storage for mean/sem calc
        minStrain_ss0 = inf; maxStrain_ss0 = -inf;

        for s = 1:numSamples % Data extraction and cleaning loop
            try
                data = samples{s};
                current_filename = rawData.(concField).ss0.filenames{s}; % Get filename for this sample

                if ~ismember(actualStaticStrainCol, data.Properties.VariableNames) || ~ismember(actualStaticStressCol, data.Properties.VariableNames), continue; end
                strain = data.(actualStaticStrainCol) * 100; stress = data.(actualStaticStressCol) / 1e6;
                validIdx = ~isnan(strain) & ~isinf(strain) & ~isnan(stress) & ~isinf(stress) & strain >=0 & stress >=0; strain = strain(validIdx); stress = stress(validIdx);
                if isempty(strain) || length(strain) < 2, continue; end; [strain, uniqueIdx] = unique(strain); stress = stress(uniqueIdx); if length(strain) < 2, continue; end
                allStrains_ss0{s} = strain; allStresses_ss0{s} = stress; minStrain_ss0 = min(minStrain_ss0, min(strain)); maxStrain_ss0 = max(maxStrain_ss0, max(strain));
                maxStrainOverallSS = max(maxStrainOverallSS, max(strain)); maxStressOverallSS = max(maxStressOverallSS, max(stress));

                % --- Calculate Individual Modulus ---
                fitIdx = strain >= strainForModulusFit(1) & strain <= strainForModulusFit(2);
                if sum(fitIdx) >= 2 % Need at least 2 points for polyfit
                    p = polyfit(strain(fitIdx)/100, stress(fitIdx), 1); % Fit strain (unitless) vs stress (MPa)
                    if ~isnan(p(1)) && p(1) > 0 % Check if slope (modulus) is valid
                        % Store for mean/SEM calculation later
                        individualModuli(end+1) = p(1);

                        % *** NEW: Store individual result for separate CSV ***
                        individual_modulus_data_fm{end+1} = struct(...
                            'Material', materialIdentifier, ...
                            'Concentration', concLabel, ...
                            'SampleFileName', current_filename, ...
                            'Individual_YoungModulus_MPa', p(1));
                        % *** END NEW ***
                    else
                        fprintf('  WARN: Invalid modulus (%.2f) calculated for sample %s (%s ss0).\n', p(1), current_filename, concLabel);
                    end
                else
                    fprintf('  WARN: Not enough points (%d) in fit range [%.1f%%, %.1f%%] for sample %s (%s ss0).\n', sum(fitIdx), strainForModulusFit(1), strainForModulusFit(2), current_filename, concLabel);
                end
                 % --- End Calculate Individual Modulus ---

            catch ME_proc, fprintf('  ERROR processing sample %d (%s) of %s ss0: %s. Skipping.\n', s, current_filename, concLabel, ME_proc.message); continue; end
        end
        allStrains_ss0 = allStrains_ss0(~cellfun('isempty',allStrains_ss0)); allStresses_ss0 = allStresses_ss0(~cellfun('isempty',allStresses_ss0)); numValidSamples_ss0 = length(allStrains_ss0);

        % Store calculated individual moduli (valid ones) for this group
        resultsSS0.(concField).YoungModuli = individualModuli; % Used later for summary calc
        resultsSS0.(concField).N_ModulusCalc = length(individualModuli); % N of valid moduli
        resultsSS0.(concField).N_Samples_plotted = numValidSamples_ss0; % N of samples with plottable curves

        if numValidSamples_ss0 > 0 % Interpolation and Averaging for plotting
            % ... (Keep the interpolation and averaging code for SS0 plotting as is) ...
             minStrainValid = min(cellfun(@min, allStrains_ss0)); maxStrainValid = max(cellfun(@max, allStrains_ss0)); % Changed max target
             if ~(isinf(minStrainValid) || isinf(maxStrainValid) || minStrainValid >= maxStrainValid)
                commonStrain_ss0 = linspace(minStrainValid, maxStrainValid, commonStrainPoints_SS)'; interpStresses_ss0 = NaN(commonStrainPoints_SS, numValidSamples_ss0);
                for s = 1:numValidSamples_ss0, interpStresses_ss0(:,s) = interp1(allStrains_ss0{s}, allStresses_ss0{s}, commonStrain_ss0, 'linear', NaN); end
                validRows = all(~isnan(interpStresses_ss0), 2);
                if any(validRows)
                    plotStrain = commonStrain_ss0(validRows); plotMean = mean(interpStresses_ss0(validRows,:), 2); plotSE = zeros(size(plotMean));
                    if numValidSamples_ss0 > 1, plotSE = std(interpStresses_ss0(validRows,:), 0, 2) / sqrt(numValidSamples_ss0); end
                    plotSE(isnan(plotSE)) = 0; % Replace NaN SE with 0
                    lineColor = colors(concLabel); lineStyle = '-'; % Solid line
                    if ~isempty(plotStrain) && ~isempty(plotMean)
                        h_mean = plot(axSS, plotStrain, plotMean, 'Color', lineColor, 'LineWidth', 1.5, 'LineStyle', lineStyle);
                        if numValidSamples_ss0 > 1 && ~all(plotSE == 0)
                           fill(axSS, [plotStrain; flipud(plotStrain)], [(plotMean - plotSE); flipud(plotMean + plotSE)], ...
                                lineColor, 'FaceAlpha', plotFaceAlpha, 'EdgeColor', 'none');
                        end
                        plotHandlesSS = [plotHandlesSS, h_mean]; legendEntriesSS{end+1} = sprintf('%s Room Temp.', concLabel);
                    else, fprintf(' WARN: No plottable mean data for %s ss0.\n', concLabel); end
                end
            end
        end
    end % End if ss0 exists

    % --- Process SS_Elevated ---
    if isfield(rawData, concField) && isfield(rawData.(concField), 'ss_elevated') && ~isempty(rawData.(concField).ss_elevated.samples)
       % ... (Keep the processing and plotting code for SS_Elevated as is) ...
        samples = rawData.(concField).ss_elevated.samples; numSamples = length(samples);
        allStrains_ssE = cell(1, numSamples); allStresses_ssE = cell(1, numSamples); minStrain_ssE = inf; maxStrain_ssE = -inf;
        for s = 1:numSamples % Data extraction and cleaning loop
             try
                data = samples{s}; if ~ismember(actualStaticStrainCol, data.Properties.VariableNames) || ~ismember(actualStaticStressCol, data.Properties.VariableNames), continue; end
                strain = data.(actualStaticStrainCol) * 100; stress = data.(actualStaticStressCol) / 1e6; validIdx = ~isnan(strain) & ~isinf(strain) & ~isnan(stress) & ~isinf(stress) & strain >=0 & stress >=0;
                strain = strain(validIdx); stress = stress(validIdx); if isempty(strain) || length(strain) < 2, continue; end; [strain, uniqueIdx] = unique(strain); stress = stress(uniqueIdx); if length(strain) < 2, continue; end
                allStrains_ssE{s} = strain; allStresses_ssE{s} = stress; minStrain_ssE = min(minStrain_ssE, min(strain)); maxStrain_ssE = max(maxStrain_ssE, max(strain));
                maxStrainOverallSS = max(maxStrainOverallSS, max(strain)); maxStressOverallSS = max(maxStressOverallSS, max(stress));
             catch ME_proc, fprintf('  ERROR processing sample %d of %s ss_elevated: %s. Skipping.\n', s, concLabel, ME_proc.message); continue; end
        end
        allStrains_ssE = allStrains_ssE(~cellfun('isempty',allStrains_ssE)); allStresses_ssE = allStresses_ssE(~cellfun('isempty',allStresses_ssE)); numValidSamples_ssE = length(allStrains_ssE);
        if numValidSamples_ssE > 0 % Interpolation and Averaging
             minStrainValid = min(cellfun(@min, allStrains_ssE)); maxStrainValid = max(cellfun(@max, allStrains_ssE)); % Changed max target
             if ~(isinf(minStrainValid) || isinf(maxStrainValid) || minStrainValid >= maxStrainValid)
                commonStrain_ssE = linspace(minStrainValid, maxStrainValid, commonStrainPoints_SS)'; interpStresses_ssE = NaN(commonStrainPoints_SS, numValidSamples_ssE);
                for s = 1:numValidSamples_ssE, interpStresses_ssE(:,s) = interp1(allStrains_ssE{s}, allStresses_ssE{s}, commonStrain_ssE, 'linear', NaN); end
                validRows = all(~isnan(interpStresses_ssE), 2);
                if any(validRows)
                    plotStrain = commonStrain_ssE(validRows); plotMean = mean(interpStresses_ssE(validRows,:), 2); plotSE = zeros(size(plotMean));
                    if numValidSamples_ssE > 1, plotSE = std(interpStresses_ssE(validRows,:), 0, 2) / sqrt(numValidSamples_ssE); end
                    plotSE(isnan(plotSE)) = 0;
                    lineColor = colors(concLabel); lineStyle = '--'; % Dashed line
                    if ~isempty(plotStrain) && ~isempty(plotMean)
                        h_mean = plot(axSS, plotStrain, plotMean, 'Color', lineColor, 'LineWidth', 1.5, 'LineStyle', lineStyle);
                        if numValidSamples_ssE > 1 && ~all(plotSE == 0)
                           fill(axSS, [plotStrain; flipud(plotStrain)], [(plotMean - plotSE); flipud(plotMean + plotSE)], ...
                                lineColor, 'FaceAlpha', plotFaceAlpha, 'EdgeColor', 'none');
                        end
                        plotHandlesSS = [plotHandlesSS, h_mean]; legendEntriesSS{end+1} = sprintf('%s 80C', concLabel);
                    else, fprintf(' WARN: No plottable mean data for %s ss_elevated.\n', concLabel); end
                end
            end
        end
    end % End if ss_elevated exists
end % End loop through concentrations

% Finalize Combined Stress-Strain Plot
if ~isempty(plotHandlesSS)
    legend(axSS, plotHandlesSS, legendEntriesSS, 'Location', 'eastoutside'); title(axSS, ['Stress-Strain Curve Field''s Metal']);
    set(findall(gcf,'-property','FontName'),'FontName','Times New Roman', 'FontSize', 17.25)
    if maxStrainOverallSS > 0, xlim(axSS, [0, ceil(maxStrainOverallSS/1)*1]); else, xlim(axSS, [0 5]); end
    if maxStressOverallSS > 0, currentYLim = ylim(axSS); ylim(axSS, [0, max(currentYLim(2), maxStressOverallSS * 1.05)]); else, ylim(axSS, [0 0.05]); end
    xlim(axSS, [0, 5]);
    hold(axSS, 'off');
    try saveas(hFigSS, [outputPlotPrefix, '_StressStrain_Combined.png']); fprintf('Saved Combined Stress-Strain plot.\n');
    catch ME_save, fprintf('ERROR saving Combined Stress-Strain plot: %s\n', ME_save.message); end
else
    fprintf('No valid data processed for Combined Stress-Strain plot.\n'); if ishandle(hFigSS), close(hFigSS); end
end


% --- 2. Process and Plot Temperature Sweep (TS) using FILL for SE ---
hFigTS = figure('Name', 'Temperature Sweep', 'Position', [100, 100, 700, 500]);
axTS = axes('Parent', hFigTS); hold(axTS, 'on'); grid(axTS, 'off');
xlabel(axTS, ['Temperature (', char(176), 'C)']); ylabel(axTS, 'Storage Modulus (MPa)');
set(findall(gcf,'-property','FontName'),'FontName','Times New Roman', 'FontSize', 17.25)
legendEntriesTS = {}; plotHandlesTS = []; minTempOverallTS = inf; maxTempOverallTS = -inf;

for i = 1:length(concFieldsSorted)
    concField = concFieldsSorted{i}; concLabel = concLabelsMap(concField);
    if isfield(rawData, concField) && isfield(rawData.(concField), 'ts') && ~isempty(rawData.(concField).ts.samples)
       % ... (Keep the TS processing and plotting code as is) ...
        samples = rawData.(concField).ts.samples; numSamples = length(samples); if numSamples == 0, continue; end
        allTemps = cell(1, numSamples); allModuli = cell(1, numSamples); minTempSample = inf; maxTempSample = -inf;
        for s = 1:numSamples % Data extraction and cleaning loop
             try
                data = samples{s}; if ~ismember(actualSampleTempCol, data.Properties.VariableNames) || ~ismember(actualStorageModCol, data.Properties.VariableNames), continue; end
                temp = data.(actualSampleTempCol); modulus = data.(actualStorageModCol); validIdx = ~isnan(temp) & ~isinf(temp) & ~isnan(modulus) & ~isinf(modulus) & modulus > 0;
                temp = temp(validIdx); modulus = modulus(validIdx); if isempty(temp) || length(temp) < 2, continue; end; [temp, uniqueIdx] = unique(temp); modulus = modulus(uniqueIdx); if length(temp) < 2, continue; end
                allTemps{s} = temp; allModuli{s} = modulus; minTempSample = min(minTempSample, min(temp)); maxTempSample = max(maxTempSample, max(temp));
                minTempOverallTS = min(minTempOverallTS, min(temp)); maxTempOverallTS = max(maxTempOverallTS, max(temp));
             catch ME_proc, fprintf('  ERROR processing sample %d of %s ts: %s. Skipping.\n', s, concLabel, ME_proc.message); continue; end
        end
        allTemps = allTemps(~cellfun('isempty',allTemps)); allModuli = allModuli(~cellfun('isempty',allModuli)); numValidSamples = length(allTemps);

        if numValidSamples > 0 % Interpolation and Averaging
            minTempValid = min(cellfun(@min, allTemps)); maxTempValid = max(cellfun(@max, allTemps)); % Changed max target
            if ~(isinf(minTempValid) || isinf(maxTempValid) || minTempValid >= maxTempValid)
                commonTemp = linspace(minTempValid, maxTempValid, commonTempPoints_TS)'; interpModuli = NaN(commonTempPoints_TS, numValidSamples);
                for s = 1:numValidSamples, interpModuli(:,s) = interp1(allTemps{s}, allModuli{s}, commonTemp, 'linear', NaN); end
                validRows = all(~isnan(interpModuli), 2);
                if any(validRows)
                plotX = commonTemp(validRows); 
                plotMean = mean(interpModuli(validRows,:), 2) / 1e6;  % divide by 1000,000
                plotSE = zeros(size(plotMean));
                if numValidSamples > 1
                plotSE = std(interpModuli(validRows,:), 0, 2) / sqrt(numValidSamples) / 1e6;  % divide by 1000,000
                end
                    plotSE(isnan(plotSE)) = 0;
                    lineColor = colors(concLabel);
                    if ~isempty(plotX) && ~isempty(plotMean)
                        h_mean = plot(axTS, plotX, plotMean, 'Color', lineColor, 'LineWidth', 1.5);
                        if numValidSamples > 1 && ~all(plotSE == 0)
                           fill(axTS, [plotX; flipud(plotX)], [(plotMean - plotSE); flipud(plotMean + plotSE)], ...
                                lineColor, 'FaceAlpha', plotFaceAlpha, 'EdgeColor', 'none');
                        end
                        plotHandlesTS = [plotHandlesTS, h_mean];
                        legendLabel = concLabel; if strcmp(concLabel, '0v'), legendLabel = 'Ecoflex 50'; end
                        legendEntriesTS{end+1} = sprintf('%s', legendLabel);
                    else, fprintf(' WARN: No plottable mean data for %s ts.\n', concLabel); end
                end
            end
        end
    end
end

% Finalize TS Plot
if ~isempty(plotHandlesTS)
    legend(axTS, plotHandlesTS, legendEntriesTS, 'Location', 'eastoutside'); title(axTS, ['Temperature Sweep Field''s Metal']);
    if ~isinf(minTempOverallTS) && ~isinf(maxTempOverallTS) && minTempOverallTS < maxTempOverallTS, xlim(axTS, [floor(minTempOverallTS/5)*5, ceil(maxTempOverallTS/5)*5]); else, xlim(axTS, [30 80]); end
    currentYLim = ylim(axTS); ylim(axTS, [0, currentYLim(2)]); hold(axTS, 'off');
    xlim(axTS, [40, 75]);
    try saveas(hFigTS, [outputPlotPrefix, '_TempSweep_StorageModulus.png']); fprintf('Saved Temperature Sweep plot.\n');
    catch ME_save, fprintf('ERROR saving Temp Sweep plot: %s\n', ME_save.message); end
else
    fprintf('No valid data processed for Temperature Sweep plot.\n'); if ishandle(hFigTS), close(hFigTS); end
end

% --- 3. Calculate and Plot Young's Modulus Bar Chart (Using Summary Data) ---
% This section calculates the summary mean/SEM from resultsSS0 for plotting
% and populates the youngModulusResults table for summary CSV saving.
hFigYM = figure('Name', 'Youngs Modulus', 'Position', [850, 100, 700, 500]);
axYM = axes('Parent', hFigYM); hold(axYM, 'on'); grid(axYM, 'off'); ylabel(axYM, 'Young''s Modulus (MPa)');
barLabels = {}; meanModuli = []; seModuli = []; barColors = []; modulusDataExists = false;
set(findall(gcf,'-property','FontName'),'FontName','Times New Roman', 'FontSize', 17.25)
for i = 1:length(concFieldsSorted)
    concField = concFieldsSorted{i}; concLabel = concLabelsMap(concField);
    if isfield(resultsSS0, concField) && isfield(resultsSS0.(concField), 'N_ModulusCalc') && resultsSS0.(concField).N_ModulusCalc > 0
        moduli = resultsSS0.(concField).YoungModuli; % Get individual moduli stored earlier
        n = resultsSS0.(concField).N_ModulusCalc;
        meanYM = mean(moduli);
        stdErrYM = 0; if n > 1, stdErrYM = std(moduli) / sqrt(n); end
        meanModuli(end+1) = meanYM; seModuli(end+1) = stdErrYM;
        barLabel = concLabel; % No need to check for '0v'/'Ecoflex 50' here for FM data
        barLabels{end+1} = barLabel; barColors = [barColors; colors(concLabel)];
        % Prepare row for the summary table
        newRow = table(string(materialIdentifier), string(barLabel), meanYM, stdErrYM, uint8(n), 'VariableNames', {'Material', 'Concentration', 'YoungModulus_MPa', 'YoungModulus_SE', 'N_Samples'});
        youngModulusResults = [youngModulusResults; newRow];
        fprintf('Young''s Modulus Summary for %s: %.4f +/- %.4f MPa (N=%d)\n', barLabel, meanYM, stdErrYM, n);
        modulusDataExists = true;
    end
end
if modulusDataExists
    xPos = 1:length(meanModuli); b = bar(axYM, xPos, meanModuli, 'FaceColor', 'flat'); b.CData = barColors; errorbar(axYM, xPos, meanModuli, seModuli, 'k.', 'LineWidth', 1, 'CapSize', 10, 'LineStyle', 'none');
    set(axYM, 'xtick', xPos, 'xticklabel', barLabels, 'XTickLabelRotation', 45); ylabel(axYM, 'Young''s Modulus (MPa)'); title(axYM, [' Room Temperature Young''s Modulus']);
    currentYLim = ylim(axYM); ylim(axYM, [0, currentYLim(2)]); hold(axYM, 'off');
    try saveas(hFigYM, [outputPlotPrefix, '_YoungsModulus_BarChart.png']); fprintf('Saved Young''s Modulus bar chart.\n');
    catch ME_save, fprintf('ERROR saving Youngs Modulus Bar Chart: %s\n', ME_save.message); end
else, fprintf('No Young''s Modulus data to plot.\n'); if ishandle(hFigYM), close(hFigYM); end; end

% --- 4. Save SUMMARY Young's Modulus Data to CSV ---
% This uses the 'youngModulusResults' table populated above.
% The appending logic remains the same.
[outputDir, ~, ~] = fileparts(outputCsvPath); if ~isempty(outputDir) && ~isfolder(outputDir), fprintf('Creating output directory: %s\n', outputDir); mkdir(outputDir); end
if modulusDataExists && ~isempty(youngModulusResults)
    try
        fileExists = exist(outputCsvPath, 'file') == 2;
        if fileExists
            fprintf('Attempting to append SUMMARY Young''s Modulus results to: %s\n', outputCsvPath);
            try
                optsRead = detectImportOptions(outputCsvPath); existingData = readtable(outputCsvPath, optsRead); existingHeaders = lower(strjoin(sort(existingData.Properties.VariableNames))); newHeaders = lower(strjoin(sort(youngModulusResults.Properties.VariableNames)));
                if strcmp(existingHeaders, newHeaders)
                     existingKeys = lower(strcat(string(existingData.Material), '_', string(existingData.Concentration))); newKeys = lower(strcat(string(youngModulusResults.Material), '_', string(youngModulusResults.Concentration))); rowsToAppend = ~ismember(newKeys, existingKeys);
                     if any(rowsToAppend), dataToAppend = youngModulusResults(rowsToAppend,:); writetable(dataToAppend, outputCsvPath, 'WriteMode', 'Append', 'WriteVariableNames', false); fprintf('Appended %d new SUMMARY rows to %s\n', sum(rowsToAppend), outputCsvPath);
                     else, fprintf('No new material/concentration combinations found to append to SUMMARY file.\n'); end
                else, fprintf('ERROR: Column names mismatch in SUMMARY file. Saving new summary data separately.\n'); newCsvPath = [outputCsvPath(1:end-4), '_newData_', datestr(now,'yyyymmddHHMMSS'), '.csv']; writetable(youngModulusResults, newCsvPath); fprintf('New summary data saved to: %s\n', newCsvPath); end
            catch ME_read_append, fprintf('ERROR Reading/Appending SUMMARY CSV %s: %s\nSaving new summary data separately.\n', outputCsvPath, ME_read_append.message); newCsvPath = [outputCsvPath(1:end-4), '_newData_', datestr(now,'yyyymmddHHMMSS'), '.csv']; writetable(youngModulusResults, newCsvPath); fprintf('New summary data saved to: %s\n', newCsvPath); end
        else, fprintf('Creating new SUMMARY Young''s Modulus results file: %s\n', outputCsvPath); writetable(youngModulusResults, outputCsvPath); end
    catch ME_csv, fprintf('ERROR writing SUMMARY Young''s Modulus data to CSV: %s\n', ME_csv.message); end
else, fprintf('No SUMMARY Young''s Modulus data calculated to save.\n'); end

% --- 5. *** NEW: Save INDIVIDUAL Sample Modulus Data to CSV *** ---
fprintf('\nSaving INDIVIDUAL sample Young''s Modulus data...\n');
% Construct filename for individual results based on summary filename
[summaryDir, summaryBase, ~] = fileparts(outputCsvPath);
individualOutputCsvPath = fullfile(summaryDir, [summaryBase, '_individual_modulus_data.csv']);

if ~isempty(individual_modulus_data_fm)
    try
        individual_table_fm = struct2table([individual_modulus_data_fm{:}], 'AsArray', true);

        % Optional: Sort individual results if desired
        individual_table_fm = sortrows(individual_table_fm, {'Material', 'Concentration', 'SampleFileName'});

        writetable(individual_table_fm, individualOutputCsvPath);
        fprintf('Saved individual sample modulus data (%d rows) to: %s\n', height(individual_table_fm), individualOutputCsvPath);
        disp('Individual Modulus Data Snippet (FM):');
        disp(head(individual_table_fm)); % Display first few rows
    catch ME_save_individual
        warning('Error saving individual sample modulus data table for FM: %s', ME_save_individual.message);
    end
else
    fprintf('No valid individual sample modulus data was generated for FM to save.\n');
end
% --- END Section 5 ---

fprintf('Processing complete.\n');

end % End of function processFMData