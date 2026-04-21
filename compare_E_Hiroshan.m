clear; clc; close all;

% --- Aspect Ratio (AR) Setup ---
l = 2.5;
d = 0.2;
FM_AR = l / d;
E50 = 82000; % Pa

% --- Guth Model Calculations ---
Vf_list = [0.1, 0.2, 0.3, 0.4, 0.5];
%E_guth = E50 * (1 + 0.67 * FM_AR * Vf_list + 1.62 * FM_AR^2 * Vf_list.^2);
E_guth = E50 * (1 + 1.0367 * FM_AR * Vf_list + 0.0209 * FM_AR^2 * Vf_list.^2);



% --- Tsai Model Calculations ---
EFM = 9.25e9; % Pa
%sigma = (2 * l) / d;

%Optimized sigmaVals
sigma = 17.5;
nL = ((EFM / E50) - 1) / ((EFM / E50) + sigma);
nT = ((EFM / E50) - 1) / ((EFM / E50) + 2);

E_tsai = zeros(size(Vf_list));
for i = 1:length(Vf_list)
    Vf = Vf_list(i);
    E_tsai_L = (0.98994) * ((1 + (sigma * nL * Vf)) / (1 - nL * Vf));
    E_tsai_R = (0.010058) * ((1 + (2 * nT * Vf)) / (1 - nT * Vf));
    E_tsai(i) = E50 * (E_tsai_L + E_tsai_R);
end

% --- Load Data ---
fmFile = 'output_matlab/fm_dma.csv';
ss0File = 'output_matlab/ss0_young_modulus_results.csv';

try
    dataFM = readtable(fmFile);
    dataSS0 = readtable(ss0File);
    allData = [dataFM; dataSS0];
catch ME
    error('Error reading files: %s', ME.message);
end

% --- Clean and Format Data ---
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

% Remove all Ecoflex rows
ecoRows = contains(string(allData.Material), 'ecoflex', 'IgnoreCase', true);
allData(ecoRows, :) = [];

% Parse Concentration values
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

% --- Grouped Bar Data ---
materialsOrder = {'Cerr 117', 'Cerr 158', 'FM'};
numConc = length(concentrations);
numMat = length(materialsOrder);

YM_matrix = NaN(numConc, numMat);
SE_matrix = NaN(numConc, numMat);

for i = 1:numConc
    conc = concentrations(i);
    for j = 1:numMat
        mat = materialsOrder{j};
        row = allData(allData.ConcentrationNumeric == conc & allData.Material == mat, :);
        if ~isempty(row)
            YM_matrix(i, j) = row.YoungModulus_MPa(1);
            SE_matrix(i, j) = row.YoungModulus_SE(1);
        end
    end
end

% --- Add Guth and Tsai Data ---
guth_ym = [0, E_guth] / 1e6;
tsai_ym = [0, E_tsai] / 1e6;

YM_matrix(:, end+1) = NaN;
SE_matrix(:, end+1) = NaN;
YM_matrix(:, end+1) = NaN;
SE_matrix(:, end+1) = NaN;
materialsOrder{end+1} = 'Guth';
materialsOrder{end+1} = 'Tsai';

for i = 2:numConc
    YM_matrix(i, end-1) = guth_ym(i);
    YM_matrix(i, end) = tsai_ym(i);
end

% --- Plotting ---
figure('Position', [100 100 900 600]);
hold on;
b = bar(concentrations(2:end), YM_matrix(2:end, :), 'grouped');

% Assign Colors
colors = [0 0 1; 1 0 0; 0 0.7 0; 0 0 0; 0.5 0.5 0.5];
for i = 1:length(b)
    b(i).FaceColor = colors(i, :);
end

% Error Bars (only for experimental data, not Guth or Tsai)
x = nan(size(YM_matrix(2:end, :)));
for j = 1:length(b)
    if isprop(b(j), 'XEndPoints')
        x(:, j) = b(j).XEndPoints';
    end
end
expCols = 1:3; % Only Cerr 117, Cerr 158, FM
errorbar(x(:, expCols), YM_matrix(2:end, expCols), SE_matrix(2:end, expCols), ...
    'k.', 'LineStyle', 'none', 'LineWidth', 1);

% Horizontal line at 87 kPa (0.087 MPa)
yline(0.087, '-', '\bfEcoFlex 50', ...
    'LabelHorizontalAlignment', 'left', ...
    'LabelVerticalAlignment', 'top', ...
    'Color', [0.2 0.2 0.2], ...
    'FontSize', 10, ...
    'LineWidth', 2);

% Labels and Title
xlabel('Filler Concentration (%)');
ylabel("Young's Modulus (MPa)");
legend(materialsOrder, 'Location', 'northwest');
title("Elastic Modulus");

% Clean X-axis ticks
xticks(concentrations(2:end)); % [10 20 30 40 50]
xticklabels({'10', '20', '30', '40', '50'});

% Remove grid
grid off;


% --- Error Calculation and Plotting ---
materialsToCompare = {'Cerr 117', 'Cerr 158', 'FM'};
modelNames = {'Guth', 'Tsai'};
modelIndices = [find(strcmp(materialsOrder, 'Guth')), find(strcmp(materialsOrder, 'Tsai'))];

errors = NaN(numConc, length(materialsToCompare), length(modelNames));

for i = 2:numConc
    for j = 1:length(materialsToCompare)
        expVal = YM_matrix(i, strcmp(materialsOrder, materialsToCompare{j}));
        for k = 1:length(modelNames)
            modelVal = YM_matrix(i, modelIndices(k));
            if ~isnan(expVal) && ~isnan(modelVal)
                errors(i, j, k) = abs((modelVal - expVal) / expVal) * 100;
            end
        end
    end
end

% Average error across concentrations (ignoring NaNs)
meanErrors = squeeze(nanmean(errors(2:end, :, :), 1)); % size: [3 materials x 2 models]

% --- Plotting Error ---
figure('Position', [25 25 800 500]);
hold on;

% Plotting the bar chart with reduced gap between bars
b = bar(meanErrors, 'grouped', 'BarWidth', 0.5);  % Set BarWidth to make bars thinner

% Adjust the positions of the grouped bars to reduce the gap
b(1).FaceColor = 'black';  % Guth error in black
b(2).FaceColor = 'red';    % Tsai error in red

% Set x-axis labels
xticks(1:length(materialsToCompare));  % Adjust x-axis ticks for better alignment
xticklabels({'Cerr 117', 'Cerr 158', 'FM'});  % Material names for the x-axis

% Reduce the gap between groups (Cerr 117, Cerr 158, FM)
% This is achieved by setting the 'BarWidth' property and adjusting x-tick positions
xtickPos = 1:length(materialsToCompare);  % Position of each material
xtickSpacing = 0.001;  % Adjust spacing between bars for each material
set(gca, 'XTick', xtickPos, 'XTickLabel', {'Cerr 117', 'Cerr 158', 'FM'}, 'XTickLabelRotation', 0);

% Y-axis label and title
ylabel('Mean Absolute Percentage Error (%)');
legend(modelNames, 'Location', 'northwest');
title('Model Error vs Experimental Materials');

% Grid and font size adjustments for clean visualization
grid off;  % Remove grid lines
set(gca, 'FontSize', 12);  % Increase font size

