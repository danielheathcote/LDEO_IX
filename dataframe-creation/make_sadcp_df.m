function [names, cols] = make_sadcp_df(f, p, t0)
% function [names, cols] = make_sadcp_df(f, p, t0)
%
% Long-form dataframe of shipboard-ADCP velocities, one row per
% (profile, depth bin). Reads f.sadcp directly (loadsadcp.m collapses the
% SADCP data into a single mean profile, which is not what we want) but
% applies the same time window and position check as loadsadcp.m.
%
% input  : t0 - Julian day of the first LADCP super-ensemble (common
%               time base); profiles before t0 are rejected
%
% columns: sadcp_t_step  - 0-based in-window profile index
%          sadcp_t_clock - ISO 8601 time stamp
%          t_seconds     - seconds since the first LADCP super-ensemble
%          depth         - bin depth [m, positive down]
%          u, v          - zonal/meridional ocean velocity [m/s]

names = {'sadcp_t_step','sadcp_t_clock','t_seconds','depth','u','v'};
cols = {[],{},[],[],[],[]};

if existf(f,'sadcp')~=1 | length(f.sadcp)<2 | ~exist(f.sadcp,'file')
  disp('>>> WARNING: no SADCP file; sadcp.csv will be header-only');
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
  disp('>>> WARNING: no SADCP data in cast time window; sadcp.csv will be header-only');
  return;
end

% same position sanity check as loadsadcp.m
if abs(p.lon)+abs(p.lat)~=0 & ...
   (abs(mean(S.lon_sadcp(ii))-p.lon)>0.1/cos(p.lat*pi/360) | ...
    abs(mean(S.lat_sadcp(ii))-p.lat)>0.1)
  disp('>>> WARNING: SADCP data more than 0.1 degree from LADCP; sadcp.csv will be header-only');
  return;
end

nz = length(S.z_sadcp);
np = length(ii);

tj = S.tim_sadcp(ii); tj = tj(:);
tsec = (tj - t0) * 86400;
tclock = jul2iso(tj);

% expand to long form (depth bin varies fastest within each profile)
prof = kron((1:np)', ones(nz, 1));
depth = repmat(S.z_sadcp(:), np, 1);
u = S.u_sadcp(:,ii); u = u(:);
v = S.v_sadcp(:,ii); v = v(:);

keep = find(~(isnan(u) & isnan(v)));

cols = {prof(keep)-1, ...
        tclock(prof(keep)), ...
        tsec(prof(keep)), ...
        depth(keep), ...
        u(keep), ...
        v(keep)};
