#!/usr/bin/env ruby
require "nokogiri"
require "date"


rows = [] # the plan
cols = [] # the legend

# Identifies element type (SPE/ATIW/Practical Placement)
# struc.: { "color1" => "type1", "color2" => "type2" }
colorKeys = {} 

# Which class is related to a row
row_who = [] 

r=0 # row counter
planEnd=false # flag for switching from plan to legend 
debug = {cols: false, rows: true, row_merge: false} # control debug output
days=["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

# Finds a child that has the requested tag name
def parent(child, parentTag)
    parent=child.parent
    while parent.name != parentTag; parent = parent.parent; end
    return parent
end

def parseValue(value, weekdate, weekofyear)

    start=Date.strptime("1" + weekdate[0..5] + weekofyear[0..3], "%u%d.%m-%Y")
    dur=""
    if td and
        ( match = td.text.scan(/(#{days.join("|")}) ?((\d{1,2})(\.|:)(\d{2}))?(\[(.*)\])?(.*)/) ) and
        ( match = match[0] ) and
        ( match.length == 8 )

        day=match[0]
        hours=match[2]
        minutes=match[4]
        room=match[6]


        if hours and minutes
            start = start + Rational(hours,24) + Rational(minutes,1440)
        end
        start+= days.index day
        dur=1

        text= "Time #{start.strftime("%a %H:%M %d.%m.%y KW%U")} @ Room \"#{room}\""

        title=match[7].to_s.strip.scan(/(.*)\((.*)\)(-(.*))?/)[0]
        if title
            text += "; Title: #{title[0]}, Group: #{title[1]}#{ title[3] ? ", Lecturer: " + title[3] : ""}"
        else
            text += "; Not matched! \"#{match[7].to_s}\""
        end

    elsif td != nil
        dur=5
    end

end

if not file = ARGV[0]
    puts "Missing input file"
else
    doc = File.open(file){|f| Nokogiri::HTML(f)}

    doc.xpath("//tr").each{|tr|
        fonts=tr.xpath("td//font")
        key=fonts[0]
        if key

            if key.inner_html == "Abkürzung"
                planEnd=true
                r=0
            end

            if planEnd
                tr.xpath("td").map.with_index{|td, index|
                    if index >= cols.length; cols.push []; end
                    if debug[:cols]; puts "COLS: #{index},#{r}: #{td.text}"; end

                    cols[index].push td
                }
                r+=1
                next
            else

                #puts key.to_s
                keyBgColor=parent(key, "td")["bgcolor"]

                if key.inner_html =~ /\d{4}\/KW \d{1,2}/; r=0; end

                if key.inner_html =~ /\w{3}\d{4}/; colorKeys.store(keyBgColor, key.inner_html); end

                firstValBgColor = parent(fonts[1], "td")["bgcolor"]

                if not row_who[r]; row_who.push []; end
                row_who[r].push key.inner_html

                if debug[:rows]
                    puts "ROWS: %02d: %s (%s); (%s)" % [r, keyBgColor, key.inner_html, firstValBgColor]
                    
                    if r > 1 # row 0 and 1 have KW and date only

                        fonts.map.with_index do |font, index|
                            
                            if index >= 1 # row 0 would have class name only (could also be empty)
                                #parseValue(value, weekdate, weekofyear
                                puts (inner=font.inner_html) == "<br>" ? "" : parseValue(inner, rows[1], rows[0])
                            end
                        end
                    else
                        puts tr
                    end
                end
            end
        end

        if not rows[r]; rows.push []; end
        rows[r].push tr
        r+=1
    }

    #modsAbbr=cols[1] # abbreviations for modules
    #fullMods=cols[2] # full module names
    #lectsAbbr=cols[4] # abbreviations for lecturers
    #fullLects=cols[5] # full lecturers
    otherKey=cols[7]
    keyMeaning=cols[8]

    for n in 12..14
        colorKeys.store(otherKey[n]["bgcolor"], keyMeaning[n].text)
    end
    if debug[:cols]; puts "colorKeys: #{colorKeys}"; end


    # merge plan rows
    rows.map.with_index{|row,index|
        while row.length > 1
            row.delete_at(1).children.each{|child| row[0].add_child(child)}
        end

        if debug[:row_merge]; puts "RWMR: #{index}"; end

        if index < 2
            if debug[:row_merge]
                puts "Header rows"
                puts row[0].xpath("td").each{|td| puts td.text}
            end
        else
            weeksofyear=rows[0][0].xpath("td")
            weekdates=rows[1][0].xpath("td")

            row[0].xpath("td").map.with_index{|td,i|
                weekofyear=weeksofyear[i]
                if weekofyear; weekofyear=weekofyear.text; end
                weekdate=weekdates[i]
                if weekdate; weekdate=weekdate.text; end

                if i==0 or weekofyear.length < 1; next; end
                start=Date.strptime("1" + weekdate[0..5] + weekofyear[0..3], "%u%d.%m-%Y")
                dur=""
                if td and
                    ( match = td.text.scan(/(M[oi]|D[io]|Fr|S[ao]) ?((\d{1,2})(\.|:)(\d{2}))?(\[(.*)\])?(.*)/) ) and
                    ( match = match[0] ) and
                    ( match.length == 8 )

                    day=match[0]
                    hours=match[2]
                    minutes=match[4]
                    room=match[6]


                    if hours and minutes
                            start = start + Rational(hours,24) + Rational(minutes,1440)
                    end
                    start+= days.index day
                    dur=1

                    text= "Time #{start.strftime("%a %H:%M %d.%m.%y KW%U")} @ Room \"#{room}\""

                    title=match[7].to_s.strip.scan(/(.*)\((.*)\)(-(.*))?/)[0]
                    if title
                        text += "; Title: #{title[0]}, Group: #{title[1]}#{ title[3] ? ", Lecturer: " + title[3] : ""}"
                    else
                        text += "; Not matched! \"#{match[7].to_s}\""
                    end

                elsif td != nil
                    dur=5
                end

                if debug[:row_merge]
                    puts "RWMR: %2d (Match %s;%s Calc. %s@%sd) %s %s" % [i, weekofyear, weekdate, start, dur, text, (colorKey = colorKeys[td["bgcolor"]]) ? "(#{colorKey})" : "" ]
                end
            }
            if debug[:row_merge]; puts "--"; end
        end
    }
    #rows[0].each{|row| row.xpath("td").each{|e| puts e.text}}
end
