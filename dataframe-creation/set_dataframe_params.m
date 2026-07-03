% set_dataframe_params.m
%
% Per-cast configuration for create_dataframes.m -- the analogue of
% set_cast_params.m (see Processing_HowTo.pdf for the meaning of the
% f.* and p.* fields; they are identical here).
%
% This file is a WORKING EXAMPLE: edit the paths and file-layout fields
% for your cruise. It runs in the workspace of create_dataframes, which
% provides the station number `stn`.
%
% Notes specific to the dataframe export:
%  - p.getdepth = 2 uses CTD-pressure-derived instrument depth (more
%    accurate than integrated vertical velocity); create_dataframes falls
%    back to p.getdepth = 1 automatically if it fails (p_df.getdepth_fallback)
%  - if your casts do NOT start and end near the surface (e.g. tow-yo /
%    yoyo segments at depth), set p.cut = 0: otherwise loadctd.m rejects
%    the CTD pressure series (depth then silently comes from integrated W,
%    relative to the cast start instead of true depth) and returns early
%    without setting the cast start/end positions p.poss/p.pose

more off;

% -------------------- Cruise Information --------------------
p.cruise_id = 'MYCRUISE';
p.whoami = 'A. N. Oceanographer';
p.ladcp_station = stn;
p.name = sprintf('%s cast #%03d', p.cruise_id, p.ladcp_station);

% -------------------- LADCP Raw Files --------------------
f.ladcpdo = sprintf('data/raw_ladcp/%03dDL000.000', stn);  % downlooker
f.ladcpup = sprintf('data/raw_ladcp/%03dUL000.000', stn);  % uplooker
%f.ladcpup = ' ';   % no uplooker

% -------------------- Output Directory --------------------
p_df.outdir = sprintf('dataframes/%03d/', stn);
f.res = strcat(p_df.outdir, 'ladcp_df');   % log-file target only

% -------------------- CTD Time-Series Data --------------------
% ASCII table, one scan per line; column numbers below
f.ctd = sprintf('data/ctd_timeseries/%03d.asc', stn);
f.ctd_header_lines = 0;
f.ctd_fields_per_line = 6;
f.ctd_time_field = 1;
f.ctd_pressure_field = 2;
f.ctd_temperature_field = 3;
f.ctd_salinity_field = 4;
f.ctd_time_base = 0;           % 0: elapsed seconds; 1: year-day

% -------------------- Navigation Data --------------------
% ASCII table with time/lat/lon columns (may be the same file as f.ctd)
f.nav = f.ctd;
f.nav_header_lines = 0;
f.nav_fields_per_line = 6;
f.nav_time_field = 1;
f.nav_lon_field = 5;
f.nav_lat_field = 6;
f.nav_time_base = 0;

% -------------------- Optional SADCP Data --------------------
% .mat file with tim_sadcp, lat_sadcp, lon_sadcp, u_sadcp(z,t),
% v_sadcp(z,t), z_sadcp -- e.g. built by mkSADCP.m from CODAS output
f.sadcp = 'data/SADCP/SADCP.mat';
%f.sadcp = ' ';     % no SADCP

% -------------------- Processing Settings --------------------
p.saveplot = [];               % no diagnostic plots saved
p.checkpoints = [];
p.getdepth = 2;                % instrument depth from CTD pressure (p2z)
%p.cut = 0;                    % uncomment for casts that never surface
                               % (see header note)

% -------------------- Yoyo / Tow-Yo Cruises --------------------
% If each station is split into sub-casts, call create_dataframes(stn, yo)
% (or batch_create_dataframes(stations, true), which discovers all yos of
% each station automatically) and use BOTH numbers in the file names and
% output directory, e.g.:
%
% p.name    = sprintf('%s cast #%03d yo #%d', p.cruise_id, stn, yo);
% f.ladcpdo = sprintf('data/raw_ladcp/%03d_%03dDL000.000', stn, yo);
% f.ladcpup = sprintf('data/raw_ladcp/%03d_%03dUL000.000', stn, yo);
% f.ctd     = sprintf('data/ctd_timeseries/%03d_%03d.asc', stn, yo);
% p_df.outdir = sprintf('dataframes/%03d_%03d/', stn, yo);
% f.res     = strcat(p_df.outdir, 'ladcp_df');
% p.cut     = 0;   % yo segments at depth never surface (see header note)

% -------------------- Dataframe Export Settings --------------------
p_df.surface_depth     = 20;   % [m] instrument depth threshold for gps.csv
                               %  (Inf: dump ship track at every timestep)
p_df.show_plots        = 0;    % 1 = leave diagnostic figures visible
p_df.save_state        = 1;    % also save step13_state.mat (d,di,p,f)
p_df.getdepth_fallback = 1;    % on getdpthi failure retry with p.getdepth=1
