function [names, cols] = make_btrack_df(di)
% function [names, cols] = make_btrack_df(di)
%
% Dataframe of bottom-tracked instrument velocities from the
% super-ensemble structure di (di.bvel is 4 x n with rows [u;v;w;err]).
%
% columns: t_step       - super-ensemble index, SAME numbering as t_step
%                         in ladcp.csv so the two frames join directly
%          bot_t_clock  - ISO 8601 time stamp
%          t_seconds    - seconds since the first LADCP super-ensemble
%                         (common time base across all dataframes)
%          bot_u, bot_v - bottom-tracked INSTRUMENT velocity over ground
%                         [m/s] (di.bvel holds the raw convention,
%                         seafloor minus instrument, so it is negated)

names = {'t_step','bot_t_clock','t_seconds','bot_u','bot_v'};

bu = -di.bvel(1,:)';
bv = -di.bvel(2,:)';
tj = di.time_jul(:);

keep = find(isfinite(bu) & isfinite(bv));

if isempty(keep)
  disp('>>> WARNING: no valid bottom-track data; btrack.csv will be header-only');
  cols = {[],{},[],[],[]};
  return;
end

cols = {keep-1, ...
        jul2iso(tj(keep)), ...
        (tj(keep)-tj(1)) * 86400, ...
        bu(keep), ...
        bv(keep)};
