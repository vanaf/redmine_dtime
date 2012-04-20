ActionController::Routing::Routes.draw do |map|
map.connect '/dtime/show_week', :controller => 'dtime', :action => 'show_week'
map.connect '/dtime/edit', :controller => 'dtime', :action => 'edit'
map.connect '/dtime/update', :controller => 'dtime', :action => 'update'
map.connect '/dtime/deleterow', :controller => 'dtime', :action => 'deleterow'
map.connect '/dtime/getissues', :controller => 'dtime', :action => 'getissues'
map.connect '/dtime/getactivities', :controller => 'dtime', :action => 'getactivities'
map.connect '/dtime', :controller => 'dtime', :action => 'index'
end
