require 'sinatra/base'
require 'google/apis/people_v1'
require 'net/http'
require 'vpim/icalendar'
require 'chronic_duration'
People = Google::Apis::PeopleV1

class AvailabilityWidget < Sinatra::Application
  set :protection, except: :frame_options

  ERROR_EMOJI = "&#9888;"
  DEFAULT_REFRESH_TIME = 300

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
    event = calendar.reject {|e| e.dtend.nil? || e.dtend < now }.sort_by(&:dtstart).reject {|e| attendee_declined? e, "mailto:#{address}"}.first
    return event
  end

  def attendee_declined? event, uri
    event.attendees.select {|a| a.uri == uri }.any? {|a| a.partstat == "DECLINED" }
  end

  def format_meeting event
    now = Time.now
    if event.nil?
      return "Free now.", DEFAULT_REFRESH_TIME
    elsif event.dtstart < now && event.dtend > now
      seconds = (event.dtend - now)
      return "#{event.summary} for #{ChronicDuration.output(seconds.to_i, units: 1)}.", [seconds, DEFAULT_REFRESH_TIME].min
    elsif event.dtstart > now
      seconds = (event.dtstart - now)
      return "Free now. #{event.summary} in #{ChronicDuration.output(seconds.to_i, units: 1)}.", [seconds, DEFAULT_REFRESH_TIME].min
    end
  end

  def retrieve_calendar calendar_url
      calendars = Net::HTTP.get URI.parse calendar_url
      Vpim::Icalendar.decode(calendars).first
  end

  def render_widget address, calendar_url, google_id
    image = get_avatar google_id
    name = address.split('@').first.split('.').map(&:capitalize).join(' ')
    status, refresh_time = begin
      format_meeting get_next_meeting_info address, calendar_url
    rescue
      ["#{ERROR_EMOJI} Set calendar to public (full or free/busy).", DEFAULT_REFRESH_TIME]
    end
    headers "Refresh" => refresh_time.to_s
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