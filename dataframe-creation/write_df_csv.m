function n = write_df_csv(fname, names, cols)
% function n = write_df_csv(fname, names, cols)
%
% write a long-form dataframe to CSV for use with pandas.read_csv
%
% input  : fname - output file name
%          names - cellstr of column names
%          cols  - cell array of columns (numeric vectors or cellstr),
%                  all of equal length (may be empty -> header-only file)
%
% output : n     - number of data rows written
%
% numeric values are written as %.10g (NaN literal is parsed natively by
% pandas); the header line is always written so schemas stay consistent.

if length(names) ~= length(cols)
  error('write_df_csv: names/cols length mismatch');
end

ncol = length(cols);
n = length(cols{1});
for j = 2:ncol
  if length(cols{j}) ~= n
    error('write_df_csv: column %d has %d rows, expected %d', ...
          j, length(cols{j}), n);
  end
end

fid = fopen(fname, 'w');
if fid < 0
  error('write_df_csv: cannot open %s for writing', fname);
end

fprintf(fid, '%s', names{1});
fprintf(fid, ',%s', names{2:end});
fprintf(fid, '\n');

for i = 1:n
  for j = 1:ncol
    if j > 1, fprintf(fid, ','); end
    if iscell(cols{j})
      fprintf(fid, '%s', cols{j}{i});
    else
      fprintf(fid, '%.10g', cols{j}(i));
    end
  end
  fprintf(fid, '\n');
end

fclose(fid);
