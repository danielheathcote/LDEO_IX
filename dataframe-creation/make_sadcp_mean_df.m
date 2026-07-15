function [names, cols] = make_sadcp_mean_df(f, p, t0)
% function [names, cols] = make_sadcp_mean_df(f, p, t0)
%
% Mean-profile dataframe of shipboard-ADCP velocities: one row per depth
% bin, collapsing the same in-window SADCP profiles that make_sadcp_df.m
% expands to long form (same file load, time window, and position check).
%
% input  : t0 - Julian day of the first LADCP super-ensemble (common
%               time base); profiles before t0 are rejected
%
% columns: depth      - bin depth [m, positive down]
%          u, v       - mean zonal/meridional ocean velocity [m/s],
%                        averaged (NaN-ignoring) across in-window profiles
%          u_std, v_std - sample std of u/v across in-window profiles;
%                        note: stdnan returns 0 (not NaN) for a bin with
%                        only one valid profile in the window

names = {'depth','u','v','u_std','v_std'};
cols = {[],[],[],[],[]};

if existf(f,'sadcp')~=1 | length(f.sadcp)<2 | ~exist(f.sadcp,'file')
  disp('>>> WARNING: no SADCP file; sadcp_mean.csv will be header-only');
  return;
end

S = load(f.sadcp);
% expected: tim_sadcp(t) [Julian days], lat_sadcp(t), lon_sadcp(t),
%           u_sadcp(z,t), v_sadcp(z,t) [m/s], z_sadcp(z,1) [m, positive]

% same time window as loadsadcp.m, but never before the first LADCP
% super-ensemble (t_seconds must not go negative)
p = setdefv(p,'sadcp_dtok',0);
ii = find(S.tim_sadcp > (julian(p.time_start)-p.sadcp_dtok) & ...
          S.tim_sadcp < (julian(p.time_end)+p.sadcp_dtok) & ...
          S.tim_sadcp >= t0);

if isempty(ii)
  disp('>>> WARNING: no SADCP data in cast time window; sadcp_mean.csv will be header-only');
  return;
end

% same position sanity check as loadsadcp.m
if abs(p.lon)+abs(p.lat)~=0 & ...
   (abs(mean(S.lon_sadcp(ii))-p.lon)>0.1/cos(p.lat*pi/360) | ...
    abs(mean(S.lat_sadcp(ii))-p.lat)>0.1)
  disp('>>> WARNING: SADCP data more than 0.1 degree from LADCP; sadcp_mean.csv will be header-only');
  return;
end

% collapse across in-window profiles, one row per depth bin
u_win = S.u_sadcp(:,ii);
v_win = S.v_sadcp(:,ii);
u_mean = meannan(u_win')';
v_mean = meannan(v_win')';
u_std = stdnan(u_win')';
v_std = stdnan(v_win')';
depth = S.z_sadcp(:);

keep = find(~(isnan(u_mean) & isnan(v_mean)));

cols = {depth(keep), ...
        u_mean(keep), ...
        v_mean(keep), ...
        u_std(keep), ...
        v_std(keep)};
