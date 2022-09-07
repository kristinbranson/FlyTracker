function [angle,l,x,y,ismissing] = FixWingNaNs(angle,l,i,medianlength,outtrx)

ismissing_angle = isnan(angle);
ismissing_l = isnan(l);

% fill with zeros
angle(ismissing_angle) = 0;

% interpolate
ispresent_l = ~ismissing_l ;
n_present_l = nnz(ispresent_l) ;
n = length(ispresent_l) ;
if n_present_l == 0
  l(:) = medianlength;
elseif n_present_l == 1,
  l1 = l(ispresent_l);
  l(:) = l1;
elseif n_present_l < n ,
  l(ismissing_l) = interp1(find(ispresent_l), l(ispresent_l), find(ismissing_l), 'linear', 'extrap') ;
else
  % do nothing
end

ismissing = ismissing_l | ismissing_angle;

x = outtrx.trx(i).x + l.*cos(outtrx.trx(i).theta + pi-angle);
y = outtrx.trx(i).y + l.*sin(outtrx.trx(i).theta + pi-angle);

end
