% unsteady_run.m
%
% Parameterized, plot-free version of quasi1d.m. Runs the explicit
% flux-vector-split unsteady solver from a space-marched initial
% condition and returns time-history data for plotting by the driver.
%
% INPUT (struct opts):
%   opts.gamma, opts.amach0, opts.p0, opts.rho0
%   opts.xlength, opts.xsh
%   opts.jmax, opts.cfl
%   opts.itsteady (iterations to converge to steady before forcing)
%   opts.imeth   (-2 AUSM, -1 vanLeer, +1 Steger-Warming)
%   opts.dpvar   (fractional exit-pressure oscillation)
%   opts.timeper (period scale; itperiod = 400*irefine*timeper)
%   opts.iper    (number of forced periods)
%   opts.itplots (snapshots per period; default 16)
%
% OUTPUT (struct R):
%   R.x                  (1 x jmax)  grid
%   R.area               (1 x jmax)  cell-center area
%   R.p_steady           pressure at end of itsteady ramp-up
%   R.amach_steady       Mach at end of itsteady
%   R.p_envelope         (jmax x Nsnap) snapshots taken during the LAST forced period
%   R.amach_envelope     (jmax x Nsnap) Mach snapshots, same cadence
%   R.t_envelope         (1 x Nsnap) snapshot times in fraction-of-period
%   R.t_probe            (1 x Nfull) probe-time vector (fraction of period) over all forced periods
%   R.p_probe            (1 x Nfull) probe pressure history
%   R.normit, R.normres  residual histories (1 x itmax)
%   R.xsh, R.xprobe      bookkeeping
%   R.p_final            final pressure profile
%
function R = unsteady_run(opts)
    gamma   = opts.gamma;
    amach0  = opts.amach0;
    p0      = opts.p0;
    rho0    = opts.rho0;
    xlength = opts.xlength;
    xsh     = opts.xsh;
    jmax    = opts.jmax;
    cfl     = opts.cfl;
    itsteady= opts.itsteady;
    imeth   = opts.imeth;
    dpvar   = opts.dpvar;
    timeper = opts.timeper;
    iper    = opts.iper;
    if isfield(opts,'itplots'); itplots = opts.itplots; else; itplots = 16; end

    % derive irefine from jmax (jmax = 40*irefine + 1)
    irefine = (jmax - 1) / 40;
    itperiod = round(irefine * 400 * timeper);
    itmax = itsteady + itperiod * iper;

    dx = xlength / (jmax - 1);
    x = 0:dx:xlength;
    area    = calcarea(x);
    areaint = calcarea(x + 0.5*dx);

    xprobe = xsh + 0.05 * xlength;
    iloc = floor(xprobe/xlength*(jmax-1) + 1);
    fprobe = (xprobe - x(iloc)) / dx;

    [rho_sp, u_sp, p_sp, e_sp, amach_sp] = ...
        spacemarch(gamma, amach0, p0, rho0, xsh, x, area, 1);
    rho = rho_sp; u = u_sp; p = p_sp; e = e_sp; amach = amach_sp;
    pend = p(jmax);

    q = loadq(rho, u, e, area);

    dq = zeros(3, jmax);
    fluxjp = zeros(3, jmax-1);
    normit  = zeros(1, itmax);
    normres = zeros(1, itmax);

    n_probe = itperiod * iper;
    p_probe = zeros(1, n_probe);

    snap_stride = max(1, round(itperiod / itplots));
    n_snap_max = ceil(itperiod / snap_stride) + 2;
    p_envelope     = zeros(jmax, n_snap_max);
    amach_envelope = zeros(jmax, n_snap_max);
    t_envelope     = zeros(1, n_snap_max);
    n_snap = 0;

    p_steady = p_sp;
    amach_steady = amach_sp;

    for iter = 1:itmax
        if iter < itsteady
            dtdx = min(cfl ./ (abs(u) + u ./ amach));
        end

        if imeth == 1
            [fluxp, fluxn] = steger_flux(gamma, area, rho, u, p, e);
            fluxjp(:, 1:jmax-1) = fluxp(:, 1:jmax-1) + fluxn(:, 2:jmax);
        elseif imeth == -1
            [fluxp, fluxn] = vanl_flux(gamma, area, rho, u, p, e);
            fluxjp(:, 1:jmax-1) = fluxp(:, 1:jmax-1) + fluxn(:, 2:jmax);
        elseif imeth == -2
            fluxjp = ausm_flux(gamma, areaint, rho, u, p, e);
        end

        if imeth <= 1
            dq(:, 2:jmax-1) = -dtdx * (fluxjp(:, 2:jmax-1) - fluxjp(:, 1:jmax-2));
            dq(2, 2:jmax-1) = dq(2, 2:jmax-1) + ...
                dtdx * p(2:jmax-1) .* (areaint(2:jmax-1) - areaint(1:jmax-2));
        end

        dq = calcbc(gamma, dq, p, rho, u, area, dtdx, dpvar, pend, ...
                    itperiod, iter, itsteady);

        rsq = sqrt(dq(1,:).^2 + dq(2,:).^2 + dq(3,:).^3);
        normres(iter) = norm(rsq, 2);
        normit(iter)  = normres(iter);

        q = q + dq;
        [rho, u, p, e, amach] = loadpr(q, area, gamma);

        if iter == itsteady
            pend = p(jmax);
            p_steady = p;
            amach_steady = amach;
        end

        if iter > itsteady
            k = iter - itsteady;
            p_probe(k) = (1 - fprobe) * p(iloc) + fprobe * p(iloc + 1);

            % snapshot during LAST forced period
            if iter > itmax - itperiod && mod(iter - itsteady, snap_stride) == 0
                n_snap = n_snap + 1;
                p_envelope(:, n_snap)     = p(:);
                amach_envelope(:, n_snap) = amach(:);
                t_envelope(n_snap) = (iter - itsteady) / itperiod;
            end
        end
    end

    p_envelope     = p_envelope(:, 1:n_snap);
    amach_envelope = amach_envelope(:, 1:n_snap);
    t_envelope     = t_envelope(1:n_snap);

    R = struct();
    R.x = x;
    R.area = area;
    R.p_steady = p_steady;
    R.amach_steady = amach_steady;
    R.p_envelope = p_envelope;
    R.amach_envelope = amach_envelope;
    R.t_envelope = t_envelope;
    R.t_probe = (1:n_probe) / itperiod;
    R.p_probe = p_probe;
    R.normit = normit;
    R.normres = normres;
    R.xsh = xsh;
    R.xprobe = xprobe;
    R.p_final = p;
    R.amach_final = amach;
    R.itsteady = itsteady;
    R.itperiod = itperiod;
end
