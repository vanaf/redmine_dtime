
require 'redmine'

#require 'application'

class DtimeHooks  < Redmine::Hook::ViewListener

	render_on	:view_account_left_bottom,
			:partial => 'dtime/hooks/view_account_left_bottom'	



end
