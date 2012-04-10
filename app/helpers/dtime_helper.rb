module DtimeHelper
 

def options_for_period_select(value)
    options_for_select([[l(:label_all_time), 'all'],
						[l(:label_this_week), 'current_week'],
                        [l(:label_last_week), 'last_week'],
                        [l(:label_this_month), 'current_month'],
                        [l(:label_last_month), 'last_month'],
                        [l(:label_this_year), 'current_year']],
                        value)
  end

end
