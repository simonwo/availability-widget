require 'sinatra/base'
require 'google/apis/people_v1'
require 'net/http'
require 'vpim/icalendar'
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
  rescue
    ''
  end

  def get_next_meeting_info address, calendar_url
    calendar = retrieve_calendar calendar_url
    now = Time.now
    event = calendar.reject {|e| e.dtend < now }.sort_by(&:dtstart).reject {|e| attendee_declined? e, "mailto:#{address}"}.first
    return event
  end

  def attendee_declined? event, uri
    event.attendees.select {|a| a.uri == uri }.any? {|a| a.partstat == "DECLINED" }
  end

  def format_status event
    now = Time.now
    if event.nil?
      "Free now."
    elsif event.dtstart < now && event.dtend > now
      seconds = (event.dtend - now)
      "#{summary} for #{ChronicDuration.output(seconds.to_i, units: 1)}."
    elsif event.dtstart > now
      seconds = (event.dtstart - now)
      "Free now. #{summary} in #{ChronicDuration.output(seconds.to_i, units: 1)}."
    end
  end

  def retrieve_calendar calendar_url
      calendars = Net::HTTP.get URI.parse calendar_url
      Vpim::Icalendar.decode(calendars).first
  end

  def render_widget address, calendar_url, google_id
    headers "Refresh" => "120"
    image = get_avatar google_id
    name = address.split('@').first.split('.').map(&:capitalize).join(' ')
    status = format_status get_next_meeting_info address, calendar_url
    haml :widget, locals: {:avatar => image, :name => name, :status => status}
  end

  get '/:address/' do |address|
    render_widget address, "https://calendar.google.com/calendar/ical/#{address}/public/basic.ics", params['google']
  end

  get '/:address/:key/' do |address, key|
    render_widget address, "https://calendar.google.com/calendar/ical/#{address}/#{key}/basic.ics", params['google']
  end

  run! if app_file == $0
end