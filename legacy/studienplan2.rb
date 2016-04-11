#!/usr/bin/ruby
require "csv"
require "fileutils"
prev=nil
prev_key=nil
rows=[]
i=0
j=0
i_max=0
CSV.foreach("studienplan.csv", encoding: "UTF-8") do |row| 
    
    if not prev; prev=row; next; end # Need a previous row.

    #if j > 200; break; end # Only first 200 rows
    if row[1] == "Abkürzung"; break; end

    if row[0] == "Gruppe"; i=0; end # Continuation of last row

    if rows.length == i; rows.push([]); end # no need to check, "i" never will be 

    if not rows[i]; rows[i] = []; end

    rows[i].push prev

    i_max = i > i_max ? i : i_max 
    
    puts "%3i;%3i;" % [i, j]
    
    # Continue
    prev=row
    i+=1
    j+=1
end
puts "Rows read: #{j+1}"
puts "Rows: #{i_max+1}"

# Merge rows
rows_new = []
rows.each.with_index{|x,i|
#    puts "%i@%s" % [i,x]
    while x.length > 1
        x[0] += x.delete_at(1)
    end
    rows[i]=x[0]
} 
rows.each.with_index{|x,i|
    if i < 2; next; end
#q    puts x.to_s
    x.each.with_index{|y,j|
        if j==0 or not rows[0][j]; next; end
        start=Date.strptime("1" + rows[1][j][0..5] + rows[0][j][0..3], "%u%d.%m-%Y")
        dur=""
        if y =~ /M[oi]|D[io]|Fr|S[ao]/
            k=-1
            case y[0..1]
            when "Mo"
                k=0
            when "Di"
                k=1
            when "Mi"
                k=2
            when "Do"
                k=3
            when "Fr"
                k=4
            when "Sa"
                k=5
            when "So"
                k=6
            end
            start+=k
            dur=1
        elsif y != nil
            dur=5
        end
        rows[i][j]=[y,dur,start]
    }
}
rows.each{|x| puts x[0..10].to_s}
