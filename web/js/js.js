/*
 * (C) 2016 Christoph "criztovyl" Schulz
 * GPLv3 and later.
 * Part of studienplan5, a util to convert HTMLed-XLS Studienplände into iCal files.
 * https://github.com/criztovyl/studienplan5
 */

// Data w/ JS classes instead of JSON objects.
// 0 - keys, Clazz
// 1 - values, Clazz-es, key's parents
// 2 - events, key's events
var classes,
    // directory ical files are located in
    ical_dir,
    // whether ical files contain elements of all parents
    unified,
    // events list from data.json
    events,
    // classes as a hashmap
    classesTable;
    // Whether we need to check for Clazz#full_name is set (for <select> opts)
    checkForFull;

function Clazz(name, course, cert, jahrgang, group){
    this.name = name;
    this.course = course;
    this.cert = cert;
    this.jahrgang = jahrgang;
    this.group = group;
    this.isClazz = true;
}

Clazz.Jahrgang = function(name){
    return new Clazz(undefined, undefined, undefined, name);
}

Clazz.from_json = function(json){
    if(json["json_class"] == "Clazz"){
        var v = json["v"];
        return new Clazz(v[0], v[1], v[2], v[3], v[4])
    }
    else {
        console.warn(json["json_class"] + " is not a Clazz!");
        //console.log("-");
        //console.debug(json);
        return false;
    }
}

// Make hashCode and equals "static" for use by Clazz internally and Hashtable.
// Hashtable is faster when you give a equality and hash function to it.

Clazz.hashCode = function(clazz){
    return 'Clazz-7LrCVhVi:' + [clazz.group, clazz.name, clazz.cert, clazz.course, clazz.jahrgang].join(',');
}

Clazz.equals = function(clazz, other){
    return clazz.name == other.name &&
        clazz.course == other.course &&
        clazz.cert == other.cert &&
        clazz.jahrgang == other.jahrgang &&
        clazz.group == other.group;
}

Clazz.prototype = {
    simple: function(no_jahrgang_for_class){
        if(this.full_name() != undefined){
            var str = this.full_name();
            if(no_jahrgang_for_class == undefined)
                str += "(" + this.full_jahrgang() + ")";
            return str;
        }
        else if (this.jahrgang != undefined){
            return this.full_jahrgang();
        }
        else{
            return "";
        }
    },
    full_name: function(){
        if(this.name != undefined){
            if(this.group != undefined){
                return this.name + "-" + this.group;
            }
            else{
                return this.name;
            }
        }
        else{
            return undefined;
        }
    },
    full_jahrgang: function(){
        if(this.jahrgang != undefined){
            if(this.course != undefined){
                return this.jahrgang + "(" + this.course + ")";
            }
            else{
                return this.jahrgang;
            }
        }
        else {
            return undefined;
        }
    },
    ical_file_name: function(){
        var name = this.jahrgang;
        if (this.full_name() != undefined)
            name += "-" + this.full_name();
        if(this.course != undefined)
            name += "-" + this.course;
        if(this.cert != undefined)
            name += "-" + this.cert;

        if(unified)
            name += ".unified";

        return name + ".ical";
    },
    ical_file_link: function(into){

        var loc, webcal_url, ical_link, links, container;

        loc = location.href.split("/"); loc.pop();
        webcal_url = loc.join("/").replace(/https?:\/\//, "webcal://");

        ical_link = sprintf("%s/%s", ical_dir, this.ical_file_name());

        links = $("<span>");

        container = $("<p>").html(this.simple(false) + ": <br/>").appendTo(links);

        $("<label>").html("URL: ").appendTo(container);
        $("<input>").attr({"type": "text", "value": window.location.origin + window.location.pathname + ical_link, "disabled": "true"}).appendTo(container);
        $(container).append("<br>");
        $("<a>").attr({"href": ical_link, "target": "_blank"}).html(".ics herunterladen").appendTo(container);
        $(container).append("<br>");
        $("<a>").attr({"href": sprintf("%s/%s/%s", webcal_url, ical_dir, this.ical_file_name()), "target": "_blank"}).html("webcal öffnen (Outlook)").appendTo(container);

        $(container).appendTo(links);

        if(into != undefined){
            $(links).appendTo(into);
            return into;
        }
        else
            return links;
    },
    equals: function(clazz){
        return Clazz.equals(this, clazz);
    },
    parent: function(){

        var ret = _.clone(this);

        if(this.group)
            ret.group = null
        else if(this.name)
            ret.name = null
        else if(this.cert)
            ret.cert = null
        else if(this.course)
            ret.course = null
        else if(this.jahrgang)
            ret = null

        return ret;
    },
    hashCode: function(){
       return Clazz.hashCode(this);
    }
}

function loadClasses(default_ical_dir){
    $.ajax("classes.json").done(function(data){
        console.log("Loaded classes");

        var keyys, values, loadEvents = true;

        var json_data_version = data.json_data_version.split("."); // 0 - major, 1 - minor

        if (json_data_version[0] == "1"){

            if(Number(json_data_version[1]) >= 1){
                ical_dir = data.ical_dir;
                unified = data.unified;
                default_ical_dir && console.info("Called loadClasses with a parameter but classes.json is new enough.");
            }
            else {
                ical_dir = default_ical_dir || "ical";
                unified = false;
            }

            switch(Number(json_data_version[1])){
                case 4:
                   checkForFull = true;
                case 3:
                    loadEvents = data.load_events;
                case 2:
                    if(data.data.json_object_keys){
                        keyys = data.data.keys;
                        values = data.data.values;
                    }
                    else {
                        console.error("Is no object with json_object_keys!");
                    }
                    break;
                case 1:

                    if(data.json_object_keys){
                        keyys = data["data"][0];
                        values = data["data"][1];

                    }
                    else {
                        console.error("Stringified keys are not supportet yet.");
                    }
                    break;
                default:
                    console.error("Unsupported 1.x version.");
                    break;

            }
        }
        else {
            console.error("Unknown/Unspported JSON data version: " + json_data_version.join("."));
        }

        // Magic happens here: undo JSON object keys.
        if(keyys){
            var populate_func = function(data_evts){

                events = data_evts;
                console.log("Loaded events");

                $(document).ready(function(){

                    // 0 - keys, Clazz
                    // 1 - values, Clazz-es, key's parents
                    // 2 - events, key's events
                    classes = [[], [], []];
                    classesTable = new Hashtable(Clazz.hashCode, Clazz.equals);

                    var select = $(".inner.cover#usage select").first();

                    // This popultates both the classes var and the HTML select, why to two loops when we can do one?

                    console.log("Document ready");

                    select.html("");
                    $("<option>").html("Bitte auswählen...").attr("value", -1).appendTo(select);

                    $.each(keyys, function(index, element){

                        var o_key = Clazz.from_json(element), // Key as Clazz Object
                            o_parents = [],
                            o_events = [],
                            // out-of-loop var to not re-allocate it each loop
                            clazz;

                        classes[0].push(o_key);
                        if(!checkForFull || o_key.full_name())
                            $("<option>").html(o_key.full_name()).attr("value", index).appendTo(select);

                        // Outer "index" is a numeric key, no index. "values" is an Object no Array.
                        $.each(values[index], function(index, element){

                            clazz = Clazz.from_json(element)

                            o_parents.push(clazz);
                            classes[0].push(clazz);
                        });

                        o_events = _.filter((events && events.data) || [], function(o){
                            return Clazz.from_json(o.class).equals(o_key);
                        })

                        classes[1].push(o_parents);
                        classes[2].push(o_events);

                        if(!classesTable.containsKey(o_key))
                            classesTable.put(o_key, { parents: o_parents, events: o_events });
                        else {
                            value_container = classesTable.get(o_key);
                            value_container.parents = value_container.parents.concat(o_parents);
                            value_container.events = value_container.events.concat(o_events);
                        }

                    });

                    $.each(classes[2], function(index, events){
                        $.each(events, function(index, event){
                            event.class = Clazz.from_json(event.class);
                        });
                    });

                    $(select).removeAttr("disabled");
                    $(select).on("change", classSelect);

                    if(getHashSelection() && select && select[0]){
                        $(select)[0].selectedIndex = Number(getHashSelection());
                        console.log("loadClasses / Hash Selection:");
                        console.log(getHashSelection());
                        $(select).change();
                    }

                });
            }

            if(loadEvents)
                $.get("data.json").done(function(data){
                    populate_func(data);
                }).fail(function(){
                    populate_func(undefined);
                });
            else{
                console.log("Configured not to load data.json.");
                populate_func(undefined);
            }

        }
        else {
            console.error("Could not process classes! (empty)");
        }
    });
}

$(document).ready(function(){

    $(".nojs").hide();
    $(".inner.cover").hide();
    $(".inner.cover#home").show();
    $(".nav li#curr-home").addClass("active");

    $(window).on("hashchange", hashChange);

    hashChange();

    // protected email script by Joe Maller
    // modified by Christoph Schulz, 2016 (For the super paranoid)
    // // JavaScripts available at http://www.joemaller.com
    // // this script is free to use and distribute
    // // but please credit me and/or link to my site
    //
    var cloaked = 'join' + 'out' + '.com';
    cloaked = cloaked.replace(".com", ".de");
    cloaked = ('ch' + '.schulz' + '@' + cloaked);
    $("#contact #mail a").attr("href", "mailto:" + cloaked).html(cloaked);

});

var noHashChange = 0;
function hashChange(evt){

    if(noHashChange == 0){

        console.log("Hash change!");

        var target = window.location.hash; // Location hash incl. #. Keep it.

        if(String(target)){
            $(".inner.cover").hide();

            var selection_match = target.match(/-selection-(\d+)$/);

            // Remove selection string from target
            if(selection_match) target = target.replace(selection_match[0], "");

            $(".inner.cover"  + target).show();
            $(".nav li.active").removeClass("active");
            $(".nav li#curr-" + target.replace("#", "")).addClass("active");

            if(selection_match){
                var select = $(".inner.cover#usage select");
                if(select && select[0] && !select[0].disabled){
                    console.log("hashChange / getHashSelection:");
                    console.log(getHashSelection());
                    $(select)[0].selectedIndex = Number(getHashSelection());
                    $(select).change();
                }
            }
        }
    }
    else {
        console.log("noHashChange +" + (noHashChange-1));
        noHashChange--;
    }
}

var hashSelectionRE = /-selection-(\d+)$/;

function getHashSelection(){
    var match = document.location.hash.match(hashSelectionRE);
    return match ? match[1] : match // It's undefined? Return undefined.
}

function setHashSelection(selectedIndex){
    noHashChange = 2;
    removeHashSelection();
    location.hash = location.hash + "-selection-" + selectedIndex;
}

function removeHashSelection(){
    location.hash = location.hash.replace(hashSelectionRE, "");
}
function classSelect(){

    var target = $($(".inner.cover#usage #icals ul#cal-links"))
    target.html("");

    if(String(this.value) && this.value != -1){

        classes[0][this.value].ical_file_link($("<li>")).appendTo(target);

        if(!unified){
            $.each(classes[1][this.value], function(index, element){
                element.ical_file_link($("<li>")).appendTo(target);
            });
        }

        $(".inner.cover#usage #icals").show();
        setHashSelection(this.selectedIndex);
    }
    else{
        $(".inner.cover#usage #icals").hide();
        console.log("select.value -1");
    }
}
