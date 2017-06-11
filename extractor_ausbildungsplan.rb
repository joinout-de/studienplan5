require "json"
require "date"
require_relative "structs"

class ExtractorAusbildungsplan

    attr_reader :data

    def initialize(file)
        @file = file
        @data = Plan.new "Ausbildungsplan"
    end

    def extract()
        case $TABULA_VERSION
        when "0.9" then extract09
        else extract09
        end
    end

    # Extract using Tabula 0.9 data format
    def extract09()

        puts "Using Tabula 0.9 data format"

        woche=""
        zeitraum=""
        comment=""
        taetigkeit=""
        klasse = Clazz.new("FS151","BSc","FST","ABB2015")

        inhalt = JSON.parse(@file.readlines.join(?\n).gsub("\\r", " ").gsub(/- (\w)/, "\\1").gsub(/ +/, " "))

        inhalt.shift

        for zeile in 0..4
            for spalte in 0..10

                zx4=zeile*4;

                woche = inhalt[zx4][spalte]["text"]
                zeitraum = inhalt[zx4+1][spalte]["text"]

                if !(freieTage = inhalt[zx4+2][spalte]["text"]).empty?
                    comment = "Freie Tage: #{freieTage}."
                end

                if inhalt[zx4+3][spalte]["text"] != ""
                    taetigkeit = inhalt[zx4+3][spalte]["text"]
                end

                taetigkeit = case taetigkeit
                             when /^Studienpräsenzwochen?$/ then "Studienpräsenz"
                             when /^Betriebliche Praxis (\d+)$/
                                 comment += (comment.empty? ? "" : " ") + "Nr: #$1"
                                 "Praxis"
                             when /^ATIW Block (\d+)$/
                                 comment += (comment.empty? ? "" : " ") + "Nr: #$1"
                                 "ATIW"
                             else taetigkeit
                             end

                next if woche.empty?

                @data.push({
                    title: taetigkeit,
                    class: klasse,
                    time: DateTime.strptime("1 "+woche+" 20"+zeitraum[-2,2],"%u KW %W %Y"),
                    special: :fullWeek,
                    comment: comment
                })
            end
        end

        @data
    end

end
