function s = jul2iso(jul)
% function s = jul2iso(jul)
%
% convert the pipeline's Julian days (see gregoria.m: JD 2440000 begins
% 0000h May 23 1968) to a cellstr of ISO 8601 time stamps
% 'yyyy-mm-ddTHH:MM:SS.FFF' suitable for pandas parse_dates.

g = gregoria(jul(:));
s = cellstr(datestr(datenum(g), 'yyyy-mm-ddTHH:MM:SS.FFF'));
