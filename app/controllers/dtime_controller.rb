class DtimeController < ApplicationController
unloadable

before_filter :require_login
#before_filter :check_perm_and_redirect, :only => [:edit, :update, :destroy]
before_filter :check_rw_perm_and_redirect, :only => [:edit, :update, :destroy]


  def index
    retrieve_date_range
	@from = getMonday(@from)
	@to = getSunday(@to)
	
    respond_to do |format|
      format.html {
        # Paginate results
		user_id = params[:user_id]
		set_user_projects(User.current)
		ids = nil		
		if user_id.blank?
			ids = User.current.id.to_s
		elsif user_id.to_i == 0
			#all users
			@user_ids.values.each_with_index do|id, i|
				if i == 0
					ids =  id.to_s
				else
					ids +=  ',' + id.to_s
				end
			end		
			ids = User.current.id.to_s if ids.nil?
		else
			ids = user_id
		end
		# mysql - the weekday index for date (0 = Monday, 1 = Tuesday, … 6 = Sunday)
		sqlStr = "select user_id, monday as spent_on, hours from " +
			" (select adddate(t.spent_on,weekday(t.spent_on)*-1) as monday, "
		
		# postgre doesn't have the weekday function
		# The day of the week (0 - 6; Sunday is 0)
		if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
			sqlStr = "select user_id, monday as spent_on, hours from " +
				" (select case when cast(extract(dow from t.spent_on) as integer) = 0 then t.spent_on - 6" +
				" else t.spent_on - (cast(extract(dow from t.spent_on) as integer) - 1) end as monday, "
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLite'
			sqlStr = "select user_id, monday as spent_on, hours from " +
				" (select date(spent_on, '-' || strftime('%w', spent_on, '-1 days') || ' days') as monday, "
		end
		sqlStr += " t.user_id, sum(t.hours) as hours from time_entries t, users u" +
			" where u.id = t.user_id and u.id in (" + 
			ids +") and t.spent_on between '" + 
			@from.to_s() + "' and '" + @to.to_s() + "' group by monday, user_id order by monday desc, user_id) as v1"

		 
		result = TimeEntry.find_by_sql("select count(*) as id from (" + sqlStr + ") as v2")
		@entry_count = result[0].id
        @entry_pages = Paginator.new self, @entry_count, per_page_option, params['page']
			
		@entries = TimeEntry.find_by_sql(sqlStr + 
			" LIMIT " + @entry_pages.items_per_page.to_s +
			" OFFSET " + @entry_pages.current.offset.to_s)

        #@total_hours = TimeEntry.visible.sum(:hours, :include => [:user], :conditions => cond.conditions).to_f
		result = TimeEntry.find_by_sql("select sum(hours) as hours from (" + sqlStr + ") as v2")
		@total_hours = result[0].hours
        render :layout => !request.xhr?
      }
    end

  end

  def show_week
        respond_to do |format|
                format.html {
                        @date = Date.today
                        if !params[:date].blank?
                                @date = params[:date].to_s.to_date
                        end
                        @mon = getMonday(@date)
			@all_users = User.find(:all,:order => 'lastname, firstname')
			@user_id = User.current.id
			if !params[:user_id].blank?
                        	@user_id = params[:user_id]
			end
                        cond = getCondition(@mon, @user_id)
                        @entries = TimeEntry.find(:all, :include => [:project, :issue, :activity] , :conditions => cond.conditions,
                                :order => 'project_id, issue_id, activity_id, spent_on')
                        @total_hours = 0
                        @total_hours =  @entries.sum(&:hours) if !@entries.blank?
                        if @entries.blank? && !params[:prev_template].blank?
                                @prev_entries = prevTemplate(user_id)
                                @prev_template = true
                        end
			@user = User.find(@user_id)
                        render :layout => !request.xhr?
                }
                format.api  {
                }
        end
  end


  def edit
	respond_to do |format|
		format.html {
			@prev_template = false
			@date = Date.today
			if !params[:date].blank?
				@date = params[:date].to_s.to_date
			end
			logger.info @date

			@entries = TimeEntry.find_all_by_spent_on_and_user_id(@date,User.current.id,:order => 'project_id, issue_id, activity_id, spent_on')
			@total_hours = 0
			@total_hours =  @entries.sum(&:hours) if !@entries.blank?
			if @entries.blank? && !params[:prev_template].blank?
				@prev_entries = prevTemplate(user_id)
				@prev_template = true
			end
			render :layout => !request.xhr?
		} 
		format.api  {
		}
	end
  end

  # called when save is clicked on the page
  def update
  	respond_to do |format|
		format.html {
			gatherEntries
			errorMsg = nil
			TimeEntry.transaction do
				begin
				errorMsg = l(:error_dtime_save_nothing) if @entries.blank?
				@entries.each do |entry|
						if entry.hours.blank?
							# delete the time_entry
							# if the hours is empty but id is valid
							# entry.destroy() unless ids[i].blank?
							if !entry.id.blank?
								if !entry.destroy()
									errorMsg = entry.errors.full_messages.join('\n')
									break
								end
							end
						else
							#if id is there it should be update otherwise create
							if !entry.save()
								errorMsg = entry.errors.full_messages.join('\n')
								break
							end					
						end
					end
				rescue Exception => e
					errorMsg = e.message
				end
				if errorMsg.nil?
					flash[:notice] = l(:notice_successful_update)
#					direct_back_or_default :action => 'index'
					render_edit
				else
					flash[:error] = l(:error_dtime_save_failed, errorMsg)
					render_edit
					raise ActiveRecord::Rollback
				end
			end
		} 
		format.api  {
		}
	end  
  end
	
	def deleterow
		if check_permission
			ids = params['ids']
			TimeEntry.delete(ids)	
			respond_to do |format|
				format.text  { 
					render :text => 'OK' 
				}
			end
		else
			respond_to do |format|
				format.text  { 
					render :text => 'FAILED' 
				}
			end
		end
	end

	def destroy	
		respond_to do |format|
			format.html {
				@mon = params[:mon].to_s.to_date
				cond = getCondition(@mon, params[:user_id])
				TimeEntry.delete_all(cond.conditions)
				flash[:notice] = l(:notice_successful_delete)
				redirect_back_or_default :action => 'index'
			} 
			format.api  {
			}
		end
	end
	
	def new
		set_user_projects
		# get the monday for current week
		@mon = getMonday(Date.today)
		render :action => 'new'
	end
	
	
	
  def getissues
	@date = params[:date].to_s.to_date
	if params['closed_issue_ind'].blank?
		issues = Issue.find_all_by_project_id(params[:project_id] || params[:project_ids],
		:conditions => ["#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.updated_on >= ?", false, @date],
		:include => :status, :order => 'project_id')
	else
		issues = Issue.find_all_by_project_id(params[:project_id] || params[:project_ids], :order => 'project_id')
	end
	
	user = User.find(params[:user_id])
	
	issStr =""
	issues.each do |issue|
		issStr << issue.project_id.to_s() + ',' + issue.id.to_s() + ',' + 
				issue.subject + "\n" if issue.visible?(user)
	end
	respond_to do |format|
		format.text  { render :text => issStr }
	end
  end
  
	def getactivities
		project = Project.find(params[:project_id])
		actStr =""
		project.activities.each do |a|
			actStr << a.id.to_s() + ',' + a.name + "\n"
		end
	
		respond_to do |format|
			format.text  { render :text => actStr }
		end
	end
	
private
	def getCondition(mon, user_id)
    cond = ARCondition.new	
	cond << ['spent_on BETWEEN ? AND ? AND user_id = ?', mon, mon + 6, user_id]
	end

#        def getDateCondition(date, user_id)
#    cond = ARCondition.new
#        cond << ['spent_on BETWEEN ? AND ? AND user_id = ?', date-100, date+200, user_id]
#        end

	
	#change the date to a monday
	def getMonday(date)
		unless date.nil?
			#the day of calendar week (1-7, Monday is 1)
			day1_diff = date.cwday%7 - 1
			#date -= day1_diff if day1_diff != 0
			date -= day1_diff == -1 ? 6 : day1_diff
		end
		date
	end

	#change the date to a sunday
	def getSunday(date)
		unless date.nil?
			day7_diff = 7 - date.cwday%7
			date += day7_diff == 7 ? 0 : day7_diff
		end
		date
	end
	
	def prevTemplate(user_id)
		# the weekday index for date (0 = Monday, 1 = Tuesday, … 6 = Sunday)
		sqlStr = "select max(spent_on) as max_spent_on from time_entries" +
			" where user_id = " + user_id
		 
		result = TimeEntry.find_by_sql(sqlStr)
		prev_entries = nil
		max_spent_on = result[0].max_spent_on
		unless max_spent_on.blank?
			start = getMonday(max_spent_on.to_date)
			cond = getCondition(start, user_id)
			prev_entries = TimeEntry.find(:all, :conditions => cond.conditions,
					:order => 'project_id, issue_id, activity_id, spent_on')
		end
		prev_entries

	end

	
  def gatherEntries
		entryHash = params[:time_entry]
		@entries ||= Array.new
		@date = params[:date].to_s.to_date unless params[:date].blank?

		entrylookupHash = Hash.new
		unless entryHash.nil?
			entryHash.each_with_index do |entry, i|
				unless entry['project_id'].blank?
					hours = params['hours' + (i+1).to_s()]
					ids = params['ids' + (i+1).to_s()]
					hours.each_with_index do |hour, i|
						if !ids[i].blank? || !hour.blank?
							timeEntry = nil
							uniqueKey = entry['project_id']+ 
								(entry['issue_id'].blank? ? '' : entry['issue_id'])+
								(entry['activity_id'].blank? ? '' : entry['activity_id'])+ 
								@date.to_s
							if  entrylookupHash.key?(uniqueKey) && ids[i].blank?
								# For new entries, if the entry is already there, add the hours to it
								timeEntry = entrylookupHash[uniqueKey]
								timeEntry.hours += hour.to_f
							else
								if ids[i].blank?
									timeEntry = TimeEntry.new
								else
									# find it from the db so it can be updated
									timeEntry = TimeEntry.find(ids[i])
								end
								entrylookupHash[uniqueKey] = timeEntry
								
								timeEntry.attributes = entry
								# since project_id and user_id is protected
								timeEntry.project_id = entry['project_id']
								timeEntry.user_id = params[:user_id]
								timeEntry.spent_on = @date
								if hour.blank?
									timeEntry.hours = nil
								else
									timeEntry.hours = hour.to_f
								end
							end							
							# add the entries to the array, so it can be used 
							# on the edit page if an error occurs
							@entries << timeEntry				
						end				
					end
				end
			end
		end
  end

	def render_edit
		set_user_projects(User.current)
		render :action => 'edit', :user_id => params[:user_id], :mon => @mon
	end
	
  def check_perm_and_redirect
    unless check_permission
      render_403
      return false
    end
  end

  def check_rw_perm_and_redirect
    unless check_rw_permission
      render_403
      return false
    end
  end

  def check_permission
	set_user_projects(User.current)
    return @user_ids.value?(params[:user_id].to_i)
  end

  def check_rw_permission
        set_user_projects(User.current)
    return @user_ids.value?(User.current.id)
  end

  
  # Retrieves the date range based on predefined ranges or specific from/to param dates
  def retrieve_date_range
    @free_period = false
    @from, @to = nil, nil

    if params[:period_type] == '1' || (params[:period_type].nil? && !params[:period].nil?)
      case params[:period].to_s
      when 'today'
        @from = @to = Date.today
      when 'yesterday'
        @from = @to = Date.today - 1
      when 'current_week'
        @from = Date.today - (Date.today.cwday - 1)%7
        @to = @from + 6
      when 'last_week'
        @from = Date.today - 7 - (Date.today.cwday - 1)%7
        @to = @from + 6
      when '7_days'
        @from = Date.today - 7
        @to = Date.today
      when 'current_month'
        @from = Date.civil(Date.today.year, Date.today.month, 1)
        @to = (@from >> 1) - 1
      when 'last_month'
        @from = Date.civil(Date.today.year, Date.today.month, 1) << 1
        @to = (@from >> 1) - 1
      when '30_days'
        @from = Date.today - 30
        @to = Date.today
      when 'current_year'
        @from = Date.civil(Date.today.year, 1, 1)
        @to = Date.civil(Date.today.year, 12, 31)
      end
    elsif params[:period_type] == '2' || (params[:period_type].nil? && (!params[:from].nil? || !params[:to].nil?))
      begin; @from = params[:from].to_s.to_date unless params[:from].blank?; rescue; end
      begin; @to = params[:to].to_s.to_date unless params[:to].blank?; rescue; end
      @free_period = true
    else
      # default
    end
    
    @from, @to = @to, @from if @from && @to && @from > @to
    @from ||= (TimeEntry.earilest_date_for_project(@project) || Date.today)
    @to   ||= (TimeEntry.latest_date_for_project(@project) || Date.today)
  end  

	def set_user_projects(user)
		@projects = Array.new
		proj_members = Array.new
		@user_ids = Hash.new
		if !user.blank?
			@user ||= user
			@user_ids[@user.login] = @user.id if User.current.id == @user.id
		end
		allProjects = Project.find(:all, :order => 'name')
		allProjects.each do |p|
			#get the list of allowable projects.
			if !@user.nil? && @user.allowed_to?(:log_time, p)
				@projects << p
			end
			# if the user can manage other isers then add them in
			if User.current.allowed_to?(:manage_members, p)
				p.members.each do |m|			
					@user_ids[m.user.login] = m.user.id unless @user_ids.key?(m.user.login)
				end
			end
			@user_ids[User.current.login] = User.current.id if @user_ids.empty?
		end
		@sorted_user_ids = @user_ids.sort_by{|login, id| login}
	end

end
