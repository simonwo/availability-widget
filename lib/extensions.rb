require 'vpim/icalendar'
require 'tzinfo'

# Icalendar doesn't handle timezones, so we'll have to do it.
module VeventExtensions
  def prop_timezone name
    prop = properties.find {|p| p.name == name }
    tzstring = prop.params.include?('TZID') ? prop.param('TZID').first : 'UTC'
    TZInfo::Timezone.get tzstring
  rescue
    nil
  end

  def dtstart
    timezone = prop_timezone('DTSTART')
    super.nil? ? nil : timezone.local_to_utc(super)
  end

  def dtend
    timezone = prop_timezone('DTEND') || prop_timezone('DTSTART')
    super.nil? ? nil : timezone.local_to_utc(super)
  end
end

Vpim::Icalendar::Vevent.prepend(VeventExtensions)