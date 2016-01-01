#!/usr/bin/env ruby

# Install these gems first
require 'rubygems'
require 'multi_json'
require 'tracker_api'
require 'mail'

api_token  = 'your-pivotal-tracker-api-token'
from_email = 'your@email.com'
to_emails  = %w(lead@email.com manager@email.com cto@email.com)

begin
  client = TrackerApi::Client.new(token: api_token)
  my_id  = client.me.id

  project = client.project('projectID')

  in_progress_stories = []
  finished_stories    = []

  today_task_list     = ""
  yesterday_task_list = ""

  in_progress_stories |= project.stories(filter: "owner:#{my_id} state:started")

  finished_stories |= project.stories(filter: "owner:#{my_id} state:finished updated:yesterday")

  if finished_stories.empty?
    yesterday_task_list << "\t1) Nothing to update."
  else
    finished_stories.flatten.each_with_index do |story, i|
      yesterday_task_list << "\t#{i+1}) #{story.name}  -  [ #{story.url} ]\n"
    end
  end

  if in_progress_stories.empty?
    today_task_list << "\t1) Nothing to update. Will pickup something from Backlog."
  else
    in_progress_stories.flatten.each_with_index do |story, i|
      today_task_list << "\t#{i+1}) #{story.name}  -  [ #{story.url} ]\n"
    end
  end
  today_task_list << "\n"

  email_body = <<-EMAIL_BODY
  Hey All,\n

  Below is my update -\n

  YESTERDAY:\n
  #{yesterday_task_list}

  TODAY:\n
  #{today_task_list}

  Thanks,

  Your Name Dude!
  EMAIL_BODY

  options = { address:              'smtp.gmail.com',
              port:                 587,
              domain:               'localhost',
              user_name:            from_email,
              password:             'password',
              authentication:       'plain',
              enable_starttls_auto: true  }

  Mail.defaults do
    delivery_method :smtp, options
  end

  Mail.deliver do
    from     from_email
    to       to_emails.join(',')
    subject  'Daily Scrum Update'
    body     email_body
  end
rescue TrackerApi::Error => ex
end

