function tracker_job_consolidate(f_res, f_res_list, options)
  % Join results of multiple chambers 
  n_chambers = numel(f_res_list);      
  save_seg = 0;  
  if isfield(options,'save_seg'), save_seg = options.save_seg; end
  
  % CONSOLIDATE TRACKS
  D = load(f_res_list{1});
  trk.names = D.trk.names;
  n_frames = size(D.trk.data,2);
  n_fields = size(D.trk.data,3);
  flies = zeros(1,n_chambers);
  all_data = cell(1,n_chambers);
  flags_c = cell(1,n_chambers);
  flies_in_chamber = cell(1,n_chambers);
  n_flags = 0;
  for i=1:n_chambers
      D = load(f_res_list{i});
      all_data{i} = D.trk.data;
      flags_c{i} = D.trk.flags;
      flies(i) = size(D.trk.data,1);
      n_flags = n_flags + size(flags_c{i},1);
  end
  n_flies = sum(flies);
  % combine data and store ids of flies in chambers
  trk.data = zeros(n_flies,n_frames,n_fields);                
  count = 0;
  for i=1:n_chambers
      for t=1:flies(i)
          count = count + 1;
          for f=1:n_fields
            trk.data(count,:,f) = all_data{i}(t,:,f);
          end
          flies_in_chamber{i} = [flies_in_chamber{i} count];
      end
  end
  trk.flies_in_chamber = flies_in_chamber; 
  % combine flags
  flags = zeros(n_flags,6);
  count = 0;
  for i=1:n_chambers
      c_count = size(flags_c{i},1);
      flags_c{i}(:,1:2) = flies_in_chamber{i}(flags_c{i}(:,1:2));
      flags(count+(1:c_count),:) = flags_c{i};
      count = count + c_count;
  end
  trk.flags = flags;
  % save tracks
  save(f_res,'trk');
  % delete previous files
  for i=1:n_chambers
      delete(f_res_list{i});
  end          

  % CONSOLIDATE SEGMENTATION 
  if save_seg
    f_res_seg = [f_res(1:end-10) '-seg.mat']; 
    try
        segfile = [f_res_list{1}(1:end-10) '-seg.mat'];
        D = load(segfile); 
        n_frames = numel(D.seg);
        seg = cell(n_frames,1);
        for i=1:n_chambers
            segfile = [f_res_list{i}(1:end-10) '-seg.mat'];
            D = load(segfile);
            for f=1:n_frames
                seg{f} = [seg{f} D.seg{f}];
            end
        end
        save(f_res_seg,'seg','-v7.3')

        % delete previous files
        for i=1:n_chambers
            segfile = [f_res_list{i}(1:end-10) '-seg.mat'];
            delete(segfile);
        end
    catch
        disp('could not write segmentation file')
    end
  end  
end

