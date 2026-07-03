function failed = batch_create_dataframes(stations)
% function failed = batch_create_dataframes(stations)
%
% Run create_dataframes for a vector of station numbers; failures are
% caught and reported so one bad cast does not stop the batch.
%
% input  : stations - vector of station numbers, e.g. [2 3 5:12]
% output : failed   - station numbers that raised an error

failed = [];

for stn = stations(:)'
  fprintf('Creating dataframes for station %d\n', stn);
  try
    create_dataframes(stn);
  catch err
    fprintf('>>> FAILED station %d: %s\n', stn, err.message);
    failed(end+1) = stn;
  end
end

if isempty(failed)
  disp('All stations processed.');
else
  fprintf('Done; %d station(s) failed: %s\n', length(failed), num2str(failed));
end
