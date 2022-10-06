function success = core_tracker_job_combine(output_per_chamber_track_file_name, ...
                                            output_segmentation_file_name, ...
                                            atomic_track_file_name_from_chunk_index, ...
                                            calibration_or_calibration_file_name, ...
                                            options)
  % Join output of multiple chunks into a single file
  success = 0 ;
  ensure_file_does_not_exist(output_per_chamber_track_file_name) ;
  save_seg = 0; 
  if isfield(options,'save_seg'), save_seg = options.save_seg; end  
  if save_seg ,
      ensure_file_does_not_exist(output_segmentation_file_name) ;
  end
  % load info
  if isstruct(calibration_or_calibration_file_name) ,
      calib = calibration_or_calibration_file_name ;
  else
      calibration_file_name = calibration_or_calibration_file_name ;
      calibration_file_contents = load(calibration_file_name) ; 
      calib = calibration_file_contents.calib ;
  end
  im_size = size(calib.mask);
  % initialize waitbar
  steps = 0;  
  n_steps = numel(atomic_track_file_name_from_chunk_index) + 1 + save_seg;
  do_use_display = options.isdisplay && feature('ShowFigureWindows') ;
  waitstr = ['Combining tracks'];
  if do_use_display
     multiWaitbar(waitstr,0,'Color','g','CanCancel','on');
     waitObject = onCleanup(@() multiWaitbar(waitstr,'Close'));
  end      

  % COMBINE TRACKS
  % count number of sequences and number of frames
  n_seq = 0;
  n_frm = options.startframe-1;
  n_seq_guess = numel(atomic_track_file_name_from_chunk_index)*calib.n_flies;
  n_frm_guess = numel(atomic_track_file_name_from_chunk_index)*options.granularity;      
  endframe_guess = n_frm_guess + options.startframe-1;
  % initialize combined tracks
  trk.frame_ids      = zeros([1 endframe_guess]);
  trk.frame_ids(1:options.startframe-1) = 1:options.startframe-1;
  trk.frame_seq_list = cell([endframe_guess 1]);
  trk.sequences      = cell([endframe_guess 1]);
  flags = [];
  if save_seg
      frame_data = cell([endframe_guess 1]);
  end      
  s = 0;
  f = options.startframe-1;
  for n = 1:numel(atomic_track_file_name_from_chunk_index)
     % load partial track
     f_trk_curr = atomic_track_file_name_from_chunk_index{n};
     trk_curr = load(f_trk_curr);
     trk_curr = trk_curr.trks;
     % find swaps
     flags = [flags; trk_curr.flags];
     % update counts
     n_seq = n_seq + numel(trk_curr.sequences);
     n_frm = n_frm + numel(trk_curr.frame_ids);
     % store frame ids
     trk.frame_ids((f+1):(f+numel(trk_curr.frame_ids))) = ...
        trk_curr.frame_ids;
     % store frame sequence list, adjusting offsets
     for fnum = 1:numel(trk_curr.frame_seq_list)
        trk.frame_seq_list{f+fnum} = trk_curr.frame_seq_list{fnum} + s;
     end
     % store sequences, adjusting start and end times
     for snum = 1:numel(trk_curr.sequences)
        seq = trk_curr.sequences{snum};
        seq.time_start = seq.time_start + f;
        seq.time_end   = seq.time_end + f;
        trk.sequences{s+snum} = seq;
     end
     % store segmentation
     if save_seg
        frame_data((f+1):(f+numel(trk_curr.frame_ids))) = trk_curr.frame_data;
     end
     % update indices
     s = s + numel(trk_curr.sequences);
     f = f + numel(trk_curr.frame_ids);
     % update waitbar
     steps = steps + 1;
     if do_use_display   
        abort = multiWaitbar(waitstr,steps/n_steps);
        if abort, return; end
     end 
  end
  % update trk in case n_frm_guess and n_seq_guess were off
  trk.frame_ids      = trk.frame_ids(1:n_frm);  
  trk.frame_seq_list = trk.frame_seq_list(1:n_frm);
  trk.sequences      = trk.sequences(1:n_seq);
  if save_seg 
      frame_data = frame_data(1:n_frm);
  end
  % link tracks
  trk = track_link(trk,calib);
  % make sure flag sequences correspond to the linked sequences
  chunk = options.granularity;
  valid = find(mod(trk.stitch_gaps(:,2),chunk) == 0 & ...
      trk.stitch_gaps(:,1)-trk.stitch_gaps(:,2) == 1);  %look only at chunk intersections
  for v=1:numel(valid)
    i = valid(v);
    inds = find(flags(:,3) > chunk*v & flags(:,4) <= chunk*(v+1));
    [~,seq_idx] = sort(trk.stitch_seq_map{i}(calib.n_flies+1:end));
    map = trk.stitch_seqs{i}(calib.n_flies+1:end);
    seq_map = map(seq_idx);
    flags(inds,1:2) = seq_map(flags(inds,1:2));
  end
  % order sequences such that the lower id is first 
  flagSeqs = flags(:,1:2);
  flags(:,1:2) = [min(flagSeqs,[],2) max(flagSeqs,[],2)];                     
  trk.flags = flags; %%TODO union with current trk.flags?
  % check whether coordinates need to be adjusted to roi
  adjust = 0;
  if isfield(trk_curr,'roi') 
      shift = [trk_curr.roi(2)-1 trk_curr.roi(1)-1];
      roi_size = [trk_curr.roi(3)-trk_curr.roi(1)+1 ...
          trk_curr.roi(4)-trk_curr.roi(2)+1];
      if sum(roi_size==im_size) < 2  
        adjust = 1;
      end
  end      
  % gather sequences to data matrix
  n_objs = numel(trk.sequences);
  n_frames = numel(trk.frame_ids);
  trk.names = trk_curr.names;
  n_feats = numel(trk.names);  
  trk.data = nan(n_objs,n_frames,n_feats);
  for s=1:n_objs
      frames = trk.sequences{s}.time_start:trk.sequences{s}.time_end;
      trk.data(s,frames,:) = trk.sequences{s}.track;
  end
  % adjust roi cropped coordinates
  if adjust
      trk.data(:,:,[1 10 12 18:2:28]) = trk.data(:,:,[1 10 12 18:2:28]) + shift(1);
      trk.data(:,:,[2 11 13 19:2:29]) = trk.data(:,:,[2 11 13 19:2:29]) + shift(2);
  end
  % remove unnecessary fields from trk
  trk_full = trk; trk = [];
  trk.names = trk_full.names;
  trk.data  = trk_full.data;      
  trk.flags = trk_full.flags;      
  if sum(abs(trk_full.frame_ids - (0:size(trk.data,2)-1))) ~= 0
      trk.frame_ids = trk_full.frame_ids;          
  end
  % update waitbar
  steps = steps + 1;
  if do_use_display   
     abort = multiWaitbar(waitstr,steps/n_steps);
     if abort, return; end
  end  
  
  % COMBINE SEGMENTATION
  if save_seg
      seg = cell(n_frm,1);
      for f=options.startframe:n_frm
          flies = cell(1,numel(trk_full.sequences));
          for c=1:numel(trk_full.sequences)
              flies{c}.body = [];
              flies{c}.wings = [];
              flies{c}.legs = [];
              flies{c}.rem = [];
              fr = f-trk_full.sequences{c}.time_start + 1;
              if fr < 1, continue; end
              if fr > numel(trk_full.sequences{c}.obj_list), continue; end
              obj_id = trk_full.sequences{c}.obj_list(fr);
              if obj_id == 0, continue; end
              flies{c}.body = frame_data{f}.body_cc.PixelIdxList{obj_id};
              flies{c}.wings = frame_data{f}.seg.body_wing_pixels{obj_id};
              flies{c}.legs = frame_data{f}.seg.body_leg_pixels{obj_id};
              fg_id = frame_data{f}.body_fg(obj_id);
              fg_pix = frame_data{f}.fg_cc.PixelIdxList{fg_id};
              fg_pix = setdiff(fg_pix,flies{c}.body);
              fg_pix = setdiff(fg_pix,flies{c}.wings);
              fg_pix = setdiff(fg_pix,flies{c}.legs);
              flies{c}.rem = fg_pix;
              % adjust roi cropped coordinates
              if adjust
                  [I,J] = ind2sub(roi_size, flies{c}.body);
                  flies{c}.body = sub2ind(im_size,I+shift(2),J+shift(1));
                  [I,J] = ind2sub(roi_size, flies{c}.wings);
                  flies{c}.wings = sub2ind(im_size,I+shift(2),J+shift(1));
                  [I,J] = ind2sub(roi_size, flies{c}.legs);
                  flies{c}.legs = sub2ind(im_size,I+shift(2),J+shift(1));
                  [I,J] = ind2sub(roi_size, flies{c}.rem);
                  flies{c}.rem = sub2ind(im_size,I+shift(2),J+shift(1));
              end
          end
          seg{f} = flies;
      end          
      clear frame_data
      % update waitbar
      steps = steps + 1;
      if do_use_display   
         abort = multiWaitbar(waitstr,steps/n_steps);
         if abort, return; end
      end       
  end   
  
  % AUTOMATIC ID CORRECTION
  try
      [trk,swaps] = track_auto_id(trk);  
  catch err
      disp(err)
      disp('Warning: Could not auto correct ids, classifier binaries may be missing for your OS.')
      swaps = [];
  end
  if size(swaps,1) > 0 && save_seg
      % udpate segmentation according to swaps
      for i=1:size(swaps,1)
        fly1 = swaps(i,1);
        fly2 = swaps(i,2);
        frame = swaps(i,3);
        for f=frame:numel(seg)
            tmp = seg{f}{fly1};
            seg{f}{fly1} = seg{f}{fly2};
            seg{f}{fly2} = tmp;
        end
      end      
  end
  % order flies based on their size
  areas = nanmean(trk.data(:,:,6),2);
  [~,sortids] = sort(areas,'ascend');
  trk.data = trk.data(sortids,:,:);
  if save_seg
      for f=options.startframe:n_frames
        seg{f} = seg{f}(sortids);
      end
  end
  map = zeros(size(sortids));
  map(sortids) = 1:numel(sortids);
  trk.flags(:,1:2) = map(trk.flags(:,1:2)); 
  % save files
  save(output_per_chamber_track_file_name,'trk', '-v7.3'); %save([f_res(1:end-10) '-swaps.mat'],'swaps');  
  if save_seg      
     save(output_segmentation_file_name, 'seg', '-v7.3') ; %save([f_res(1:end-10) '-seg.mat'],'seg','-v7.3'); 
  end    
  % delete temp chunk files
  for n=1:numel(atomic_track_file_name_from_chunk_index)
      f_trk_curr = atomic_track_file_name_from_chunk_index{n};
      delete(f_trk_curr);
  end          
  % close waitbar
  if do_use_display
    multiWaitbar(waitstr,'Close');
    drawnow
  end  
  % indicate that everything worked
  success = 1;
end
