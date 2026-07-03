function [names, cols] = make_gps_df(di, p_df)
% function [names, cols] = make_gps_df(di, p_df)
%
% Dataframe of ship GPS positions at times when the instrument is near the
% surface (instrument depth < p_df.surface_depth), one row per
% super-ensemble. Displacements use the same flat-earth conversion as the
% pipeline's ship-drift calculation (prepinv.m).
%
% columns: gps_t_step           - 0-based row counter
%          gps_t_clock          - ISO 8601 time stamp
%          t_seconds            - seconds since the first LADCP
%                                 super-ensemble (common time base
%                                 across all dataframes)
%          instrument_depth     - depth of the instrument [m, positive down]
%          gps_dt               - seconds since previous entry (NaN first)
%          total_displacement_x - m East of first entry
%          total_displacement_y - m North of first entry
%          rel_displacement_x   - m East of previous entry (NaN first)
%          rel_displacement_y   - m North of previous entry (NaN first)

names = {'gps_t_step','gps_t_clock','t_seconds','instrument_depth',...
         'gps_dt','total_displacement_x','total_displacement_y',...
         'rel_displacement_x','rel_displacement_y'};

idepth = -di.z(:);				% di.z negative below surface
slat = di.slat(:);
slon = di.slon(:);
tj = di.time_jul(:);

is = find(idepth < p_df.surface_depth & isfinite(slat) & isfinite(slon));

if isempty(is)
  disp('>>> WARNING: no near-surface GPS fixes found; gps.csv will be header-only');
  cols = {[],{},[],[],[],[],[],[],[]};
  return;
end

lat0 = slat(is(1));
lon0 = slon(is(1));
x = (slon(is)-lon0) * cos(lat0*pi/180) * 60 * 1852;	% m East
y = (slat(is)-lat0) * 60 * 1852;			% m North

cols = {(0:length(is)-1)', ...
        jul2iso(tj(is)), ...
        (tj(is)-tj(1)) * 86400, ...
        idepth(is), ...
        [NaN; diff(tj(is)) * 86400], ...
        x, ...
        y, ...
        [NaN; diff(x)], ...
        [NaN; diff(y)]};
