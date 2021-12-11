function fix_SetCreatedObjectBgColor( hObject, color )
% set the background color for a newly created GUI object
% JAB 6/23/12

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',color);
end
