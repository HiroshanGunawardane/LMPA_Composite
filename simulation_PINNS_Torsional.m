%% Physics-Informed Neural Network (PINN) for Bending Actuator
clear; clc;

%% --- Generate Synthetic Bending Data ---
n = 100;
P = linspace(0, 400, n)';              % Pressure in kPa
theta_max_deg = 100; L = 1.0;          % Arc length (m)

% Generate nonlinear angle with noise
theta_rad = deg2rad(theta_max_deg) * (1 - exp(-0.02 * P));
noise = deg2rad(2) * randn(n,1);
theta_rad_noisy = theta_rad + noise;
theta_deg_noisy = rad2deg(theta_rad_noisy);

% Compute tip displacement (x, y)
x = zeros(n,1); y = zeros(n,1);
for i = 1:n
    th = theta_rad_noisy(i);
    if abs(th) < 1e-6
        x(i) = 0; y(i) = L;
    else
        R = L / th;
        x(i) = R * sin(th);
        y(i) = R * (1 - cos(th));
    end
end

% Save data
data = [P, theta_deg_noisy, x, y];
writematrix(data, 'bending_actuator_synthetic_with_tip.csv');

% Plot synthetic data
figure;
subplot(1,2,1);
plot(P, theta_deg_noisy, 'bo-', 'DisplayName', 'Noisy Bending');
hold on;
plot(P, rad2deg(theta_rad), 'r--', 'DisplayName', 'Ideal');
xlabel('Pressure (kPa)');
ylabel('Bending Angle (deg)');
title('Bending Angle vs Pressure');
legend; grid on;

subplot(1,2,2);
plot(x, y, 'g-', 'LineWidth', 2);
xlabel('X (m)'); ylabel('Y (m)');
title('Tip Displacement');
axis equal; grid on;

%% --- Define Physics-Informed Neural Network (PINN) ---
% Normalize pressure input between 0 and 1
P_norm = (P - min(P)) / (max(P) - min(P));

% Convert to dlarray for training
XTrain = dlarray(P_norm','CB');
YTrain = dlarray(theta_rad_noisy','CB');

% Initialize network
layers = [
    featureInputLayer(1)
    fullyConnectedLayer(20)
    tanhLayer
    fullyConnectedLayer(20)
    tanhLayer
    fullyConnectedLayer(1)
];

net = dlnetwork(layers);

%% --- Physics Constants ---
A = 1e-4; r = 0.01;  % Cross-sectional area and moment arm
dt = 5 / n;          % Approximate time step

% Estimate stiffness and damping from data (used as physical constants)
dtheta_data = gradient(theta_rad_noisy, dt);
tau_data = A * r * P * 1000;  % Torque from pressure (N·m)
X_phys = [theta_rad_noisy, dtheta_data];
params_phys = X_phys \ tau_data;
k_theta = params_phys(1);
c_theta = params_phys(2);

fprintf('Physics estimated parameters:\n');
fprintf('k_theta = %.4f Nm/rad\n', k_theta);
fprintf('c_theta = %.4f Nm*s/rad\n', c_theta);

%% --- Training Setup ---
numEpochs = 1000;
learnRate = 1e-2;
trailingAvg = [];
trailingAvgSq = [];

lossHistory = zeros(numEpochs,1);

%% --- Training Loop ---
for epoch = 1:numEpochs
    [loss, gradients] = dlfeval(@modelLoss, net, XTrain, YTrain, ...
                                P_norm, A, r, k_theta, c_theta, dt);
    [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, ...
        trailingAvg, trailingAvgSq, epoch, learnRate);

    lossHistory(epoch) = extractdata(loss);
    if mod(epoch, 100) == 0
        fprintf('Epoch %d: Loss = %.4e\n', epoch, lossHistory(epoch));
    end
end

%% --- Plot Training Loss ---
figure;
plot(lossHistory);
xlabel('Epoch'); ylabel('Loss');
title('PINN Training Loss');

%% --- Plot Model Prediction ---
YPred = predict(net, XTrain);
theta_pred = extractdata(YPred)';

figure;
plot(P, rad2deg(theta_rad_noisy), 'bo-', 'DisplayName', 'Measured');
hold on;
plot(P, rad2deg(theta_pred), 'r--', 'LineWidth', 1.5, 'DisplayName', 'PINN Prediction');
xlabel('Pressure (kPa)');
ylabel('Bending Angle (deg)');
title('PINN Prediction vs Ground Truth');
legend; grid on;

%% --- Model Loss Function (Physics + Data) ---
function [loss, gradients] = modelLoss(net, X, YTrue, Pnorm, A, r, k_theta, c_theta, dt)
    % Forward pass
    theta = forward(net, X);          % Predicted angle (dlarray)

    % Compute derivative dtheta/dPnorm via automatic differentiation
    dtheta_dP = dlgradient(sum(theta), X);

    % Approximate dtheta/dt = dtheta/dP * dP/dt
    pressure_range = 1; % normalized pressure from 0 to 1
    total_time = dt * size(X, 2); % total time
    dtheta_dt = dtheta_dP * (pressure_range / total_time);

    % Calculate predicted torque from physics
    tau_pred = k_theta * theta + c_theta * dtheta_dt;

    % Convert normalized pressure back to actual pressure (kPa)
    P = Pnorm * 400;

    % Torque from pressure input (Pa)
    tau_act = A * r * P * 1000; % N·m

    % Calculate losses (mean squared error)
    mse_data = mse(theta, YTrue);
    mse_phys = mse(tau_pred, tau_act');

    % Total loss
    loss = mse_data + mse_phys;

    % Compute gradients for training
    gradients = dlgradient(loss, net.Learnables);
end
