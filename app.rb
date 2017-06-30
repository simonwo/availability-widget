require 'sinatra/base'
require 'google/apis/people_v1'
require 'net/http'
require 'icalendar'
require 'chronic_duration'
People = Google::Apis::PeopleV1

class AvailabilityWidget < Sinatra::Application
  set :protection, except: :frame_options

  def initialize
    super
    @plus = People::PeopleServiceService.new
    @plus.key = ENV['GOOGLE_API_KEY']
  end

  def get_avatar google_user_id
    person = @plus.get_person "people/#{google_user_id}", person_fields: 'photos'
    person.photos.first.url
  end

  def get_next_meeting_info calendar_url
    calendar = retrieve_calendar calendar_url
    now = DateTime.now
    event = calendar.events.reject {|e| e.dtend < now }.sort_by(&:dtstart).first
    return event.dtstart, event.dtend, event.summary
  end

  def format_status dtstart, dtend, summary
    now = DateTime.now
    if dtstart.nil?
      "Free now."
    elsif dtstart < now && dtend > now
      seconds = (dtend - now)*24*60*60
      "#{summary} for #{ChronicDuration.output(seconds.to_i, units: 1)}."
    elsif dtstart > now
      seconds = (dtstart - now)*24*60*60
      "Free now. #{summary} in #{ChronicDuration.output(seconds.to_i, units: 1)}."
  end
  end

  def retrieve_calendar calendar_url
      calendars = Net::HTTP.get URI.parse calendar_url
      Icalendar::Calendar.parse(calendars).first
  end

  get '/:address/' do |address|
    image = get_avatar params['google']
    name = address.split('@').first.split('.').map(&:capitalize).join(' ')
    dtstart, dtend, summary = get_next_meeting_info "https://calendar.google.com/calendar/ical/#{address}/public/basic.ics"
    status = format_status dtstart, dtend, summary
    haml :widget, locals: {:avatar => image, :name => name, :status => status}
  end

  run! if app_file == $0
end