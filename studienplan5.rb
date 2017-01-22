#!/usr/bin/env ruby
# A utility to convert HTMLed-XLS Studienpläne into iCal.
# Copyright (C) 2016 Christoph criztovyl Schulz
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

##########
# README #
##########
#
# Some advices before you read my code.
#
#  -- Nothing so far --
##########

require "logger"
$logger = Logger.new(STDERR)
$logger.level= Logger::INFO

require "nokogiri"
require "date"
require "set"
require "icalendar"
require "icalendar/tzinfo"
require "json/add/struct"
require "optparse"
require "fileutils"
require "tzinfo"
require "yaml"

require_relative "util"; include StudienplanUtil
require_relative "structs"
require_relative "extractor_semesterplan"
require_relative "extractor_ausbildungsplan"

# Default values for options
ical_dir = "ical"
data_file = "data.json"
classes_file = "classes.json"
extr_config_file = "extr_config.yml"

# Command line opts
$options = {
    extr_cfg: true,
    all_ics: false,
}

# Data from extractors
data = Plan.new "Studienplan5"

OptionParser.new do |opts|

    opts.banner = "Usage: %s [options]" % $0
    opts.separator ""
    opts.separator "Extractors:"
    opts.separator "  --semplan file"
    opts.separator "  --ausbplan file"
    opts.separator "For usage see below."
    opts.separator ""

    opts.on("-c", "--calendar", "Generate iCalendar files to \"ical\" directory. (Change with --calendar-dir)") do |c|
        $options[:ical] = c
    end

    opts.on("-j", "--json", "Generate JSON data file (data.json).") do |j|
        $options[:json] = j
    end

    opts.on("-d", "--classes", "Generate JSON classes structure (classes.json).") do |j|
        $options[:classes] = j
    end

    opts.on("-o", "--output NAME", "Specify output target, if ends with slash, will be output directory. If not, will be name of calendar dir and prefix for JSON files.") do |o|
        $options[:output] = o
    end

    opts.on("-k", "--disable-json-object-keys", "Stringify keys that are not strings.") do |jok|
        $options[:no_jok] = jok
    end

    opts.on("-p", "--json-pretty", "Write pretty JSON data.") do |jp|
        $options[:json_pretty] = jp
    end

    opts.on("-n", "--calendar-dir NAME", "Name for the diretory containing the iCal files. Program exits status 5 if -o/--output is specified and not a directory.") do |cal_dir|
        $options[:cal_dir] = cal_dir
    end

    opts.on("-u", "--disable-unified", "Do not create files that contain all parent events recursively.") do |u|
        $options[:no_unified] = u
    end

    opts.on("-a", "--disable-apache-config", "Do not export .htaccess and other Apache-specific customizations.") do |no_apache|
        $options[:no_apache] = no_apache
    end

    opts.on("-s", "--simulate", "Simulate, do not write files or create directories.") do |simulate|
        $options[:simulate] = simulate
    end

    opts.on("-q", "--quiet", "Do not print data.") do |quiet|
        $options[:quiet] = quiet
    end

    opts.on("-l", "--level [LEVEL]", {fatal: Logger::FATAL, error: Logger::ERROR, warn: Logger::WARN, info: Logger::INFO, debug: Logger::DEBUG}, "Log level") do |level|
        $logger.level = level
    end

    opts.on("--disable-load-events", "Disable loading of data.json in -w/--web page") do |no_events|
        $options[:no_events] = true
    end

    opts.on("--[no-]extr-config", "Do (not) read extr_helper.yml. Default: Read.") do |extr_cfg|
        $options[:extr_cfg] = extr_cfg
    end

    opts.on("--[no-]all-ics", "Do (not) write an ICS file containing all events. Default: Do not write.") do |all_ics|
        $options[:all_ics] = all_ics;
    end

    # Extractors
    # TODO: Move extr_helper-code here (studienplan5) or to extractors. Maybe management here, converting in extractors.
    #

    opts.on("--semplan FILE", "Extract data from a HTMLed XLS Studienplan. Use extr_helper for XLS -> HTML.") do |semplan|
        File.open(semplan, "rb") do |f|
            data = data.merge SemesterplanExtractor.new(f).extract
        end
    end

    opts.on("--ausbplan FILE", "Extract data from a JSONed PDF Ausbildungsplan. Use extr_helper for PDF -> JSON.") do |semplan|
        File.open(semplan, "rb") do |f|
            data = data.merge Ausbildungsplan.new(f).extract
        end
    end

    # Help
    #

    opts.on("-h", "--help", "Print this help.") do |h|
        puts opts
        exit
    end

end.parse!

if $options[:cal_dir]
    ical_dir = $options[:cal_dir]
end

icals_path = nil
data_path=nil
classes_path = nil

outp = $options[:output]
if outp
    if outp.end_with?(?/)
        icals_path = outp + ical_dir
        data_path = outp + data_file
        classes_path = outp + classes_file

        unless Dir.exists? outp
            Dir.mkdir(outp)
            $logger.info "Would create dir #{outp}." if $options[:simulate]
        end

    else
        icals_path = outp
        data_path = outp + ".data.json"
        classes_path = outp + ".classes.json"

        if $options[:cal_dir]
            $logger.error "Specified calendar dir name but output is not specified as directory"
            exit 5
        end
    end
end

if File.exists? extr_config_file

    if extr_config = YAML.load_file(extr_config_file)
        extr_config.map do |extr|

            if extr["type"] and file_path = extr["file"] and File.exists? file_path

                File.open file_path, "rb" do |f|

                    case extr["type"]
                    when /^sem(ester)?plan$/ then SemesterplanExtractor.new(f).extract
                    when /^ausb(ildungs)plan$/ then ExtractorAusbildungsplan.new(f).extract
                    end

                end

            end

        end.each {|extr| data = data.merge extr }
    else
        $logger.warn "Config file empty!"
    end

else
    $logger.warn "Missing config file!"
end

# unified: :only_self, :no_self, nil
#  :only_self : only self elements
#  :no_self   : append parent elements to calendar (useful when writing divided files in parallel)
#  nil        : default (self and parent)
#def data.add_to_icalendar(key, cal, unified=nil)
#
#    unless unified == :no_self
#        self[key].each do |planElement|
#            planElement.add_to_icalendar cal
#        end if self[key]
#    end
#
#    unless unified == :only_self
#        method(__method__).call(key.parent, cal) if key.parent # Mwahahaha, calls method itself so I won't need to rename here too if I change method name ^^
#    end
#end

# JSON data file version
$data_version = "1.04"

if data

    $logger.debug "We have data."
    $logger.debug $options.inspect

    $logger.debug "Remove duplicates..."
    data.elements.uniq! {|e| [e[:time], e[:title], e[:class], e[:special]] }

    if $options[:json]

        $logger.debug "Option :json"

        json_data = {
            json_data_version: $data_version,
            generated: Time.now,
            data: data.elements
        }

        $logger.debug "Writing JSON data file \"%s\"" % data_path

        if $options[:simulate]
            $logger.info "Would write #{data_path}"
        else
            File.open(data_path, "w+") do |datafile|
                datafile.puts $options[:json_pretty] ? JSON.pretty_generate(json_data) : JSON.generate(json_data)
            end
        end

        $logger.info "Wrote JSON data file \"%s\"" % data_path
    end

    if $options[:ical]

        $logger.debug "Option :ical"

        tz=TZInfo::Timezone.get "Europe/Berlin"
        cal_stub = Icalendar::Calendar.new
        no_unified = $options[:no_unified] ? :only_self : nil

        cal_stub.prodid = "-Christoph criztovyl Schulz//studienplan5 using icalendar-ruby//DE"
        cal_stub.add_timezone tz.ical_timezone(Time.now)

        calendars = {}

        # A calendar that contains all events
        all = cal_stub.dup

        unless Dir.exists?(icals_path)
            Dir.mkdir(icals_path)
            $logger.info "Would create #{icals_path}." if $options[:simulate]
        end

        $logger.info "Writing unified calendars." unless no_unified

        $logger.info "Collecting events..."

        data.elements.each do |elem|

            clazz = elem[:class]

            $logger.debug "Class: #{clazz.inspect}"
            $logger.debug "Elem: #{elem.inspect}" unless clazz

            calendars[clazz] = cal_stub.dup unless calendars[clazz]

            tzid=calendars[clazz].timezones[0].tzid.to_s

            event = calendars[clazz].event do |evt|

                formats = { title: "%s", class: "Klasse/Jahrgang: %s", more: "%s", nr: "#%s", room: "%s", lect: "Dozent: %s. " }
                formats = formats.merge(formats) do |key, oldval, newval|

                    empty = oldval.class == Array && oldval.length > 1 ? oldval[1] : ""

                    if elem[key].to_s != empty
                        newval = oldval % elem[key]
                    else
                        newval = ""
                    end

                end

                time = elem[:time]
                dur = elem[:dur]

                dtend = time + 5 if elem[:special] == :fullWeek
                comment = ""

                evt.dtstart = Icalendar::Values::DateTime.new time, 'tzid' => tzid

                if dtend
                    evt.dtend = Icalendar::Values::DateTime.new dtend, 'tzid' => tzid
                elsif elem[:dur]
                    evt.dtend = Icalendar::Values::DateTime.new time + dur/24.0, 'tzid' => tzid # dur is in hours, addition in days.
                else
                    evt.dtend = Icalendar::Values::DateTime.new time + 1/24.0, 'tzid' => tzid # Events must have end thats not equal to start, set dur 60 min (also see above)
                    comment += "\nIm Plan wurde keine Dauer angegeben, daher auf 60 Minuten gesetzt."
                    $logger.warn "Element with unknown Duration! Title: #{elem[:title].inspect}"
                end

                evt.summary = formats[:title] + formats[:nr]
                evt.location = formats[:room]

                evt.description = formats[:lect] + formats[:more] + formats[:class] + comment

                #evt.uid = "de.joinout.criztovyl.studienplan5.planElement." + clazz.id_str + "." + title+nr # TODO: UID. This is not unique, find something.
            end

            all.add_event event

        end

        unless no_unified

            $logger.info "Including parent calendar events..."

            calendars.keys.each do |clazz|

                $logger.debug "Parent events for #{clazz}"

                parent = clazz
                while parent = parent.parent
                    $logger.debug parent
                    calendars[parent].events.each do |evt| calendars[clazz].add_event evt end if calendars[parent]
                end
            end

        end

        $logger.info "Writing calendars..."

        if $options[:all_ics]

            all_ics_path = icals_path + File::SEPARATOR + "all.ical"

            $logger.info "Writing calendar file \"#{all_ics_path}\" containing all events..."

            if $options[:simulate]
                $logger.info "Would write #{all_ics_path}"
            else
                File.open(all_ics_path, "w+"){|f| f.puts all.to_ical }
            end

        end

        calendars.each_pair do |clazz, cal|

            $logger.debug "Class: #{clazz.inspect}"

            clazz_file = icals_path + File::SEPARATOR + StudienplanUtil.class_ical_name(clazz) + ".ical"
            clazz_file.gsub!(/\.ical/, ".unified.ical") unless no_unified

            $logger.info "Writing calendar file \"%s\"" % clazz_file

            if $options[:simulate]
                $logger.info "Would write #{clazz_file}"
            else
                File.open(clazz_file, "w+") do |f|
                    f.puts cal.to_ical
                end
            end
        end

        $logger.info "Wrote calendar files to \"%s\"" % icals_path
    end

    if $options[:classes]

        $logger.debug "Option :classes"

        json_data = {
            json_data_version: $data_version,
            generated: Time.now,
            ical_dir: ical_dir,
            unified: $options[:no_unified] ? false : true,
            load_events: $options[:no_events] ? false : true,
            data: {}
        }
        export = json_data[:data] # TODO Do we still require this as an extra variable?

        # Build classes structure. Keys are Clazzes and value array elements are parents.
        data.extra[:classes].each do |key|

            export.store(key, [])

            # Loop through parents until none is left
            parent = key
            while parent = parent.parent
                export[key].push parent
            end
        end

        json_data[:data] = StudienplanUtil.json_object_keys(export) unless $options[:no_jok]

        $logger.debug "Writing JSON classes file \"%s\"" % classes_path

        if $options[:simulate]
            $logger.info "Would write #{classes_path}"
        else
            File.open(classes_path, "w+") do |datafile|
                datafile.puts $options[:json_pretty] ? JSON.pretty_generate(json_data) : JSON.generate(json_data)
            end
        end

        $logger.info "Wrote JSON classes file \"%s\"" % classes_path
    end
else
    $logger.info "No data"
end
