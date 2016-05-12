#!/usr/bin/env ruby 
# Part of utility to convert HTMLed-XLS studienpläne into iCals.
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
 

# This is the Struct for storing class information
require "./util"
Clazz = Struct.new(:name, :course, :cert, :jahrgang, :group) do

    def self.Jahrgang(name)
        return self.new(nil, nil, nil, name)
    end

    def to_s

        jahrgang = format(self.jahrgang, "Jahrgang %s")
        full_name = format(self.full_name, ", %s")
        course = format(self.course,  ", Course %s")
        cert = format(self.cert, ", Cert. %s")

        jahrgang + full_name + course + cert
    end

    def full_name
        format(self.group, format(self.name, "%s-%%s"), format(self.name, "%s", nil))
        #self.group ? self.name.to_s + "-" + self.group.to_s : self.name.to_s
    end

    def full_jahrgang
        format(self.course, format(self.jahrgang, "%s(%%s)"), format(self.jahrgang))
        #self.course ? self.jahrgang.to_s + "(" + self.course.to_s + ")" : self.jahrgang
    end

    def simple
        self.name ? "%s(%s)" % [self.full_name, self.full_jahrgang] : "#{self.full_jahrgang}"
    end

    def format(str, format="%s", empty="", opts=[])
        StudienplanUtil.format_non_empty(str, format, empty, opts)
    end

    def parent
        # Jahrgang > Course > Cert > Name > Group
        ret = self.dup
        if self.group
            ret.group = nil
        elsif self.name
            ret.name = nil
        elsif self.cert
            ret.cert = nil
        elsif self.course
            ret.course = nil
        elsif self.jahrgang
            ret = nil
        end
        ret
    end
end

