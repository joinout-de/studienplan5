#!/usr/bin/env ruby

require "nokogiri"
require "date"

plan = []
legend = []

colorKeys = {}

r=0 # Row counter
planEnd=false # flag for switching from plan to legend parsing

debug = {
   row: true, 
   fonts: true
}
def parent(child, parentTag)
    parent=child.parent
    while parent.name != parentTag; parent = parent.parent; end
    return parent
end

if not file = ARGV[0]
    puts "Missing input file. (ARGV 0)"
else
    doc = File.open file do |f| Nokogiri::HTML f end

    lastKey = nil;

    doc.xpath("//tr").each do |tr|

        fonts = tr.xpath("td//font")

        key = fonts[0]
        if key

            keyColor = parent(key, "td")["bgcolor"] 
            key = ( ( key = key.inner_html ) == "<br>" and lastKey ) ? lastKey : key

            if key =~ /\w{3}\d{4}/; colorKeys.store(keyColor, key); end

        end

        if key == "Abkürzung"; planEnd = true; end

        if planEnd; break; end # Will do more here later :)

        if debug[:row]
            puts "ROWS: Row index #{r_index}"
            puts "ROWS: Row key (#{key}) and color (#{keyColor})"
        end

        fonts.map.with_index do |font, f_index|

            if (fontInner = font.inner_html) and fontInner != "<br>" ;
                puts "FNTS: Font index (#{f_index}) inner (#{fontInner})"
                if f_index > 0
                    puts fontInner.scan(/(M[oi]|D[io]|Fr|S[ao]) ?((\d{1,2})(\.|:)(\d{2}))?(\[(.*)\])? ?(.*)/).to_s
                end
            end
            if debug[:fonts]
                if ( fontColor = font["color"] ); puts "FNTS: Font color: #{fontColor}"; end
            end

        end
        if debug[:row]; puts "--"; end

        lastKey = key
    end
end
