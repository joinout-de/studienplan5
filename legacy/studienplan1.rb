#!/usr/bin/ruby
require "csv"
require "fileutils"
prev=nil
prev_key=nil
rows=[]
#rows_merged=[]
#first=true
i=0
j=0
i_max=0
CSV.foreach("studienplan.csv", encoding: "UTF-8") do |row| 
    
    if not prev; prev=row; next; end # Need a previous row.

    #if j > 200; break; end # Only first 200 rows
    if row[1] == "Abkürzung"; break; end

    if row[0] == "Gruppe"; i=0; end # Continuation of last row

    if rows.length == i; rows.push({}); end # no need to check, "i" will increase by 1 each time.

    prev_key=prev.slice! 0 # First cell could contain class name

    if prev_key =~ /[AB]BB\d\d\d\d/; prev_key=nil; end # Exceptions which values aren't classes

    if not rows[i][prev_key]; rows[i].store(prev_key, []); end

    rows[i][prev_key].push prev
    
    #puts "rows[#{i}][#{prev_key}].push #{prev}"

    i_max = i > i_max ? i : i_max 
    
    puts "%3i;%3i: %s;" % [i, j, prev_key]
    
    # Continue
    prev=row
    i+=1
    j+=1
end
puts "Rows read: #{j+1}"
puts "Rows: #{i_max+1}"
# Merge splitted/continued rows together
#
rows_new = []
i=0;
rows.each{|row|
    row_new = {}
    row.each {|key,val|
        row_new.store(key, [])
        val.each{|e|
            row_new[key] += e
        }
    }
    puts "Row %i has: %s" % [i, row_new.keys]
    rows_new.push row_new
    i+=1;
}
rows=rows_new
puts "Merging loops: #{i}"
puts "Merged rows: #{rows.size}"
#puts rows.to_s

weeks = rows.slice!(0) [nil]
dates = rows.slice!(0) ["Gruppe"]

#puts weeks.map.with_index {|x,i| x+" "+dates[i]}
i=0
classes = {}
no_class = []
rows.each{|row|
#    puts "--"
#    puts "%i@%i: %s" % [i, row.length, row.to_s ]
    row.keys.each{|klass|
        if not no_class[i]; no_class.push []; end
        if klass
#           puts "#{klass}: class #{i}"
            if not classes[klass]; classes[klass]=[]; end
            classes[klass].push row[klass]
        else
#           puts "#{klass}: no class #{i}"
            no_class[i].push row[klass]
        end
    }
#    puts "--"
    i+=1
}
puts "Found #{classes.keys.length} classes"
puts classes
#puts "Non-classes(%i):" % [no_class.length]
#no_class.each{|x| puts "%2$i: %1$s\n--q" % [x, x.length] }
#puts weeks.to_s
#puts dates.to_s
'''
rows_new = []
rows.each{|row|
    row_merged= []
    row.each{|row_part|
        row_merged = row_merged + row_part
    }
    rows_new.push row_merged
}
puts ["qhi", "there", "whats", "up"].to_csv
puts rows_new.to_s
merged="studienplan_merged.csv"
#FileUtils.touch(merged)
CSV.open(merged, "wb", encoding: "UTF-8"){|csv|
    rows_new.each{|row|
        csv << row
    }
}
'''
