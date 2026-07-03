function [names, cols] = make_ladcp_df(di)
% function [names, cols] = make_ladcp_df(di)
%
% Long-form dataframe of individual LADCP measurements from the
% super-ensemble structure di (output of prepinv/loadsadcp, i.e. the data
% exactly as the inversion sees them).
%
% One row per (super-ensemble, bin). u/v are velocities of the ocean
% relative to the instrument (NOT absolute ocean velocities).
%
% columns: t_step    - 0-based super-ensemble index (equal t_clock <=>
%                      equal t_step)
%          t_clock   - ISO 8601 time stamp
%          t_seconds - seconds since first super-ensemble
%          dt        - seconds since previous super-ensemble (NaN for first)
%          bin_idx   - signed bin number: +1..+N downlooker (1 nearest the
%                      instrument, increasing downward), -1..-M uplooker
%          depth     - depth of the measurement [m, positive down]
%          u, v      - zonal/meridional relative velocity [m/s]

names = {'t_step','t_clock','t_seconds','dt','bin_idx','depth','u','v'};

[nbins, nsup] = size(di.ru);

% per-super-ensemble time columns
tj = di.time_jul(:);
tsec = (tj - tj(1)) * 86400;
dtv = [NaN; diff(tj) * 86400];
tclock = jul2iso(tj);

% signed bin index per matrix row (uplooker rows first, see loadrdi.m:
% di.izu(b) / di.izd(b) give the matrix row of bin b of each instrument)
bin_idx = zeros(nbins, 1);
bin_idx(di.izu) = -(1:length(di.izu));
bin_idx(di.izd) = 1:length(di.izd);

% expand to long form; matrices are bins x time, so A(:) makes the bin
% index vary fastest within each t_step
ens = kron((1:nsup)', ones(nbins, 1));		% super-ensemble no. per row

bin_col = repmat(bin_idx, nsup, 1);

u = di.ru(:);
v = di.rv(:);
depth = -di.izm(:);				% di.izm negative below surface

keep = find(~(isnan(u) & isnan(v)));

cols = {ens(keep)-1, ...
        tclock(ens(keep)), ...
        tsec(ens(keep)), ...
        dtv(ens(keep)), ...
        bin_col(keep), ...
        depth(keep), ...
        u(keep), ...
        v(keep)};
