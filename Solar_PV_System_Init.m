%=================================================
% نموذج نظام الطاقة الشمسية المتكامل
% Solar PV System Complete Model - Initialization
%=================================================
% استخدام: انسخ هذا الملف وشغّله في MATLAB
% Usage: Copy this file and run it in MATLAB

clear all; close all; clc;

%% ===== معاملات النظام =====

% معاملات PV Array
PV.Voc = 42;               % Open circuit voltage (V)
PV.Isc = 8;                % Short circuit current (A)
PV.Vmpp = 35;              % Voltage at MPP (V)
PV.Impp = 7.5;             % Current at MPP (A)
PV.Pmpp = 262.5;           % Power at MPP (W)
PV.G_ref = 1000;           % Reference irradiance (W/m²)
PV.T_ref = 25;             % Reference temperature (°C)
PV.ki = 0.0032;            % Temperature coefficient for current (%/°C)
PV.kv = -0.123;            % Temperature coefficient for voltage (V/°C)
PV.Np = 1;                 % Number of parallel strings
PV.Ns = 1;                 % Number of series modules

% معاملات MPPT - Perturb & Observe Algorithm
MPPT.Ts = 0.001;           % Sampling time (1ms)
MPPT.stepV = 0.5;          % Voltage step size (V)
MPPT.Vref_init = 35;       % Initial reference voltage (V)
MPPT.Vref_max = 48;        % Maximum reference voltage (V)
MPPT.Vref_min = 20;        % Minimum reference voltage (V)
MPPT.P_prev = 0;           % Previous power (W)
MPPT.V_prev = 35;          % Previous voltage (V)

% معاملات Boost DC-DC Converter
Boost.fs = 10000;          % Switching frequency (10 kHz)
Boost.Ts = 1/Boost.fs;     % Sampling time
Boost.L = 0.003;           % Inductance (3 mH)
Boost.C = 1000e-6;         % Capacitance (1000 µF)
Boost.ESR = 0.1;           % Series resistance (0.1 Ω)
Boost.Vin_nom = 35;        % Input voltage (35V)
Boost.Vout_nom = 54.6;     % Output voltage (54.6V)
Boost.Vout_ref = 54.6;     % Output voltage reference (V)
Boost.D_init = 1 - (Boost.Vin_nom / Boost.Vout_nom);  % Initial duty cycle

% معاملات PI Controller للـ Boost
Boost.Kp = 1.5;            % Proportional gain
Boost.Ki = 0.5;            % Integral gain
Boost.Kd = 0.0;            % Derivative gain

% معاملات البطارية (Lithium-ion 48V)
Batt.Vnom = 48;            % Nominal voltage (48V)
Batt.Capacity = 100;       % Capacity (100 Ah)
Batt.Energy = Batt.Vnom * Batt.Capacity;  % Energy (4.8 kWh)
Batt.R_internal = 0.01;    % Internal resistance (10 mΩ)
Batt.V_charge = 54.6;      % Charging voltage (100% SOC)
Batt.V_discharge = 40;     % Discharge voltage (0% SOC)
Batt.V_nominal = 48;       % Nominal operating voltage
Batt.I_max_charge = 50;    % Maximum charge current (50A)
Batt.I_max_discharge = 100;% Maximum discharge current (100A)
Batt.SOC_init = 0.5;       % Initial SOC (50%)
Batt.SOC_min = 0.1;        % Minimum SOC (10%)
Batt.SOC_max = 0.95;       % Maximum SOC (95%)

% معاملات محول ثنائي الاتجاه (Bidirectional Converter)
BiDir.fs = 10000;          % Switching frequency (10 kHz)
BiDir.L = 0.005;           % Inductance (5 mH)
BiDir.C_dc = 1000e-6;      % DC link capacitance (1000 µF)
BiDir.Vdc_ref = 900;       % DC link reference voltage (900V)

% معاملات PI Controller للبطارية
BiDir.Kp_V = 1.5;          % Voltage controller Kp
BiDir.Ki_V = 0.5;          % Voltage controller Ki
BiDir.Kp_I = 0.5;          % Current controller Kp
BiDir.Ki_I = 0.1;          % Current controller Ki

% معاملات العاكس (Inverter) - Three Phase
Inv.Vdc_nom = 900;         % DC link voltage (900V)
Inv.Vac_nom = 230;         % AC output voltage RMS (230V)
Inv.Vac_peak = Inv.Vac_nom * sqrt(2);  % Peak voltage
Inv.f_grid = 50;           % Grid frequency (50 Hz)
Inv.fs_inv = 5000;         % Inverter PWM frequency (5 kHz)
Inv.L_filter = 0.005;      % Filter inductance (5 mH)
Inv.C_filter = 100e-6;     % Filter capacitance (100 µF)
Inv.R_filter = 0.1;        % Filter resistance (0.1 Ω)

% معاملات PI Controller للعاكس
Inv.Kp_voltage = 1.5;      % Voltage controller Kp
Inv.Ki_voltage = 0.5;      % Voltage controller Ki
Inv.Kp_current = 0.5;      % Current controller Kp
Inv.Ki_current = 0.1;      % Current controller Ki

% معاملات مراقب الشبكة (PLL - Phase Locked Loop)
PLL.Kp = 100;              % Proportional gain
PLL.Ki = 5000;             % Integral gain
PLL.f_nom = 50;            % Nominal frequency (50 Hz)
PLL.omega_nom = 2*pi*50;   % Nominal angular frequency

% معاملات الشبكة الكهربائية (Grid)
Grid.Vnom = 230;           % Nominal voltage (230V RMS)
Grid.f_nom = 50;           % Nominal frequency (50 Hz)
Grid.omega_nom = 2*pi*50;  % Nominal angular frequency
Grid.R_line = 0.5;         % Line resistance (0.5 Ω)
Grid.L_line = 0.005;       % Line inductance (5 mH)
Grid.Z_short = Grid.R_line + 1j*2*pi*Grid.f_nom*Grid.L_line;  % Line impedance

% معايير الحماية (Protection Thresholds)
Protection.Vmin = 0.85 * Grid.Vnom;     % Under-voltage threshold
Protection.Vmax = 1.1 * Grid.Vnom;      % Over-voltage threshold
Protection.f_min = 47.5;                % Under-frequency threshold
Protection.f_max = 52.5;                % Over-frequency threshold
Protection.i_max = 50;                  % Maximum current (50A)
Protection.v_dc_max = 1000;             % Max DC link voltage (1000V)
Protection.v_dc_min = 800;              % Min DC link voltage (800V)

%% ===== معاملات المحاكاة =====

Sim.Ts = 1e-5;             % Simulation time step (10 µs)
Sim.T_total = 10;          % Total simulation time (10 seconds)
Sim.time = 0:Sim.Ts:Sim.T_total;  % Time vector

%% ===== معاملات الاختبار (Test Scenarios) =====

% السيناريو 1: شروق تدريجي
Test1.Irradiance = linspace(0, 1000, length(Sim.time));  % 0 → 1000 W/m²
Test1.Temperature = 25 * ones(size(Sim.time));

% السيناريو 2: غيوم متقطعة
t_cloud = 0:2:Sim.T_total;
Test2.Irradiance = 1000 * (0.5 + 0.5*sin(2*pi*Sim.time/2));  % ±500 W/m²
Test2.Temperature = 25 * ones(size(Sim.time));

% السيناريو 3: غروب تدريجي
Test3.Irradiance = linspace(1000, 0, length(Sim.time));  % 1000 → 0 W/m²
Test3.Temperature = 25 * ones(size(Sim.time));

% السيناريو 4: تأثير الحرارة
Test4.Irradiance = 1000 * ones(size(Sim.time));
Test4.Temperature = 25 + 25*sin(2*pi*Sim.time/Sim.T_total);  % 25 → 50°C

%% ===== حفظ المعاملات =====

save('Solar_System_Parameters.mat', 'PV', 'MPPT', 'Boost', 'Batt', ...
    'BiDir', 'Inv', 'PLL', 'Grid', 'Protection', 'Sim', 'Test1', 'Test2', 'Test3', 'Test4');

%% ===== طباعة ملخص المعاملات =====

disp('═════════════════════════════════════════════');
disp('✓ تمت تهيئة معاملات نظام الطاقة الشمسية بنجاح');
disp('═════════════════════════════════════════════');
disp(' ');
disp('📋 ملخص المعاملات:');
disp(['  • قوة PV: ' num2str(PV.Pmpp) ' W']);
disp(['  • جهد Boost: ' num2str(Boost.Vin_nom) 'V → ' num2str(Boost.Vout_nom) 'V']);
disp(['  • سعة البطارية: ' num2str(Batt.Capacity) ' Ah']);
disp(['  • جهد DC Link: ' num2str(Inv.Vdc_nom) ' V']);
disp(['  • جهد الشبكة: ' num2str(Grid.Vnom) ' V @ ' num2str(Grid.f_nom) ' Hz']);
disp(['  • زمن المحاكاة: ' num2str(Sim.T_total) ' ثانية']);
disp(' ');
disp('✓ تم حفظ المعاملات في: Solar_System_Parameters.mat');
disp('═════════════════════════════════════════════');
