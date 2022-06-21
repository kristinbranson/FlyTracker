function core_tracker_job_consolidate(output_track_file_name, ...
                                      output_segmentation_file_name, ...
                                      per_chamber_track_file_name_from_chamber_index, ...
                                      per_chamber_segmentation_file_name_from_chamber_index, ...
                                      options)
                                  
  % Join results of multiple chambers 
  n_chambers = numel(per_chamber_track_file_name_from_chamber_index);      
  save_seg = 0;  
  if isfield(options,'save_seg'), save_seg = options.save_seg; end

  % Blow out old outputs
  ensure_file_does_not_exist(output_track_file_name) ;
  if save_seg ,
      ensure_file_does_not_exist(output_segmentation_file_name) ;
  end
  
  % CONSOLIDATE TRACKS
  D = load(per_chamber_track_file_name_from_chamber_index{1});
  trk.names = D.trk.names;
  n_frames = size(D.trk.data,2);
  n_fields = size(D.trk.data,3);
  flies = zeros(1,n_chambers);
  all_data = cell(1,n_chambers);
  flags_c = cell(1,n_chambers);
  flies_in_chamber = cell(1,n_chambers);
  n_flags = 0;
  for i=1:n_chambers
      D = load(per_chamber_track_file_name_from_chamber_index{i});
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
  save(output_track_file_name,'trk');
  % delete previous files
  for i=1:n_chambers
      ensure_file_does_not_exist(per_chamber_track_file_name_from_chamber_index{i}) ;
  end          

  % CONSOLIDATE SEGMENTATION 
  if save_seg
    %output_segmentation_file_name = [output_track_file_name(1:end-10) '-seg.mat']; 
    try
        %segfile = [per_chamber_track_file_name_from_chamber_index{1}(1:end-10) '-seg.mat'];
        segfile = per_chamber_segmentation_file_name_from_chamber_index{1} ;
        D = load(segfile); 
        n_frames = numel(D.seg);
        seg = cell(n_frames,1);
        for i=1:n_chambers
            %segfile = [per_chamber_track_file_name_from_chamber_index{i}(1:end-10) '-seg.mat'];
            segfile = per_chamber_segmentation_file_name_from_chamber_index{i} ;
            D = load(segfile);
            for f=1:n_frames
                seg{f} = [seg{f} D.seg{f}];
            end
        end
        save(output_segmentation_file_name,'seg','-v7.3')

        % delete previous files
        for i=1:n_chambers
            %segfile = [per_chamber_track_file_name_from_chamber_index{i}(1:end-10) '-seg.mat'];
            segfile =  per_chamber_segmentation_file_name_from_chamber_index{i} ;
            ensure_file_does_not_exist(segfile) ;
        end
    catch
        disp('could not write segmentation file')
    end
  end  
end

