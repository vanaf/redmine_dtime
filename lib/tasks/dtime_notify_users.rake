desc 'Notify users about overdue timesheets'

namespace :redmine do
  task :dtime_notify_users => :environment do
    cond = ARCondition.new
    cond << ['spent_on BETWEEN ? AND ?', Date.today-30, Date.today-1]

    activeUsers = User.active.find(:all)
    neededUsers = Array.new
    activeUsers.each do |u|
	if u.allowed_to_globally?(:log_time,{})
		neededUsers << u
	end
    end


    perDays = TimeEntry.find(:all,:select =>"user_id, spent_on, sum(hours) as sum_hours" ,:conditions => cond.conditions,:group => "user_id, spent_on")
    
    neededUsers.each do |u|
	curUser = perDays.find_all{|perDay| perDay.user_id == u.id}
	if !curUser.blank?
		overdueDates = Array.new
		for @date in (Date.today-30)..(Date.today-1)
			if @date.cwday<6
				uh = curUser.select{|curUserDate| curUserDate.spent_on == @date}.first
				if uh.blank? or uh.sum_hours.to_i < 2
					overdueDates |= [@date]
				end
			end
		end
		DtimeMailer.deliver_notify_user(overdueDates,u)
	end
    end
  end
end
