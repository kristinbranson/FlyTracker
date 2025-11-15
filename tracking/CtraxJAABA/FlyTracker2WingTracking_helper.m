function outtrx = FlyTracker2WingTracking_helper(ftfile,trxfile,perframedir,outtrxfile,perframe_params,arena,newid2oldid,annfile)

if ischar(ftfile),
  ftd = load(ftfile);
else
  ftd = ftfile;
end
if ischar(trxfile),
  intrx = load(trxfile);
else
  intrx = trxfile;
end
outtrx = intrx;
nflies = numel(intrx.trx);

if ~exist('newid2oldid','var') || isempty(newid2oldid),
  newid2oldid = 1:nflies;
end
if ~exist('annfile','var'),
  annfile = [];
end

assert(nflies == numel(newid2oldid) && max(newid2oldid) <= numel(ftd.trk.data));


[outtrx.trx.arena] = deal(arena);

fidx = struct;
fidx.wing_anglel = find(strcmp(ftd.trk.names,'wing l ang'));
fidx.wing_angler = find(strcmp(ftd.trk.names,'wing r ang'));
fidx.wing_lengthl = find(strcmp(ftd.trk.names,'wing l len'));
fidx.wing_lengthr = find(strcmp(ftd.trk.names,'wing r len'));

nwingsdetected = cell(1,nflies);
% remove nans

alllengths = ftd.trk.data(:,:,[fidx.wing_lengthl,fidx.wing_lengthr]);
medianlength = nanmedian(alllengths(:));

for i = 1:nflies,
  
  id = newid2oldid(i);
  
  [ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_anglel),...
    ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_lengthl),...
    outtrx.trx(i).xwingl,outtrx.trx(i).ywingl,ismissingl] = ...
    FixWingNaNs(ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_anglel),...
    ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_lengthl),i,medianlength,outtrx);
  
  [ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_angler),...
    ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_lengthr),...
    outtrx.trx(i).xwingr,outtrx.trx(i).ywingr,ismissingr] = ...
    FixWingNaNs(ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_angler),...
    ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_lengthr),i,medianlength,outtrx);
  nwingsdetected{i} = double(~ismissingl) + double(~ismissingr);

end

% minus sign is important here!
for i = 1:numel(outtrx.trx),
  id = newid2oldid(i);
  outtrx.trx(i).wing_anglel = -ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_anglel);
  outtrx.trx(i).wing_angler = -ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_angler);
end


if ~isempty(annfile),
  [outtrx.trx.annname] = deal(annfile);
end

if exist(outtrxfile,'file'),
  delete(outtrxfile);
end
save(outtrxfile,'-v7.3','-struct','outtrx');

if ~exist(perframedir,'dir'),
  mkdir(perframedir);
end

% wing_anglel <- -'wing l ang'
fn = 'wing_anglel';
data = cell(1,nflies);
for i = 1:nflies,
  id = newid2oldid(i);
  data{i} = -ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(fn));
end
units.num = {'rad'};
units.den = cell(1,0);
filecurr = fullfile(perframedir,[fn,'.mat']);
if exist(filecurr,'file'),
  delete(filecurr);
end
save(fullfile(perframedir,[fn,'.mat']),'data','units');

% wing_angler <- -'wing r ang'
fn = 'wing_angler';
data = cell(1,nflies);
for i = 1:nflies,
  id = newid2oldid(i);
  data{i} = -ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(fn));
end
units.num = {'rad'};
units.den = cell(1,0);
filecurr = fullfile(perframedir,[fn,'.mat']);
if exist(filecurr,'file'),
  delete(filecurr);
end
save(filecurr,'data','units');

% fakectrax: wing_arear <- 'wing r len'
% ow: wing_lengthr <- wing r len
ffn = 'wing_lengthr';
if perframe_params.fakectrax,
  cfn = 'wing_arear';
  units.num = {'px^2'};
  units.den = cell(1,0);
  notes = sprintf('This is actually %s, units are actually mm',ffn);
else
  cfn = ffn;
  units.num = {'px'};
  units.den = cell(1,0);
  notes = '';
end  
data = cell(1,nflies);
for i = 1:nflies,
  id = newid2oldid(i);
  data{i} = ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(ffn));
end
filecurr = fullfile(perframedir,[cfn,'.mat']);
if exist(filecurr,'file'),
  delete(filecurr);
end
save(filecurr,'data','units','notes');

% fakectrax: wing_areal <- 'wing l len'
% ow: wing_lengthl <- wing l len
ffn = 'wing_lengthl';
if perframe_params.fakectrax,
  cfn = 'wing_areal';
  units.num = {'px^2'};
  units.den = cell(1,0);
  notes = sprintf('This is actually %s, units are actually mm',ffn);
else
  cfn = ffn;
  units.num = {'px'};
  units.den = cell(1,0);
  notes = '';
end  
data = cell(1,nflies);
for i = 1:nflies,
  id = newid2oldid(i);
  data{i} = ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.(ffn));
end
filecurr = fullfile(perframedir,[cfn,'.mat']);
if exist(filecurr,'file'),
  delete(filecurr);
end
save(fullfile(perframedir,[cfn,'.mat']),'data','units','notes');

% wing_trough_angle <- -( 'wing l ang' + 'wing r ang' ) / 2
cfn = 'wing_trough_angle';
data = cell(1,nflies);
for i = 1:nflies,
  id = newid2oldid(i);
  data{i} = -.5*modrange(ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_anglel)+...
    ftd.trk.data(id,outtrx.trx(i).firstframe:outtrx.trx(i).endframe,fidx.wing_angler),-pi,pi);
end
units.num = {'rad'};
units.den = cell(1,0);
filecurr = fullfile(perframedir,[cfn,'.mat']);
if exist(filecurr,'file'),
  delete(filecurr);
end
save(fullfile(perframedir,[cfn,'.mat']),'data','units');

% n wings detected
cfn = 'nwingsdetected';
data = nwingsdetected;
% data = cell(1,nflies);
% for i = 1:nflies,
%   data{i} = 2+zeros(1,outtrx.trx(i).nframes);
% end
units.num = {'unit'};
units.den = cell(1,0);
filecurr = fullfile(perframedir,[cfn,'.mat']);
if exist(filecurr,'file'),
  delete(filecurr);
end
save(fullfile(perframedir,[cfn,'.mat']),'data','units');

end
