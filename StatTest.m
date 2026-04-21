clear; clc; close all;

% --- Load Experimental Data ---
fmFile = 'output_matlab/fm_dma.csv';
ss0File = 'output_matlab/ss0_young_modulus_results.csv';

try
    dataFM = readtable(fmFile);
    dataSS0 = readtable(ss0File);
    allData = [dataFM; dataSS0];
catch ME
    error('Error reading data files: %s', ME.message);
end

% --- Standardize Material Names ---
allData.Material = categorical(allData.Material);
materialNames = categories(allData.Material);

for i = 1:length(materialNames)
    if strcmpi(materialNames{i}, 'fm')
        allData.Material(allData.Material == materialNames{i}) = 'FM';
    elseif strcmpi(materialNames{i}, 'cerr_117')
        allData.Material(allData.Material == materialNames{i}) = 'Cerr 117';
    elseif strcmpi(materialNames{i}, 'cerr_158')
        allData.Material(allData.Material == materialNames{i}) = 'Cerr 158';
    end
end
allData.Material = removecats(allData.Material);

% Remove Ecoflex or irrelevant materials
ecoRows = contains(string(allData.Material), 'ecoflex', 'IgnoreCase', true);
allData(ecoRows, :) = [];

% --- Parse Concentration Field into Numeric ---
concentrations = [0, 10, 20, 30, 40, 50];
numericConcentration = zeros(height(allData), 1);
for i = 1:height(allData)
    strVal = lower(strtrim(allData.Concentration{i}));
    if contains(strVal, 'v')
        numericConcentration(i) = sscanf(strVal, '%fv');
    else
        num = str2double(strVal);
        numericConcentration(i) = isnan(num) * NaN + ~isnan(num) * num;
    end
end
allData.ConcentrationNumeric = numericConcentration;

% --- Kruskal-Wallis Test for Each Concentration Level ---
fprintf('\n--- Kruskal-Wallis Test by Concentration ---\n');

materialsToTest = {'Cerr 117', 'Cerr 158', 'FM'};
concentrationLevels = unique(allData.ConcentrationNumeric(~isnan(allData.ConcentrationNumeric)));

for c = 1:length(concentrationLevels)
    conc = concentrationLevels(c);

    % Subset data
    subset = allData(allData.ConcentrationNumeric == conc & ...
                     ismember(allData.Material, materialsToTest), :);
    subset = subset(~isnan(subset.YoungModulus_MPa), :);

    % Skip if too few groups
    if numel(unique(subset.Material)) < 2
        fprintf('Concentration %d%%: Not enough data for Kruskal-Wallis.\n', conc);
        continue;
    end

    % Perform test
    youngsModulus = subset.YoungModulus_MPa;
    groupLabels = subset.Material;

    [p_kw, tbl_kw, stats_kw] = kruskalwallis(youngsModulus, groupLabels, 'off');
    
    fprintf('\nConcentration %d%%:\n', conc);
    fprintf('  p-value = %.4f\n', p_kw);

    if p_kw < 0.05
        fprintf('  ➤ Significant difference found.\n');
        figure('Name', sprintf('Post-hoc Comparison at %d%%', conc));
        multcompare(stats_kw, 'CType', 'dunn-sidak');
        title(sprintf('Post-hoc Comparison (Dunn-Sidak) at %d%% Filler', conc));
    else
        fprintf('  ➤ No significant difference.\n');
    end
end

% --- Optional: Global Test (across all concentrations) ---
fprintf('\n--- Kruskal-Wallis Test on Full Experimental Dataset ---\n');
kruskalData = allData(ismember(allData.Material, materialsToTest) & ...
                      ~isnan(allData.YoungModulus_MPa), :);

youngsModulus = kruskalData.YoungModulus_MPa;
groupLabels = kruskalData.Material;

[p_kw, tbl_kw, stats_kw] = kruskalwallis(youngsModulus, groupLabels, 'off');

fprintf('Global p-value = %.4f\n', p_kw);
if p_kw < 0.05
    fprintf('Result: Significant difference across all materials.\n');
    figure('Name', 'Global Post-hoc Comparison');
    multcompare(stats_kw, 'CType', 'dunn-sidak');
    title('Global Post-hoc Comparison (Dunn-Sidak)');
else
    fprintf('Result: No significant difference across materials.\n');
end
