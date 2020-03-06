movfiles = dir('/groups/branson/home/bransonk/behavioranalysis/code/SSRNN/SSRNN/Data/bowl/GMR_71G01_AE_01_TrpA_*/movie.ufmf');
for i = 1:numel(movfiles),
  
  [~,nframes(i),fid] = get_readframe_fcn(fullfile(movfiles(i).folder,movfiles(i).name));
  fclose(fid);
  
end

%% 

n = numel(pd0.data{7});
for i = 1:n,
  
  if i+n-1 > numel(pd.data{7}),
    break;
  end
  err(i) = nanmean(abs(pd.data{7}(i:i+n-1)-pd0.data{7}));
  
end

%%

moviei = 1;
fly = 7;

off = 2564;
nplot = 1000;
for fni = 1:numel(perframefns),
%perframefn = 'velmag_ctr';
perframefn = perframefns{fni};
pd0 = load(fullfile(expdir0,dataloc_params.perframedir,[perframefn,'.mat']));
pfd0 = pd0.data{fly};
figure(123);
clf;
plot(pfd0(1:nplot),'-');
hold on;
[~,n] = fileparts(expdir0);
legs = {['real ',n]};

pd = load(fullfile(simexpdirs{moviei},dataloc_params.perframedir,[perframefn,'.mat']));
pfd = pd.data{fly}(off:end);
plot(pfd(1:nplot),'-');
title(perframefn);
input('');
end

%%

moviei = 1;
td0 = load(fullfile(expdir0,'registered_trx.mat'));
td = load(fullfile(simexpdirs{moviei},'registered_trx.mat'));

fly = 7;

figure(124);
clf;
plot(td0.trx(fly).theta,'x');
hold on;
plot(-td.trx(fly).theta(off:end),'.');

%%

realdata = false;
if realdata,
  trx = td0.trx;
  off = td0.trx(fly).firstframe-1;
else
  trx = td.trx;
  off = 0;
end

t = 1;
clf;
readframe = get_readframe_fcn(fullfile(expdir0,'movie.ufmf'));  
him = imagesc(readframe(t+off));
colormap gray;
axis image;
hold on;
if realdata,
  hfly = drawflyo(trx(fly).x(t),trx(fly).y(t),trx(fly).theta(t),trx(fly).a(t),trx(fly).b(t));
else
  hfly = drawflyo(trx(fly).x(t)+1,trx(fly).y(t)+1,-trx(fly).theta(t),trx(fly).a(t)/4,trx(fly).b(t)/4);
end
hold on;
htrx = plot(nan,nan,'-');
hax = gca;
set(hax,'XLim',trx(fly).x(t)+[-100,100],...
  'YLim',trx(fly).y(t)+[-100,100]);

for t = 1:10000,
  set(him,'CData',readframe(t+off));
  if realdata,
    updatefly(hfly,trx(fly).x(t),trx(fly).y(t),trx(fly).theta(t),trx(fly).a(t),trx(fly).b(t));
  else
    updatefly(hfly,trx(fly).x(t)+1,trx(fly).y(t)+1,-trx(fly).theta(t),trx(fly).a(t)/4,trx(fly).b(t)/4);
  end
  set(hax,'XLim',trx(fly).x(t)+[-100,100],...
    'YLim',trx(fly).y(t)+[-100,100]);
  drawnow;
end

%% 

for fly = 1:20,
  clf;
  plot(td0.trx(fly).x,td.trx(fly).x(off:off+numel(td0.trx(fly).x)-1),'.');
  input(num2str(fly));
end
