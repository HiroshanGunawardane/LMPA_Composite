clear; clc; close all;

% --- Load Experimental Data ---
ss0File = 'output_matlab/ss0_young_modulus_results.csv';
try
    data = readtable(ss0File);
catch ME
    error('Failed to read Cerr 117 file: %s', ME.message);
end

% --- Filter for Cerr 117 ---
data.Material = categorical(data.Material);
data = data(data.Material == 'cerr_117' | data.Material == 'Cerr 117', :);

% Parse concentration values safely
concentrationStr = data.Concentration;
numericConc = zeros(height(data), 1);

for i = 1:height(data)
    strVal = lower(strtrim(concentrationStr{i}));
    val = sscanf(strVal, '%f');
    if ~isempty(val)
        numericConc(i) = val(1);  % Use first value if multiple exist
    else
        warning('Could not parse concentration value: "%s"', strVal);
        numericConc(i) = NaN;
    end
end

% Remove invalid rows
validRows = ~isnan(numericConc);
data = data(validRows, :);
numericConc = numericConc(validRows);

% Convert to volume fraction and modulus in Pa
Vf = numericConc / 100;
E_exp = data.YoungModulus_MPa * 1e6;  % MPa to Pa

% --- Guth Model Setup ---
l = 2.5;   % Fiber length (m)
d = 0.2;      % Fiber diameter (m)
AR = l / d;   % Aspect ratio
E0 = 82000;   % Matrix modulus (Pa)

% --- Guth Model Function ---
guth_model = @(params, Vf) E0 * (1 + params(1) * AR * Vf + params(2) * AR^2 * Vf.^2);
error_func = @(params) guth_model(params, Vf) - E_exp;

% --- Fit Parameters ---
initialGuess = [2.0, 0.5];
opts = optimoptions('lsqnonlin', 'Display', 'iter');
[paramFit, resnorm] = lsqnonlin(error_func, initialGuess, [], [], opts);

% --- Output Results ---
A_fit = paramFit(1);
B_fit = paramFit(2);
fprintf('Optimized Guth parameters for Cerr 117:\n');
fprintf('  A = %.4f\n', A_fit);
fprintf('  B = %.4f\n', B_fit);

% --- Predict and Plot ---
E_guth_fit = guth_model(paramFit, Vf) / 1e6;  % Pa to MPa
E_exp_mpa = E_exp / 1e6;

figure('Position', [100, 100, 800, 500]);
hold on;
plot(numericConc, E_exp_mpa, 'bo-', 'LineWidth', 2, 'DisplayName', 'Experimental Cerr 117');
plot(numericConc, E_guth_fit, 'r*-', 'LineWidth', 2, 'DisplayName', 'Fitted Guth Model');
xlabel('Filler Concentration (%)');
ylabel("Young's Modulus (MPa)");
title('Fitting Guth Model to Cerr 117 Data');
legend('Location', 'northwest');
grid on;
