function SetErrorTypes(handles)
% set "next error type" menu values based on remaining suspicious sequences
% splintered from fixerrorsgui 6/23/12 JAB

isbirth = false; isdeath = false;
isswap = false; isjump = false;
isorientchange = false; isorientvelmismatch = false;
islargemajor = false;
for i = 1:length(handles.seqs),
  if ~isempty( strfindi(handles.seqs(i).type,'dummy') ),
    continue;
  end
  eval(sprintf('is%s = true;',handles.seqs(i).type));
end
s = {};
if isbirth,
  s{end+1} = 'Track Birth';
end
if isdeath
  s{end+1} = 'Track Death';
end
if isswap,
  s{end+1} = 'Match Cost Ambiguity';
end
if isjump,
  s{end+1} = 'Large Jump';
end
if isorientchange,
  s{end+1} = 'Large Change in Orientation';
end
if isorientvelmismatch,
  s{end+1} = 'Velocity & Orient. Mismatch';
end
if islargemajor,
 s{end+1} = 'Large Major Axis';
end
content = get(handles.nexterrortypemenu,'string');
v = get(handles.nexterrortypemenu,'value');
if v > length(content),
  set(handles.nexterrortypemenu,'value',length(content));
  v = length(content);
end
sel = content{v};
if isempty(s),
  set(handles.nexterrortypemenu,'string','No more errors','value',1);
  set(handles.correctbutton,'string','Finish');
else
  set(handles.nexterrortypemenu,'string',s);
  set(handles.correctbutton,'string','Correct');
  i = find(strcmpi(sel,s));
  if ~isempty(i),
    set(handles.nexterrortypemenu,'value',i);
  else
    if length(s) >= v,
      set(handles.nexterrortypemenu,'value',min(v,length(s)));
    end
  end
end
