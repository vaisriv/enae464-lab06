% index.m
%
% Lab 06 driver — Transonic Flow in a Quasi-1D Nozzle
%
% Produces every figure required by the assignment (B–E) plus derived
% data tables under outputs/text/. Designed to run via:
%     matlab -batch "cd('src'); index"
%
% Calls: calcarea.m, spacemarch.m, findshock.m, vanl_flux.m,
%        unsteady_run.m, save_fig.m
%

clear; close all;
here = fileparts(mfilename('fullpath'));
addpath(here);
text_dir = fullfile(here, '..', 'outputs', 'text');
if ~exist(text_dir, 'dir'); mkdir(text_dir); end

% Visible='off' so matlab -batch doesn't try to render windows
set(groot, 'defaultFigureVisible', 'off');
set(groot, 'defaultAxesFontSize', 14);
set(groot, 'defaultAxesLineWidth', 1.25);
set(groot, 'defaultLineLineWidth', 1.5);

% --- Common parameters ---
gamma   = 1.4;
amach0  = 1.50;
p0      = 0.25;
rho0    = 0.50;
xlength = 10.0;
pexit_target = 1/gamma;     % atmospheric in non-dimensional units (~0.7143)

%% ============================================================
%  Section B - Plot 1: nozzle geometry  +- r(x)
%% ============================================================
x_geom = linspace(0, xlength, 401);
A_geom = calcarea(x_geom);
r_geom = sqrt(A_geom / pi);

fh = figure('Position', [100 100 750 450]);
fill([x_geom, fliplr(x_geom)], [r_geom, fliplr(-r_geom)], ...
     [0.85 0.92 1.0], 'EdgeColor', 'none'); hold on;
plot(x_geom,  r_geom, 'b-');
plot(x_geom, -r_geom, 'b-');
plot([0 xlength], [0 0], 'k--', 'LineWidth', 0.75);
hold off; grid on; box on;
xlabel('x (non-dim.)');
ylabel('\pm r(x) (non-dim.)');
title('Nozzle Geometry: \pmr(x) = \pm\surd(A(x)/\pi)');
axis([0 xlength -1.0 1.0]);
save_fig(fh, 'fig01_geometry');
close(fh);

% record geometry endpoints for the report
fid = fopen(fullfile(text_dir, 'geometry_endpoints.txt'), 'w');
fprintf(fid, 'A(0)  = %.4f, r(0)  = %.4f\n', A_geom(1),   r_geom(1));
fprintf(fid, 'A(10) = %.4f, r(10) = %.4f\n', A_geom(end), r_geom(end));
fclose(fid);

%% ============================================================
%  Section C - Plots 2 & 3: space marching, xsh = 4.0
%% ============================================================
xsh_fixed = 4.0;

for irefine = [2, 1]
    jmax = 40*irefine + 1;
    dx = xlength/(jmax-1);
    x  = 0:dx:xlength;
    A  = calcarea(x);

    [~,~,p_pc, ~, ~] = spacemarch(gamma, amach0, p0, rho0, xsh_fixed, x, A, 1);
    [~,~,p_pr, ~, ~] = spacemarch(gamma, amach0, p0, rho0, xsh_fixed, x, A, 0);

    fh = figure('Position', [100 100 750 450]);
    plot(x, p_pc, 'r-' , 'LineWidth', 2.0); hold on;
    plot(x, p_pr, 'g--', 'LineWidth', 2.0); hold off;
    grid on; box on;
    xlabel('x'); ylabel('p');
    title(sprintf('Space Marching: p vs. x  (x_{sh}=4.0, j_{max}=%d)', jmax));
    legend({'Predictor-Corrector', 'Predictor only'}, 'Location', 'NorthWest');
    axis([0 xlength 0 1.0]);

    if irefine == 2
        save_fig(fh, 'fig02_spacemarch_xsh4_jmax81');
    else
        save_fig(fh, 'fig03_spacemarch_xsh4_jmax41');
    end
    close(fh);
end

%% ============================================================
%  Section C - Plots 4 & 5: varying xsh, jmax = 161, pred-corr
%% ============================================================
irefine_4 = 4;
jmax_4 = 40*irefine_4 + 1;
dx_4 = xlength/(jmax_4-1);
x_4  = 0:dx_4:xlength;
A_4  = calcarea(x_4);

xsh_list = 3:0.5:9;
n_xsh = length(xsh_list);
p_list = zeros(n_xsh, jmax_4);
p_exit = zeros(1, n_xsh);

cmap = parula(n_xsh);
fh = figure('Position', [100 100 800 480]);
hold on;
for k = 1:n_xsh
    [~,~,pk,~,~] = spacemarch(gamma, amach0, p0, rho0, xsh_list(k), x_4, A_4, 1);
    p_list(k, :) = pk;
    p_exit(k) = pk(end);
    plot(x_4, pk, '-', 'Color', cmap(k,:), 'LineWidth', 1.6);
end
hold off; grid on; box on;
xlabel('x'); ylabel('p');
title('Pressure vs. x (predictor-corrector, j_{max}=161, varying x_{sh})');
legend(arrayfun(@(s) sprintf('x_{sh}=%.1f', s), xsh_list, ...
                'UniformOutput', false), 'Location', 'EastOutside');
axis([0 xlength 0 1.0]);
save_fig(fh, 'fig04_spacemarch_varying_xsh');
close(fh);

fh = figure('Position', [100 100 750 450]);
plot(xsh_list, p_exit, 'ro-', 'LineWidth', 2.0, 'MarkerFaceColor', 'r');
grid on; box on;
xlabel('x_{sh}'); ylabel('p_{exit}');
title('Exit Pressure vs. Shock Location  (predictor-corrector, j_{max}=161)');
save_fig(fh, 'fig05_exit_pressure_vs_xsh');
close(fh);

% save the table for the report
fid = fopen(fullfile(text_dir, 'exit_pressure_vs_xsh.csv'), 'w');
fprintf(fid, 'xsh,p_exit\n');
for k = 1:n_xsh
    fprintf(fid, '%.2f,%.6f\n', xsh_list(k), p_exit(k));
end
fclose(fid);

%% ============================================================
%  Section D - Plots 6 & 7: shock capturing (steady) vs space-march
%% ============================================================
xsh_init = 3.125;

% space-march reference at the matching shock location (gives p_exit=1/gamma)
xsh_match = findshock(gamma, amach0, p0, rho0, 2.65, 5.85, x_4, A_4, 1, pexit_target);

xsh_capt_81 = NaN; xsh_capt_161 = NaN;
for irefine = [2, 4]
    jmax = 40*irefine + 1;
    dx   = xlength/(jmax-1);
    xg   = 0:dx:xlength;
    Ag   = calcarea(xg);

    opts = struct('gamma', gamma, 'amach0', amach0, 'p0', p0, 'rho0', rho0, ...
                  'xlength', xlength, 'xsh', xsh_init, ...
                  'jmax', jmax, 'cfl', 0.9, ...
                  'itsteady', 1500*irefine, 'imeth', -1, ...
                  'dpvar', 0.0, 'timeper', 1.0, 'iper', 1);
    R = unsteady_run(opts);

    [~,~,p_pcm,~,~] = spacemarch(gamma, amach0, p0, rho0, xsh_match, xg, Ag, 1);

    % shock-capture location: where |dp/dx| is maximum
    dpdx = abs(diff(R.p_final) ./ diff(R.x));
    [~, ish] = max(dpdx);
    xsh_capt = 0.5*(R.x(ish) + R.x(ish+1));

    fh = figure('Position', [100 100 800 480]);
    plot(R.x, R.p_final, 'r-',  'LineWidth', 2.0); hold on;
    plot(xg,  p_pcm,     'b--', 'LineWidth', 2.0); hold off;
    grid on; box on;
    xlabel('x'); ylabel('p');
    title(sprintf(['Shock Capturing (van Leer) vs. Space Marching ' ...
                   '(j_{max}=%d, p_{exit}=1/\\gamma)'], jmax));
    legend({sprintf('van Leer (capt. x_{sh}\\approx%.2f)', xsh_capt), ...
            sprintf('Space-march pred-corr (x_{sh}=%.3f)', xsh_match)}, ...
           'Location', 'NorthWest');
    axis([0 xlength 0 1.0]);

    if irefine == 2
        save_fig(fh, 'fig06_shockcap_vs_spacemarch_jmax81');
        xsh_capt_81 = xsh_capt;
    else
        save_fig(fh, 'fig07_shockcap_vs_spacemarch_jmax161');
        xsh_capt_161 = xsh_capt;
    end
    close(fh);
end

fid = fopen(fullfile(text_dir, 'captured_shock_loc.csv'), 'w');
fprintf(fid, 'jmax,xsh_captured,xsh_spacemarch_target\n');
fprintf(fid, '81,%.4f,%.4f\n', xsh_capt_81,  xsh_match);
fprintf(fid, '161,%.4f,%.4f\n', xsh_capt_161, xsh_match);
fclose(fid);

%% ============================================================
%  Section E - Plots 8-17: unsteady cases (envelope + probe history)
%  Plot 18: Mach envelope for the moderate case
%% ============================================================
irefine_u = 4;
jmax_u    = 40*irefine_u + 1;

cases = struct( ...
    'name', {'moderate', 'long', 'short', 'small', 'large'}, ...
    'dpvar', {0.10, 0.10, 0.10, 0.02, 0.20}, ...
    'timeper', {1.0, 2.0, 0.5, 1.0, 1.0}, ...
    'slug_env', {'fig08_unsteady_env_mod',   'fig10_unsteady_env_long', ...
                 'fig12_unsteady_env_short', 'fig14_unsteady_env_small', ...
                 'fig16_unsteady_env_large'}, ...
    'slug_time',{'fig09_unsteady_probe_mod',   'fig11_unsteady_probe_long', ...
                 'fig13_unsteady_probe_short', 'fig15_unsteady_probe_small', ...
                 'fig17_unsteady_probe_large'});

R_moderate = [];   % cache for plot 18

for c = 1:numel(cases)
    cs = cases(c);
    opts = struct('gamma', gamma, 'amach0', amach0, 'p0', p0, 'rho0', rho0, ...
                  'xlength', xlength, 'xsh', xsh_init, ...
                  'jmax', jmax_u, 'cfl', 0.9, ...
                  'itsteady', 1500*irefine_u, 'imeth', -1, ...
                  'dpvar', cs.dpvar, 'timeper', cs.timeper, 'iper', 6);

    fprintf('Running unsteady case "%s" (dpvar=%.2f, timeper=%.2f) ...\n', ...
            cs.name, cs.dpvar, cs.timeper);
    R = unsteady_run(opts);

    if strcmp(cs.name, 'moderate'); R_moderate = R; end

    % --- envelope plot ---
    fh = figure('Position', [100 100 800 480]);
    plot(R.x, R.p_steady, 'k-', 'LineWidth', 2.5); hold on;
    n_snap = size(R.p_envelope, 2);
    cm = parula(max(n_snap, 2));
    for k = 1:n_snap
        plot(R.x, R.p_envelope(:,k), '-', 'Color', cm(k,:), 'LineWidth', 1.0);
    end
    hold off; grid on; box on;
    xlabel('x'); ylabel('p');
    title(sprintf(['Unsteady pressure envelope (last period): ' ...
                   '\\Deltap_{var}=%.2f, T=%.2f'], cs.dpvar, cs.timeper));
    legend({'Steady reference', 'Snapshots over last period'}, ...
           'Location', 'NorthWest');
    axis([0 xlength 0 1.05]);
    save_fig(fh, cs.slug_env);
    close(fh);

    % --- probe time history ---
    fh = figure('Position', [100 100 800 420]);
    plot(R.t_probe, R.p_probe, 'r-', 'LineWidth', 1.5);
    grid on; box on;
    xlabel('Time (fraction of period)');
    ylabel(sprintf('p at x = x_{sh}+0.05 L = %.3f', R.xprobe));
    title(sprintf(['Probe pressure history (6 periods): ' ...
                   '\\Deltap_{var}=%.2f, T=%.2f'], cs.dpvar, cs.timeper));
    save_fig(fh, cs.slug_time);
    close(fh);
end

%% --- Plot 18: Mach envelope for moderate case ---
fh = figure('Position', [100 100 800 480]);
plot(R_moderate.x, R_moderate.amach_steady, 'k-', 'LineWidth', 2.5); hold on;
n_snap = size(R_moderate.amach_envelope, 2);
cm = parula(max(n_snap, 2));
for k = 1:n_snap
    plot(R_moderate.x, R_moderate.amach_envelope(:,k), '-', ...
         'Color', cm(k,:), 'LineWidth', 1.0);
end
plot([0 xlength], [1 1], 'k--', 'LineWidth', 0.75);
hold off; grid on; box on;
xlabel('x'); ylabel('Mach number');
title('Unsteady Mach-number envelope (moderate case: \Deltap_{var}=0.10, T=1)');
legend({'Steady reference', 'Snapshots over last period', 'M = 1'}, ...
       'Location', 'NorthEast');
axis([0 xlength 0 2.5]);
save_fig(fh, 'fig18_unsteady_mach_env_mod');
close(fh);

disp('All 18 figures written to outputs/figures/.');
