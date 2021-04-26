
% Close an open video.
%
%    video_close(vinfo)
%
% closes any open files associated with the video specified by vinfo.
%
function video_close(vinfo)
   % check video type
   if (strcmp(vinfo.type,'seq'))
      vinfo.seq.sr.close();
   elseif strcmpi(vinfo.type,'ufmf'),
     try fclose(vinfo.ufmf.fid); end %#ok<TRYNC>
   end
end
