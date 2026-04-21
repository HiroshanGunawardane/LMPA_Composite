clear; clc; close all;

% --- Aspect Ratio Setup ---
l = 2.5; % mm
d = 0.2;    % mm
AR = l / d;
E50 = 82000; % Pa

% --- Guth Model ---
Vf_list = [0.1, 0.2, 0.3, 0.4, 0.5];
E_guth = E50 * (1 + 1.0121 * AR * Vf_list + 0.0333 * AR^2 * Vf_list.^2);

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

% --- Clean Data ---
allData.Material = categorical(allData.Material);
materialNames = categories(allData.Material);
for i = 1:length(materialNames)
    switch lower(materialNames{i})
        case 'fm'
            allData.Material(allData.Material == materialNames{i}) = 'FM';
        case 'cerr_117'
            allData.Material(allData.Material == materialNames{i}) = 'Cerr 117';
        case 'cerr_158'
            allData.Material(allData.Material == materialNames{i}) = 'Cerr 158';
    end
end
allData.Material = removecats(allData.Material);

% Remove Ecoflex
allData(contains(string(allData.Material), 'ecoflex', 'IgnoreCase', true), :) = [];

% --- Parse Concentrations ---
concentrations = [0, 10, 20, 30, 40, 50];
numericConcentration = zeros(height(allData), 1);
for i = 1:height(allData)
    val = strtrim(lower(allData.Concentration{i}));
    if contains(val, 'v')
        numericConcentration(i) = sscanf(val, '%fv');
    else
        numericConcentration(i) = str2double(val);
    end
end
allData.ConcentrationNumeric = numericConcentration;

% --- Optimize Tsai Model for Cerr 117 ---
cerr117Data = sortrows(allData(allData.Material == 'Cerr 117', :), 'ConcentrationNumeric');
cerr_exp = cerr117Data.YoungModulus_MPa * 1e6;
Vf_cerr = cerr117Data.ConcentrationNumeric / 100;

EFM = 3e9; % Pa
sigma = 2 * l / d;
tsai_model = @(a, Vf_vals) arrayfun(@(Vf) ...
    E50 * ( ...
        a * ((1 + (sigma * ((EFM/E50 - 1)/(EFM/E50 + sigma)) * Vf)) / ...
            (1 - ((EFM/E50 - 1)/(EFM/E50 + sigma)) * Vf)) + ...
        (1 - a) * ((1 + (2 * ((EFM/E50 - 1)/(EFM/E50 + 2)) * Vf)) / ...
            (1 - ((EFM/E50 - 1)/(EFM/E50 + 2)) * Vf)) ...
    ), Vf_vals);

validIdx = ~isnan(cerr_exp) & ~isnan(Vf_cerr);
Vf_valid = Vf_cerr(validIdx);
cerr_exp_valid = cerr_exp(validIdx);

objective_fn = @(a) mean(abs((tsai_model(a, Vf_valid) - cerr_exp_valid) ./ cerr_exp_valid)) * 100;
optimal_a = fminbnd(objective_fn, 0.01, 0.99, optimset('Display','iter'));
optimal_b = 1 - optimal_a;
E_tsai = tsai_model(optimal_a, Vf_list);

% --- Build Data Matrix ---
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

% Add Guth and Tsai to Matrix
guth_ym = [0, E_guth] / 1e6;
tsai_ym = [0, E_tsai] / 1e6;
YM_matrix(:, end+1:end+2) = NaN;
SE_matrix(:, end+1:end+2) = NaN;
materialsOrder{end+1} = 'Guth';
materialsOrder{end+1} = 'Tsai';

for i = 2:numConc
    YM_matrix(i, end-1) = guth_ym(i);
    YM_matrix(i, end) = tsai_ym(i);
end

% --- Plot Elastic Modulus ---
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

% --- Print Optimized Tsai Parameters ---
fprintf('\nOptimized Tsai model parameters (for Cerr 117):\n');
fprintf('  a = %.4f\n', optimal_a);
fprintf('  b = %.4f\n', optimal_b);
