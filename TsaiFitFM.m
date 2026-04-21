clear; clc; close all;

% --- Aspect Ratio (AR) Setup ---
l = 2.5; % mm
d = 0.2;    % mm
FM_AR = l / d;
E50 = 82000; % Pa

% --- Guth Model Calculations ---
Vf_list = [0.1, 0.2, 0.3, 0.4, 0.5];
E_guth = E50 * (1 + 1.0121 * FM_AR * Vf_list + 0.0333 * FM_AR^2 * Vf_list.^2);

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

% --- Extract FM Data ---
fmRows = allData.Material == 'FM';
fmData = allData(fmRows, :);
fmData = sortrows(fmData, 'ConcentrationNumeric');
fm_exp = fmData.YoungModulus_MPa * 1e6;  % Convert MPa to Pa
Vf = fmData.ConcentrationNumeric / 100;

% --- Tsai Model with Optimized Weights ---
EFM = 9.8e9; % Pa
sigma = (2 * l) / d;

tsai_model = @(a, Vf_vals) arrayfun(@(Vf) ...
    E50 * ( ...
        a * ((1 + (sigma * ((EFM/E50 - 1)/(EFM/E50 + sigma)) * Vf)) / ...
            (1 - ((EFM/E50 - 1)/(EFM/E50 + sigma)) * Vf)) + ...
        (1 - a) * ((1 + (2 * ((EFM/E50 - 1)/(EFM/E50 + 2)) * Vf)) / ...
            (1 - ((EFM/E50 - 1)/(EFM/E50 + 2)) * Vf)) ...
    ), Vf_vals);

% --- Objective Function for Optimization ---
validIdx = ~isnan(fm_exp) & ~isnan(Vf);
Vf_valid = Vf(validIdx);
fm_exp_valid = fm_exp(validIdx);

objective_fn = @(a) mean(abs((tsai_model(a, Vf_valid(:)) - fm_exp_valid(:)) ./ fm_exp_valid(:))) * 100;

% --- Find Optimal a (0 < a < 1), b = 1 - a ---
lb = 0.01;
ub = 0.99;
options = optimset('Display', 'iter', 'TolX', 1e-4);
optimal_a = fminbnd(objective_fn, lb, ub, options);
optimal_b = 1 - optimal_a;

disp(['Optimal a: ', num2str(optimal_a)]);
disp(['Optimal b: ', num2str(optimal_b)]);

% --- Compute Tsai Model with Optimal Parameters ---
E_tsai = tsai_model(optimal_a, Vf_list);

% --- Data Matrix Setup ---
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

colors = [0 0 1; 1 0 0; 0 0.7 0; 0 0 0; 0.5 0.5 0.5];
for i = 1:length(b)
    b(i).FaceColor = colors(i, :);
end

x = nan(size(YM_matrix(2:end, :)));
for j = 1:length(b)
    if isprop(b(j), 'XEndPoints')
        x(:, j) = b(j).XEndPoints';
    end
end
expCols = 1:3;
errorbar(x(:, expCols), YM_matrix(2:end, expCols), SE_matrix(2:end, expCols), ...
    'k.', 'LineStyle', 'none', 'LineWidth', 1);

yline(0.087, '-', '\bfEcoFlex 50', ...
    'LabelHorizontalAlignment', 'left', ...
    'LabelVerticalAlignment', 'top', ...
    'Color', [0.2 0.2 0.2], ...
    'FontSize', 10, ...
    'LineWidth', 2);

xlabel('Filler Concentration (%)');
ylabel("Young's Modulus (MPa)");
legend(materialsOrder, 'Location', 'northwest');
title("Elastic Modulus");
xticks(concentrations(2:end));
xticklabels({'10', '20', '30', '40', '50'});
grid off;

% --- Model Error Plot ---
modelNames = {'Guth', 'Tsai'};
modelIndices = [find(strcmp(materialsOrder, 'Guth')), find(strcmp(materialsOrder, 'Tsai'))];
materialsToCompare = {'Cerr 117', 'Cerr 158', 'FM'};
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

meanErrors = squeeze(nanmean(errors(2:end, :, :), 1));

figure('Position', [25 25 800 500]);
hold on;
b = bar(meanErrors, 'grouped', 'BarWidth', 0.5);
b(1).FaceColor = 'black';
b(2).FaceColor = 'red';

xticks(1:length(materialsToCompare));
xticklabels(materialsToCompare);
ylabel('Mean Absolute Percentage Error (%)');
legend(modelNames, 'Location', 'northwest');
title('Model Error vs Experimental Materials');
grid off;
set(gca, 'FontSize', 12);
