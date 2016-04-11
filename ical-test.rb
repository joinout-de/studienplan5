require "icalendar"

cal = Icalendar::Calendar.new

cal.event do |e|
    e.dtstart = DateTime.civil(2016,4,10,7,0)
    e.dtend = DateTime.civil(2016,4,10,10,45)
    e.summary = "VERY VERY ery important meeting"
    e.description = "Now we need to decide something FINALLY"
    e.location = "Honululu" # No way this is spelled correctly.
end

file = File.open("test.ical", "a+")
file.puts cal.to_ical
file.close
