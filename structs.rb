#!/usr/bin/env ruby
# Part of a utility to convert HTMLed-XLS Studienpläne into iCal.
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

require "json"
require_relative "util"; include StudienplanUtil

class Plan

    @@logger = $logger || Logger.new(STDERR)
    @@logger.level = $logger && $logger.level || Logger::INFO

    attr_reader :name, :elements, :extra

    def initialize(name, elements = [], extra = {})
        @elements = elements ? elements : [] # An array of {}'s
        @name = name
        @extra = extra ? extra : {}
    end

    def push_element(fields)
        @@logger.debug { "New element: #{fields.inspect}" }
        @elements.push(fields)
    end

    alias_method :push, :push_element

    def merge(plan)

        case plan
        when Plan
            plan = Plan.new(plan.name + "+ #{@name}", plan.elements + @elements, plan.extra.merge(@extra))
        when Array
            plan += @elements
        when Hash
            plan = plan.merge @extra
        else
            @@logger.error "Can't merge a plan with #{plan.class}!"
            @@logger.debug plan.inspect
        end
        plan
    end

    def add_full_week(title, clazz, room, date, more=nil)
        push({title: title, class: clazz, room: room, time: date, more: more, special: :fullWeek})
    end

    def add(title, clazz, room, time, dur, lect, special, more)
        $logger.warn "#{__method__} is deprecated." if $logger
        push({title: title, class: clazz, room: room, time: time, dur: dur, lect: lect, special: special, more: more})
    end

    def to_json(opts = nil) # Yup, we can make it nil.
        return JSON.generate({name: @name, elements: @elements, extra: @extra}, opts)
    end

    def Plan.from_json(json_string)
        json = JSON.parse json_string, :symbolize_names => true
        return self.new(json[:name], json[:elements], json[:extra]) # Self is not a Plan instance, it's the Plan instance of Class.
    end

    def to_s
        "Plan \"#{@name}\". Elements:#{$/ + @elements.join($/) + $/}Extra: #{@extra}"
    end

end

##
# A Class.
#
# Four kinds of classes: Year &rarr; Course (Degree) &rarr; Group &rarr; Class &rarr -> Class Part. (Year has courses, courses have groups, ...)
#
# The class has an assigned _certification_ (apprenticeship) and a _number_.
#
# Year, certification and class number can be determined from <em>short name</em>, for the course the <em>full name</em> is needed.
#
# == Names
#
# [short name] +CCYYN+
# [full name] <code>CCYYN+D (CCC) G</code>
#
# === Codes
#
# CC:: Certfication 2-char-code (afaik only +FI+, +FS+, +FV+)
# YY:: Year 20xx
# N:: Class number (unique for certification)
# D:: Course (degree)
# G:: Group
# CCC:: Certfication 3-char-code (FBV, FIS, FST)
#
class Clazz

    # Compatibility
    JSON_VERSION = 2

    # Class' four-digit start year
    #
    # +2015+, +2016+, ...
    attr_reader :year

    # Class course
    #
    # +BA+, +BSc+
    attr_reader :course

    # Class' group
    #
    # +a+, +b+, +c+, ...
    attr_reader :group

    # Class' certification, two-char-code:
    #
    # +FI+ or +FS+, +FV+
    attr_reader :cert

    # Class' number
    #
    # +1+, +2+, +3+, ...
    attr_reader :number

    # Class' part
    #
    # +1+, +2+, +3+, ...
    attr_reader :part

    ##
    # Create a new class.
    #
    def initialize(year=nil, course=nil, group=nil, cert=nil, number=nil, part=nil)

        @year = year
        @course = course
        @group = group
        @cert = cert
        @number = number
        @part = part

        self

    end

    def with_year!(year)
        @year = year
        self
    end

    def with_year(year)
        self.dup.with_year! year
    end

    def with_course!(course)
        @course = course
        self
    end

    def with_course(course)
        self.dup.with_course! course
    end

    def with_group!(group)
        @group = group
        self
    end

    def with_group(group)
        self.dup.with_group! group
    end

    def with_cert!(cert)
        @cert = cert
        self
    end

    def with_cert(cert)
        self.dup.with_cert! cert
    end

    def with_number!(number)
        @number = number
        self
    end

    def with_number(number)
        self.dup.with_number! number
    end

    def with_part!(part)
        @part = part
        self

    end

    def with_part(part)
        self.dup.with_part! part
    end


    def with_number_and_cert!(number, cert)
        @number = number
        @cert = cert
        self
    end

    def with_number_and_cert(number, cert)
        self.dup.with_number_and_cert! number, cert
    end

    def parent!()

        # Part > Class > Group > Course > Year

        if !@part.nil?
            @part = nil

        elsif !@number.nil?
            @number = nil

        elsif !@cert.nil?
            @cert = nil

        elsif !@group.nil?
            @group = nil

        elsif !@course.nil?
            @course = nil

        else
            return nil

        end

        self

    end

    def parent()
        self.dup.parent!
    end

    def short_name()
        "%s%s%s" % [@cert.nil? ? "??" : @cert, @year.nil? ? "??" : @year-2000, @number.nil? ? "?" : @number]
    end

    def full_name()
        "%s+%-3s (%s) %s%s" %
            [self.short_name, @course.nil? ? "???": @course, @cert.nil? ? "???" : self.expand_cert, @group.nil? ? "?" : @group, @part.nil? ? "?" : @part]
    end

    def short_named?()
        !@year.nil? and @course.nil? and @group.nil? and !@cert.nil?  and !@number.nil? and @part.nil?
    end

    def extends?(other)
        !self.short_named && other.short_named && self.short_name == other.short_name
    end

    alias simple full_name

    ##
    # New class from <em>short name</em>. See Clazz.
    def self.from_short_name(short_name)

        # CCYYN
        #              $1 cert       $3 num
        #              vvvvvvv       vvvv
        short_name =~ /(\w{2})(\d{2})(\d)/
        #                     ^^^^^^^
        #                     $2 year

        #                          course
        self.new ("20" + $2).to_i, nil, nil, $1, $3
        #                               group
    end

    def expand_cert()

        return "???" unless @cert

        case @cert[1]
        when "I" then "FIS"
        when "S" then "FST"
        when "V" then "FBV"
        end
    end

    ##
    # New class from <em>full name</em>. See Clazz.
    def self.from_full_name(full_name)

        # CCYYN+D (CCC) G
        #             $1 cert       $3 num              $5 group
        #             vvvvvvv       vvvv                vvvvv
        full_name =~ /(\w{2})(\d{2})(\d)\+(\w+) \(\w+\) (\w+)/
        #                    ^^^^^^^      ^^^^^
        #                    $2 year      $4 course

        self.new ("20" + $2).to_i, $4, $5, $1, $3
    end

    def self.from_json(json)

        # TODO

        data = JSON.parse(json, { symbolize_names: true })

        if data[:json_class] != "Clazz"
            throw "Not a Clazz!"
        end

        if data[("v" + JSON_VERSION.to_s).to_sym]

        elsif data[:v]

        end

    end

    alias to_s full_name

    # `{ "json_class": "Clazz", "v": [ NAME, COURSE, CERT, JAHRGANG, GROUP ] }`
    def to_json(opts = nil)
        JSON.generate(
            {
                json_class: "Clazz", v: [
                    (!@cert.nil? and !@number.nil?) ? self.short_name : nil,
                    @course,
                    @cert.nil? ? @cert : self.expand_cert,
                    "ABB" + @year.to_s,
                    @part
                ],
                ("v" + JSON_VERSION.to_s) => {
                    year: @year,
                    course: @course,
                    group: @group,
                    cert: @cert,
                    number: @number,
                    part: @part
                }
            }, opts)
    end

    def ==(other)

        return false if other.nil?

        @year == other.year and
            @course == other.course and
            @group == other.group and
            @cert == other.cert and
            @number == other.number and
            @part == other.part
    end

    alias :eql? :==

    def hash
        @year.hash ^ @course.hash ^ @group.hash ^ @cert.hash ^ @number.hash ^ @part.hash
    end

end
