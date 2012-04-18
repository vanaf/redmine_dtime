
class DtimeMailer < Mailer
  helper :application
  helper :issues
  helper :custom_fields

  def notify_managers(overdueDateUsers, managers)
    recipients managers.collect {|u| u.mail} 
    subject l(:dtime_notify_managers_subject)
    body :dateUsers => overdueDateUsers,
         :managers => managers
    render_multipart('notify_managers', body)
  end

  def notify_user(overdueDates, user)
    recipients user.mail
    subject l(:dtime_notify_user_subject)
    body :dates => overdueDates
    render_multipart('notify_user', body)
  end


end

