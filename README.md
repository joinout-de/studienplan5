# studienplan5.rb
A utitily to convert HTMLed-XLS Studienpläne into iCals.

## Requirements

 - Nokogiri
 - iCalendar

## XLS -> HTML

Use LibreOffice. My version\* also exports comments.

    loffice --convert-to html XLS_file

or

    soffice --convert-to html XLS_file


\* LibreOffice 5.1.2.1.0 10m0(Build:1)

## Usage

Please see `ruby studienplan5.rb --help`.

## JSON data file format

    {
        json_object_keys: Bool,
        json_data_version: "x.y",
        generated: "%Y-%m-%d %H:%M:%S %z",
        data:  ...
    }

### When `json_object_keys` is true
...`data` is an nested Array. At index 0 are the real keys, at index 1 is the hash where the keys are the index of the real key.
This is for preserving the Hash key objects. (JSON does not allow objects as keys)


    [
        [
            class,
            class,
            ...
        ],
        {
            0: [
                element,
                element,
                ...
            ],
            1: [
                element,
                element,
                ...
            ],
            ...
        }
    ]

 - `element` is `{ "json_class": "PlanElement", "v": [ TITLE, CLASS, ROOM, TIME, DUR, LECT, NR, SPECIAL, MORE ] }`
  + `class`/`CLASS` is `{ "json_class": "Clazz", "v": [ NAME, COURSE, CERT, JAHRGANG, GROUP ]`

### When it's false
...`data` is a hash, the keys are stringified as described below and the values are list's of `element`s, as the values above.

    {
        class: [
            element,
            element,
            ...
        ],
        class: [
            element,
            element,
            ...
        ],
        ...
    }

`class` is `Jahrgang JAHRGANG, CLASS, Course COURSE, Cert. CERT` (CLASS, COURSE and CERT are optional and can be missing, including corresponding text and comma)

### Values

 - TITLE: String
 - CLASS: `class` or String
 - ROOM: String
 - TIME: %Y-%m-%d %H:%M:%S %z
 - DUR: String (Rationale, i.e "3/4")
 - LECT: String; Lecturer
 - NR: String; Event number (#1, #2, ...)
 - SPECIAL: String; Currently only "fullWeek" to indicate event from Mon-Fri.
 - MORE: String; Comment.

 - NAME: String; Class name
 - COURSE: String; "BSc" or "BA"
 - CERT: String; "Fachberater", i.e. "FST", "FIS"
 - JAHRGANG: String; Name of the group of classes entered the training/studies in the same year.
 - GROUP: String; Group ID withing Jahrgang (one char)

## Author

Christoph "criztovyl" Schulz

 - [GitHub](https://github.com/criztovyl)
 - [Blog](https://criztovyl.joinout.de)
 - [Twitter @criztovyl](https://twitter.com/criztovyl)

## License
GPLv3 and later.

## <3

    <3
