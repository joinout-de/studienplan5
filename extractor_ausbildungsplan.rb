require "json"
require "date"
require_relative "structs"

class ExtractorAusbildungsplan

    # Die extrahierten Daten.
    attr_reader :data

    # Extractor für JSON der Ausbildungsplan Excel-PDF.
    # (.xls mit Tabula zu .json)
    def initialize(file)

        @logger = $logger && $logger.dup || Logger.new(STDERR)
        @logger.level = $logger && $logger.level || Logger::INFO
        @logger.progname = "AusbPlan"

        @file = file
        @data = Plan.new "Ausbildungsplan"
    end

    #
    # Daten extrahieren.
    #
    # <em>$TABULA_VERSION</em> beeinflusst welche Tabula-Version ausgewählt wird.
    #
    # - 1.0 (Standard)
    # - 0.9
    def extract()

        # line-breaks are saved as \r, remove them and the word-breaks. (And spaces...)
        inhalt = JSON.parse(@file.readlines.join(?\n).gsub("\\r", " ").gsub(/- (\w)/, "\\1").gsub(/ +/, " "))

        case $TABULA_VERSION
        when "0.9" then extract09(inhalt)
        when "1.0" then extract10(inhalt)
        else extract10(inhalt)
        end
    end

    # Daten aus Tabula-1.0-Datenformat extrahieren.
    def extract10(inhalt)

        @logger.info "Using Tabula 1.0 data format"

        #
        # Tabula 1.0 data looks like this:
        #
        # {
        #   {
        #
        #     // uninteresting metadata
        #     extraction_method: %s // should be "lattice",
        #     top: %f,
        #     left: %f,
        #     width: %f,
        #     height: %f,
        #
        #     // interesting row data
        #     data: [
        #       {
        #         top: %f, // lame
        #         left: %f, // lame
        #         width: %f, // uh, interesting!
        #         height: %f, // lame
        #         text: %s, // uh, interesting!
        #       },
        #       ...
        #     ]
        #    },
        #    ...
        # }
        #

        klasse = nil
        resolveClazz(inhalt.shift["data"][0][1]["text"], /Klasse (..\d{3})Ausbildungsplan (\d{4} \/ \d{4})(.*)/) {|k| klasse = k }

        @logger.debug "---"

        for zeilenNr in (1...inhalt.length).step(2)
            zeile = inhalt[zeilenNr]["data"]

            # Zeilen:
            # 0 - KW %u
            # 1 - %d.%m - %d.%m.%y (%y != %Y, %y is YY, %Y is YYYY))
            # 2 - freie Tage á la "Mo., Di.," o.ä.
            # 3 - Veranstaltung
            #
            # 0, 1, 2 - metadata
            # 3 - data

            cellWidth = zeile[0][0]["width"].to_f

            # index of cells in row 0-2
            u = -1 # until cell
            c = 0 # current cell

            zeile[3].each do |va| # va - Veranstaltung

                next if va["text"] == ""

                taetigkeit = va["text"]
                va_count = (va["width"].to_f / cellWidth).round
                u = u + va_count
                base_comment = ""

                @logger.debug { "%07.3f of %07.3f => %02d..%02d (%02dx) %s" % [ va["width"].to_f.round(3), cellWidth.round(3), c, u, va_count, taetigkeit.inspect] }

                resolveTaetigkeit(taetigkeit, base_comment) {|t, cm| taetigkeit = t; base_comment = cm; }

                @logger.debug "Resolved %p" % taetigkeit
                @logger.debug "base_comment: #{base_comment.inspect}"

                for metaCellNr in c..u

                    woche = zeile[0][metaCellNr]["text"]
                    zeitraum = zeile[1][metaCellNr]["text"]
                    comment = base_comment

                    if !(freieTage = zeile[2][metaCellNr]["text"]).empty?
                        comment = ( comment.empty? ? "" : comment + ", ") + "Freie Tage: #{freieTage}."
                    end

                    timeStr = "1 #{woche} 20#{zeitraum[-2,2]}";

                    @logger.debug  { "timeS %s, cm %s" % [timeStr, comment].map(&:inspect) }

                    if woche.empty?
                        @logger.debug "Week empty, skipping."
                        next
                    end

                    @data.push({
                        title: taetigkeit,
                        class: klasse,
                        time: DateTime.strptime(timeStr, "%u KW %W %Y"),
                        special: :fullWeek,
                        comment: comment
                    })

                    c += 1
                end # metaCellNr

                @logger.debug "--- Cell end."
            end # zeile[3].each

            @logger.debug "-- Row end."
        end # zeilenNr

        @data
    end

    # Daten aus Tabula-0.9-Datenformat extrahieren.
    def extract09(inhalt)

        @logger.info "Using Tabula 0.9 data format"

        woche=""
        zeitraum=""
        comment=""
        taetigkeit=""
        klasse = nil

        resolveClazz(inhalt.shift[0]["text"], /Klasse (..\d{3}) Ausbildungsplan (\d{4} ?\/ \d{4}) (.*)/) {|k| klasse = k }

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

                next if woche.empty?

                resolveTaetigkeit(taetigkeit, comment) {|t,c| taetigkeit = t; comment = c }

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

    ##
    # Löst heuristsisch den Titel einer Veranstaltung auf.
    #
    # Ggf. verändert sich das Kommentar der Veranstaltung,
    # die Änderung wird vor das gegebene Kommentar gehängt.
    #
    # [taetigkeit] Titel
    # [comment] Kommentar
    def resolveTaetigkeit(taetigkeit, comment)

        base_comment = ""
        taetigkeit = case taetigkeit
                     when /^(STPR|Studienpräsenzwochen)(.*)$/
                         base_comment += $2.strip
                         "Studienpräsenz"
                     when /^Betriebliche Praxis (Block )?(\d+)(.*)$/
                         base_comment += "Nr: #$2"
                         base_comment += ", #{$3.strip}" unless $3.empty?
                         "Praxis"
                     when /^ATIW (- )?Block (\d+)$/
                         base_comment += "Nr: #$2"
                         "ATIW"
                     else taetigkeit
                     end

        comment = base_comment + ( base_comment.empty? || comment.empty? ? "" : ", " ) + comment

        yield taetigkeit, comment

    end

    ##
    # Löst den Namen einer Klasse aus gegebener Zelle
    # anhand gegebenem regulären Ausdruck auf.
    #
    # RegEx-Gruppen:
    # 0. klasse
    # 0. ausbjahr
    # 0. company
    #
    # [inhalt] Zelle
    # [regex] regulärer Ausdruck
    def resolveClazz(inhalt, regex)

        inhalt.match(regex)

        klasse = @data.extra[:class] = Clazz::from_short_name($1)
        ausbjahr = @data.extra[:ausbjahr] = $2
        company = @data.extra[:company] = $3

        @logger.info { "Parsing for class %s, ausbjahr %s, company %s" % [klasse, ausbjahr, company].map(&:inspect) }

        yield klasse, ausbjahr, company
    end

end
