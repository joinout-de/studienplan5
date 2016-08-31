#!/usr/bin/env ruby

text1 = "Do/Fr/Sa WP-BI2(b/c)-Sam"
text2 = "Do13.30[a] WIN2(3a)-Ew"
text3 = "Do13.30[a] WIN2(3a)-Sam"
text4 = "Do/Fr/Sa WP-BI2(b/c)-Em"
text5 = "Do/Fr/Sa WP-BI2(b/c)-Sa"

def multidays(text)

    days = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    days_RE_or = "(#{days.join("|")})"

    regex = /#{days_RE_or} ?(?:ab ?)?((\d{1,2})(\.|:)(\d{2}))?(\[(.*?)\])? ?(.+(?:\(.*?\))?(?:-.{2,3}?)?)?/
    scan1 = text.scan regex
    scan2 = text.split(" ")[0].scan(/#{days_RE_or}/)

    #puts scan1[0].to_s

    if scan1.length == scan2.length
        return false
    else
        text_ = text.gsub(/-\w{2,3}$/, "")
        mdays = []
        sep = nil
        lastDay = false
        text_.split(/#{days_RE_or}/).each do |part|

           if part =~ /^#{days_RE_or}$/
               mdays.push part
               lastDay = true
           elsif lastDay and not sep
               sep=part
               lastDay = false
           else
               lastDay = false
           end
        end
        text = text.gsub mdays.join(sep), ""
        mdays_ = []

        mdays.each do |mday|
            mdays_.push(mday + text)
        end
        return mdays_
    end
end

def md_(text)
    puts "Multiday? #{text}: #{multidays(text)}"
end

md_(text1)
md_(text2)
md_(text3)
md_(text4)
md_(text5)
