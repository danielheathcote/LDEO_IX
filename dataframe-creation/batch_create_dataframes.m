function failed = batch_create_dataframes(stations, yoyo)
% function failed = batch_create_dataframes(stations, yoyo)
%
% Run create_dataframes for a set of stations; failures are caught and
% reported so one bad cast does not stop the batch.
%
% input  : stations - vector of station numbers, e.g. [2 3 5:12]
%          yoyo     - OPTIONAL (default false). If true, every station is
%                     split into sub-casts (yoyo / tow-yo) and ALL yos of
%                     each station are processed: yo = 1, 2, 3, ... until
%                     the first yo whose downlooker raw file (f.ladcpdo,
%                     as built by set_dataframe_params.m) does not exist.
%                     Yos are assumed to be numbered contiguously from 1.
%
% output : failed   - casts that raised an error: a vector of station
%                     numbers, or N x 2 [stn yo] rows when yoyo is set

if nargin < 2, yoyo = 0; end

failed = [];

if ~yoyo

  for stn = stations(:)'
    fprintf('Creating dataframes for station %d\n', stn);
    try
      create_dataframes(stn);
    catch err
      fprintf('>>> FAILED station %d: %s\n', stn, err.message);
      failed(end+1) = stn;
    end
  end

else

  for stn = stations(:)'
    [ok, file1] = cast_exists(stn, 1);
    [dum, file2] = cast_exists(stn, 2);
    if strcmp(file1, file2)
      error(['set_dataframe_params.m builds the same f.ladcpdo for every yo', ...
             ' -- it does not use yo, so yoyo mode cannot discover sub-casts']);
    end
    if ~ok
      fprintf('>>> WARNING: station %d has no yo 1 raw file; skipping station\n', stn);
      continue;
    end
    yo = 1;
    while cast_exists(stn, yo)
      fprintf('Creating dataframes for station %d, yo %d\n', stn, yo);
      try
        create_dataframes([stn yo]);
      catch err
        fprintf('>>> FAILED station %d yo %d: %s\n', stn, yo, err.message);
        failed(end+1,:) = [stn yo];
      end
      yo = yo + 1;
    end
  end

end

if isempty(failed)
  disp('All casts processed.');
else
  fprintf('Done; %d cast(s) failed:\n', size(failed,1));
  disp(failed);
end

%----------------------------------------------------------------------

function [ok, ladcpdo] = cast_exists(stn, yo)
% source the cruise config for (stn, yo) and check whether the downlooker
% raw file exists -- keeps the file naming in set_dataframe_params.m as
% the single source of truth
set_dataframe_params;
ladcpdo = f.ladcpdo;
ok = exist(f.ladcpdo, 'file') == 2;
