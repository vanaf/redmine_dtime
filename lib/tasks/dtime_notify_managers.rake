desc 'Notify managers about overdue timesheets'

namespace :redmine do
  task :dtime_notify_managers => :environment do
    cond = ARCondition.new
    cond << ['spent_on BETWEEN ? AND ?', Date.today-30, Date.today-1]

    activeUsers = User.active.find(:all)
    neededUsers = Array.new
    activeUsers.each do |u|
	if u.allowed_to_globally?(:log_time,{})
		neededUsers << u
	end
    end

    overdueDateUsers =  Hash.new {|h,k| h[k]=[]}
    overdueUsers = Array.new

    perDays = TimeEntry.find(:all,:select =>"user_id, spent_on, sum(hours) as sum_hours" ,:conditions => cond.conditions,:group => "user_id, spent_on")
    for @date in (Date.today-30)..(Date.today-1)
	if @date.cwday<6
		curDate = perDays.find_all{|perDay| perDay.spent_on == @date}
		if curDate.blank?
			overdueDateUsers[@date] = neededUsers
			overdueUsers = neededUsers
		else
#			neededUsers = neededUsers.to_set
			dateOverdueUsers = Array.new
			neededUsers.each do |u|
				uh = curDate.select{|curDateUser| curDateUser.user_id == u.id}.first
				if uh.blank? or uh.sum_hours.to_i < 2
					dateOverdueUsers |= [u]
					overdueUsers |= [u]
				end
			end
			overdueDateUsers[@date] = dateOverdueUsers
		end
	end
    end

    if !overdueDateUsers.blank?			
    	managers = Array.new
    	neededProjects = Array.new
    	overdueUsers.each do |u|
		u.memberships.each do |m|
			neededProjects |= [m.project]
		end
    	end
    	neededProjects = neededProjects.to_set
    	neededProjects.each do |p|
		users_by_role = p.users_by_role
		users_by_role.keys.each do |role|
			if role.allowed_to?(:dtime_receive_manager_notifications)
				managers |= users_by_role[role]
			end			
		end
    	end
    	DtimeMailer.deliver_notify_managers(overdueDateUsers,managers)
    end
  end
end
