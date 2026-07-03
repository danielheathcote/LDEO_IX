function create_dataframes(stn, yo)
% function create_dataframes(stn, yo)
%
% input  : stn - station number (as for process_cast.m)
%          yo  - OPTIONAL sub-cast number, for cruises whose stations are
%                split into multiple casts (yoyo / tow-yo). It is not used
%                by the processing itself -- it is only made available to
%                set_dataframe_params.m for building file names, the cast
%                name and the output directory. Standard cruises omit it.
%
% Run the LDEO_IX preprocessing (steps 1-13 of ../process_cast.m) for one
% cast and, instead of calculating the inversion, export the super-ensemble
% data to long-form CSV files readable with pandas.read_csv (see README.md
% in this directory for the column definitions and sign conventions):
%
%   ladcp.csv  - individual LADCP measurements (velocity of ocean relative
%                to the instrument), one row per super-ensemble x bin
%   gps.csv    - ship GPS positions while the instrument is near the surface
%   btrack.csv - bottom-tracked instrument velocity
%   sadcp.csv  - shipboard ADCP velocities in the cast time window
%
% Configuration (paths, thresholds) lives in set_dataframe_params.m,
% the analogue of set_cast_params.m; edit it for your cruise.
% The step blocks below are copied from process_cast.m (minus the
% checkpoint/plot/diary machinery) so both stay diffable.

% make the LDEO_IX functions (loadrdi, prepinv, ...) resolve regardless of cwd
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
more off;

%----------------------------------------------------------------------
% STEP 0: DEFAULTS & CAST PARAMETERS
%----------------------------------------------------------------------

clear f d dr p ps di;			% blank slate

f.ladcpdo = ' ';			% required by default.m
default;				% load default parameters

set_dataframe_params;			% per-cast paths & p_df settings

if ~exist(p_df.outdir,'dir'), mkdir(p_df.outdir); end

if ~p_df.show_plots			% figures created inside the step
  set(0,'DefaultFigureVisible','off');	%  functions stay hidden
  restore_figvis = onCleanup(@() set(0,'DefaultFigureVisible','remove'));
end

used_depth_fallback = 0;

%----------------------------------------------------------------------
% STEP 1: LOAD LADCP DATA
%----------------------------------------------------------------------

[d,p]=loadrdi(f,p);

%----------------------------------------------------------------------
% STEP 2: FIX LADCP-DATA PROBLEMS
%----------------------------------------------------------------------

if existf(p,'beam_switch')==1, [d,p]=switchbeams(d,p); end

if p.fix_compass>0, [d,p]=fixcompass(d,p); end

%----------------------------------------------------------------------
% STEP 3: LOAD GPS DATA
%----------------------------------------------------------------------

p.navdata = 0;
if length(f.nav)>1 & exist('loadnav')==exist('loadrdi')
  [d,p]=loadnav(f,d,p);
else
  d.slon=NaN*d.time_jul; d.slat=d.slon;
end

%----------------------------------------------------------------------
% STEP 4: GET BOTTOM-TRACK DATA
%----------------------------------------------------------------------

ii1=sum(isfinite(d.hbot));
ii0=sum(d.hbot==0);
p.hbot_0=ii0/(ii1+1)*100;

if p.hbot_0>80
 p.bottomdist=1;
 disp([' WARNING found ',int2str(p.hbot_0),'% of  hbot=0  WARNING'])
end

[d,p]=getbtrack(d,p);

if d.down.Up
  disp(' discarding apparent bottom-track velocities from uplooker');
  d.bvel(find(isfinite(d.bvel))) = NaN;
end

%----------------------------------------------------------------------
% STEP 5: LOAD CTD PROFILE
%----------------------------------------------------------------------

if length(f.ctdprof)>1 & exist('loadctdprof')==exist('loadrdi')
  [d,p]=loadctdprof(f,d,p);
end

%----------------------------------------------------------------------
% STEP 6: LOAD CTD TIME SERIES
%----------------------------------------------------------------------

if length(f.ctd)>1 & exist('loadctd')==exist('loadrdi')
  [d,p]=loadctd(f,d,p);
end

%----------------------------------------------------------------------
% STEP 7: FIND SURFACE & SEA BED
%----------------------------------------------------------------------

if p.getdepth==2
  try
    [d,p]=getdpthi(d,p);
    if length(find(~isfinite(d.izm(1,:))))
      error('Missing values in d.izm --- likely missing values in CTD file');
    end
  catch depth_err
    if p_df.getdepth_fallback
      disp(['>>> WARNING: getdpthi (CTD depth) failed: ',depth_err.message]);
      disp('>>> falling back to p.getdepth=1 (integrated vertical velocity)');
      p.getdepth=1;
      [d,p]=getdpth(d,p);
      used_depth_fallback = 1;
    else
      rethrow(depth_err);
    end
  end
else
  [d,p]=getdpth(d,p);
end

%----------------------------------------------------------------------
% STEP 8: APPLY PITCH/ROLL CORRECTIONS
%----------------------------------------------------------------------

if length(p.tiltcor)>1
  pd.dpit=p.tiltcor(1);
  pd.drol=p.tiltcor(2);
  d=uvwrot(d,pd,1);
end

if length(p.tiltcor)>2
  pu.dpit=p.tiltcor(3);
  pu.drol=p.tiltcor(4);
  d=uvwrot(d,pu,0);
end

%----------------------------------------------------------------------
% STEP 9: EDIT DATA
%----------------------------------------------------------------------

d = edit_data(d,p);

%----------------------------------------------------------------------
% STEP 10: FORM SUPER ENSEMBLES
%----------------------------------------------------------------------

[di,p,d]=prepinv(d,p);

%----------------------------------------------------------------------
% STEP 11: REMOVE SUPER-ENSEMBLE OUTLIERS
%----------------------------------------------------------------------

% Reduce scatter by successively removing 1% of the data;
% lanarrow runs getinv with ps1.solve=0 and also produces dr for step 12.
if ps.outlier>0 | p.offsetup2down>0
  if exist('loadsadcp')==exist('loadrdi')
    [di,p]=loadsadcp(f,di,p);
  end
  dino=di;
  try
    lanarrow
  catch narrow_err
    disp(['>>> WARNING: outlier removal (lanarrow/getinv) failed: ',narrow_err.message]);
    disp('>>> continuing with un-narrowed super ensembles');
    di=dino;
  end
end

%----------------------------------------------------------------------
% STEP 12: RE-FORM SUPER ENSEMBLES
%----------------------------------------------------------------------

if (p.offsetup2down>0 & length(d.izu)>0 & exist('dr','var')==1)
  [di,p,d]=prepinv(d,p,dr);
end

%----------------------------------------------------------------------
% STEP 13: (RE-)LOAD SADCP DATA
%----------------------------------------------------------------------

if exist('loadsadcp')==exist('loadrdi')
  di=loadsadcp(f,di,p);
end

%----------------------------------------------------------------------
% EXPORT DATAFRAMES
%----------------------------------------------------------------------

disp(' ');
disp(['CREATE_DATAFRAMES: writing CSV files to ',p_df.outdir]);

[names,cols] = make_ladcp_df(di);
n_ladcp = write_df_csv([p_df.outdir,'ladcp.csv'], names, cols);

[names,cols] = make_gps_df(di, p_df);
n_gps = write_df_csv([p_df.outdir,'gps.csv'], names, cols);

[names,cols] = make_btrack_df(di);
n_btrack = write_df_csv([p_df.outdir,'btrack.csv'], names, cols);

[names,cols] = make_sadcp_df(f, p, di.time_jul(1));
n_sadcp = write_df_csv([p_df.outdir,'sadcp.csv'], names, cols);

if p_df.save_state
  save([p_df.outdir,'step13_state.mat'],'d','di','p','f');
end

%----------------------------------------------------------------------
% SUMMARY
%----------------------------------------------------------------------

tclock = jul2iso([di.time_jul(1) di.time_jul(end)]);
disp(' ');
disp(['CREATE_DATAFRAMES: ',p.name]);
disp(['  cast time span   : ',tclock{1},' to ',tclock{2}]);
disp(['  bottom depth     : ',num2str(p.zbottom),' m']);
if used_depth_fallback
  disp('  depth source     : integrated W (getdpth, FALLBACK)');
elseif p.getdepth==2
  disp('  depth source     : CTD pressure (getdpthi)');
else
  disp('  depth source     : integrated W (getdpth)');
end
disp(['  ladcp.csv  rows  : ',int2str(n_ladcp)]);
disp(['  gps.csv    rows  : ',int2str(n_gps)]);
disp(['  btrack.csv rows  : ',int2str(n_btrack)]);
disp(['  sadcp.csv  rows  : ',int2str(n_sadcp)]);

if ~p_df.show_plots
  close all;
end
