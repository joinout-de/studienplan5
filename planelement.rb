#!/usr/bin/env ruby 
# Part of utitily to convert HTMLed-XLS studienpläne into iCals. 
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
 

# This is the struct for storing event information 
require "./util"
PlanElement = Struct.new(:title, :clazz, :room, :time, :dur, :lect, :nr, :special, :more) do

    def self.FullWeek(title, clazz, room, date, more=nil)
        #                                         dur  lect  nr
        return self.new(title, clazz, room, date, nil, nil, nil, :fullWeek, more) 
    end

    def format(obj, format="%s", empty="", opts=[])
        if obj.class.name == Clazz.name
            if opts.include? :simple
                format % obj.simple
            else
                format % obj.to_s
            end
        elsif obj.class.name == DateTime.name
            if opts.include? :fullWeek
                format % formatWeek(obj)
            else
                format % formatTime(obj)
            end
        else
            StudienplanUtil.format_non_empty(obj, format, empty, opts)
        end
    end

    def to_s

        title = format(self.title, " %s")
        clazz = format(self.clazz, " for %s")
        more = format(self.more, " (%s)")

        case self.special
        when nil
            time = format(self.time)
            dur = format(self.dur, "@%s")
            nr = format(self.nr, "#%s")
            room = format(self.room, " at room %s")
            lect = format(self.lect, " by %s")
            return time + dur + title + nr + clazz + room + lect + more
        when :fullWeek
            time = format(self.time, "%s", "", [:fullWeek])
            return time + title + clazz + more + " (Full Week)"
        end
    end

    public
    def add_to_icalendar(icalendar)

        icalendar.event do |evt|

            title = format(self.title)
            clazz = format(self.clazz, "Klasse/Jahrgang: %s")
            more = format(self.more)

            nr = format(self.nr, "#%s")
            room = format(self.room)
            lect = format(self.lect, "Dozent: %s.")

            dtend = self.time + 5 if self.special == :fullWeek


            evt.dtstart = self.time

            if dtend
                evt.dtend = dtend
            elsif self.dur
                evt.dtend = self.time + self.dur/24
            else
                evt.dtend = self.time
            end

            evt.summary = title + nr
            evt.location = room
            evt.description = "#{lect}#{more}#{clazz}"

            #evt.uid = "de.joinout.criztovyl.studienplan5.planElement." + self.clazz.id_str + "." + title+nr # TODO: UID. This is not unique, find something.
        end
    end
end

