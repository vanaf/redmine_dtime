require 'redmine'

Redmine::Plugin.register :redmine_dtime do
  name 'Dayly Timesheet'
  author 'Ivan Afonichev'
  description 'This is a plugin for entering dayly timesheet'
  version '0.0.1'
  url 'http://www.redmine.org/plugins/d-time'
  author_url 'http://opensoftdev.ru'
  menu :top_menu, :dTime, { :controller => 'dtime', :action => 'index' }, :caption => 'D-Time', :if => Proc.new { User.current.logged? }
  menu :account_menu, :dTimeEditTS, { :controller => 'dtime', :action => 'edit' }, :caption => :dtime_edit_ts_menu_label, :after => :my_account, :if => Proc.new { User.current.logged? }
  
end
