#!/usr/bin/env ruby

require "logger"
require "time"

class CellRegisters

    attr_accessor :word, :context, :elements

    def initialize()
        clear true
    end

    def clear(full=false)
        @word = ""
        @elements = []
        @multi = 0
        @context = nil if full
    end

    def multi
        @multi += 1
    end

    def to_s
        "word: %p, elements %p, context %p" % [ @word, @elements, @context ]
    end

end

class CellParser

    attr_reader :result

    @@day_re = /^(M[oi]|D[io]|Mi|Fr|S[ao])$/

    def initialize()
        @logger = $logger ? $logger : Logger.new(STDERR)
    end

    def set(str)
        @str = str

        @registers = [ CellRegisters.new() ]
        @reg = @registers[0]
        @result = { day: [], time: [], rooms: [], subj: [], groups: [], dur: nil, lect: [] }
        @contexts = []
    end

    def parse(str=nil)

        set(str) if str

        @pos = 0
        @depth = 0

        progname = @logger.progname ? @logger.progname.dup : @logger.progname
        @logger.progname = __method__

        @logger.debug { "str: #{@str.inspect}" }
        
        while @pos <= @str.length
            advance
        end

        @logger.debug { "Finished!" }

        %w( str result contexts ).each do |regname|
            @logger.debug { "#{regname}: #{self.instance_variable_get((?@ + regname.to_s)).inspect}" }
        end 

        @logger.progname = progname
    end

    def delimit

        debug { "Delimiter! Registers: #{@reg.inspect}" }

        reg = @reg
        context = @reg.context
        word = @reg.word
        elements = @reg.elements

        elements.push word unless word.empty?

        case context
        when nil
            case word
            when @@day_re
                debug { "A day!" }
                @result[:day] += elements
                @reg.clear
                enter_context :time
            when /([\p{Word}\/-]+)/
                @result[:subj].push $1
                debug { "Adding to subj" }
            when ""
                debug { "Result empty." }
            else
                debug { "Unknown result #{@reg.word.inspect}" }
            end
        when :lect, ?[, :time

            sym = case context
                  when ?[ then :rooms
                  else context
                  end

            if !elements.empty?
                @result[sym] += elements 
                debug { "Add #{sym} #{elements.inspect}" }
            else
                debug { "#{sym} empty." }
            end

            if sym == :time
                leave_context
            end
        when ?(, :grp_range
            if word =~ /^\p{Number}+$/
                @result[:dur] = word.to_i / 60.0
            else
                @result[:groups] += elements
            end
        when :dur
            debug { "Setting #{context}" }
            @result[context] = word
            leave_context
        when :time_dur

            if elements.length == 2
                @result[:time].push elements[0]
                @result[:dur] = (Time.parse(elements[1]) - Time.parse(elements[0])) / 60.0
            else
                error { "Invalid time range! #{elements.inspect}" } 
            end
            leave_context
        else
            debug { "Nothing to delimit." }
        end

        if @reg == reg
            debug { "Clearing registers..." }
            @reg.clear
        end
    end

    def record_word(word=nil)
        word = word ? word : @current
        @reg.word += word
    end

    def record_element(element=nil, clear_word=false)
        element = element ? element : @current
        @reg.elements.push element
        @reg.word = "" if clear_word
    end

    def _log(level, msg, call_level, &block)
        progname = progname ? progname : parent_caller(1 + call_level)
        @logger.add(level, msg, progname, &block) 
    end

    def debug(msg = nil, call_level = 0, &block)
        _log(Logger::DEBUG, msg, call_level+1, &block)
    end

    def warn(msg = nil, call_level = 0, &block)
        _log(Logger::WARN, msg, call_level+1, &block)
    end

    def error(msg = nil, call_level = 0, &block)
        _log(Logger::ERROR, msg, call_level+1, &block)
    end

    def parent_caller(level=1)
        caller[level][/`.*'/][1..-2]
    end

    def warn_unknown_here
        warn(nil, 1) { "\"#{@current}\" is unknown in #{@reg.context.inspect} context!" }
    end

    def enter_context(context = nil)

        context = context ? context : @current
        @contexts.push @reg.context

        debug { "Entering context #{context.inspect} from #{@reg.inspect}."}

        @depth += 1

        if @registers[@depth]
            @registers[@depth].clear true
        else
            @registers[@depth] = CellRegisters.new()
        end

        @reg = @registers[@depth]
        @reg.context = context
    end

    def leave_context

        context = @reg.context

        @contexts.push context

        debug { "Leaving context #{context.inspect} to #{@registers[@depth-1].inspect}." }
        @registers.each.with_index {|r, i| debug(nil, 3){ "#{i}: #{r.inspect}" } }

        @reg.clear true


        @depth -= 1
        @reg = @registers[@depth]
    end

    def advance

        @current = @str[@pos]

        context = @reg.context
        word = @reg.word

        debug { "Current: #{@current.inspect}" }

        case @current

        when /[\p{Alpha}]/
            case context
            when nil, ?[, :lect
                record_word
            when ?(
                record_word
            when :grp_range
                record_word
                if @reg.word =~ /((?<num>\d)(?<from>\w)-(?<to>\w))/ # Expand group-ranges (like "4a-c" to "4a,4b,4c")
                    @reg.word = ""
                    @reg.elements += ($~[:from]..$~[:to]).to_a.map {|c| "%s%s" % [$~[:num], c] }
                end
                delimit
            when :time
                leave_context
                record_word
            else
                warn_unknown_here
            end

        when /\p{Number}/
            case context
            when nil
                if word =~ @@day_re
                    delimit
                end
                record_word
            when :time, :dur, ?[, :time_dur
                record_word
            when ?(
                record_word
            else
                warn_unknown_here
            end
        when /\p{Space}/, nil
            case context
            when :lect
                delimit
                leave_context
            else
                delimit
            end
        when ?(, ?[
            delimit
            enter_context

        when ?), ?]
            delimit
            leave_context

        when ?-
            case context
            when nil
                if @contexts[-1] == ?(
                    enter_context :lect
                else
                    record_word
                end
            when :time
                leave_context
                @reg.clear
                enter_context :time_dur
                record_element word
            when ?(
                enter_context :grp_range
                debug { "Word: #{word}, curr #{@current}"}
                record_word word # pull in contents from outer context
                record_word
            else
                warn_unknown_here
            end

        when ?., ?:
            case context
            when nil
                record_word
                debug "Dot in subject? #{word.inspect}"
            when :time, :time_dur
                record_word ?:
            else
                warn_unknown_here
            end
        when ?/
            case context
            when nil
                if word =~ @@day_re
                    record_element word, true
                else
                    record_word
                end
            when ?(, ?[, :time, :lect
                record_element word, true
            else
                warn_unknown_here
            end

        else
            delimit
            debug { "Unknown! #{@current}" }
        end

        @pos += 1
    end
end
