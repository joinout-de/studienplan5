# studienplan5.rb
A utility to convert HTMLed-XLS Studienpläne into iCals.

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
Below the format of `data.json` and `classes.json`. For the value definitions see below.

### data.json
Contains all events in `data`.

    {
        json_data_version: VersionString,
        generated: TimeString,
        data:  [
            Element,
            Element,
            Element,
            ...
        ]
    }

### classes.json
Contains all classes (keys) and their parents (value array elements) in `data`. Header also contains the name of the iCalender directory and whether iCalendar files are "unified" (i.e. contain events from all parents).

    {
        json_data_version: VersionString,
        generated: TimeString,
        ical_dir: String,
        unified: Boolean,
        data: {
            Clazz: [ Clazz, Clazz, ... ],
            Clazz: [ Clazz, Clazz, ... ],
            Clazz: [ Clazz, Clazz, ... ],
            ...
        }
    }

`Clazz` is an object, but JSON does not support object as keys, see next:

### JSON object keys
Any object that has a `json_object_keys` set to true has the following structure:

    {
        json_object_keys: true,
        keys: [
            key,
            key,
            key,
            ...
        ],
        values: {
            key_index: value,
            key_index: value,
            key_index: value,
            ...
        }
    }

### Values

* `VersionString`: String.
    - "major.minor"
* `TimeString`: String.
    - "%Y-%m-%d %H:%M:%S %z" (strftime)
* `Element`: Object. Well-known keys (expect `null` values):
    - title: String, never `null`
    - class: `Clazz`, never `null`
    - room: String
    - time: String, never `null`
    - dur: String, Rationale, e.g. `"3/4"`; Duration (either this or `special: "fullWeek"` is always set)
    - lect: String; Lecturer
    - nr: String, Integer; Event number (#1, #2, ...)
    - special: Currently only `"fullWeek"` (String, Symbol) to indicate event from Mon-Fri. (either this or `dur` is always set)
    - more: String; Comment.
* `Clazz`. Object.
    - `{ "json_class": "Clazz", "v": [ NAME, COURSE, CERT, JAHRGANG, GROUP ] }`
    - `NAME`: String; Class name
    - `COURSE`: String; "BSc" or "BA"
    - `CERT`: String; "Fachberater", i.e. "FST", "FIS"
    - `JAHRGANG`: String; Name of the group of classes entered the training/studies in the same year.
    - `GROUP`: String; Group ID withing Jahrgang (one char)
* `ClazzString`: String.
    - `Clazz` as String, see above.
    - `Jahrgang JAHRGANG, NAME, Course COURSE, Cert. CERT` (`NAME`, `COURSE` and `CERT` are optional and can be missing, including corresponding text and comma)

### Version history

#### 1.02
* `PlanElement` was replaced by an standard object. Well-known keys:
   * Strings: title, room, time, more, special
   * Clazz: class
* The file "headers" no longer contains `json_object_keys`, moved to the object that has the object keys.

#### 1.01
Soon.

## Author

Christoph "criztovyl" Schulz

 - [GitHub](https://github.com/criztovyl)
 - [Blog](https://criztovyl.joinout.de)
 - [Twitter @criztovyl](https://twitter.com/criztovyl)

## License
GPLv3 and later.

## <3

    <3
