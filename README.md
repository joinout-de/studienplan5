# studienplan5.rb
A utility to convert ugly plans, grouped by classes.

## Requirements

 - Nokogiri (`gem install nokogiri`)
 - iCalendar (`gem install icalendar`)
 - tzinfo (`gem install tzinfo`)
 - tzinfo-data (`gem install tzinfo-data`)

With [Bundler](https://bundler.io/):

    $ bundler install

## Usage

    Usage: ./studienplan5.rb [options]

    Extractors:
      --semplan file
      --ausbplan file
    For usage see below.

        -c, --calendar                   Generate iCalendar files to "ical" directory. (Change with --calendar-dir)
        -j, --json                       Generate JSON data file (data.json).
        -d, --classes                    Generate JSON classes structure (classes.json).
        -o, --output NAME                Specify output target, if ends with slash, will be output directory. If not, will be name of calendar dir and prefix for JSON files.
        -p, --json-pretty                Write pretty JSON data.
        -n, --calendar-dir NAME          Name for the diretory containing the iCal files. Program exits status 5 if -o/--output is specified and not a directory.
        -u, --[no-]unified               Do (not) create files that contain all parent events recursively. Default: Create.
        -s, --simulate                   Simulate, do not write files or create directories.
        -q, --quiet                      Do not print data.
        -l, --level [LEVEL]              Log level (fatal, error, warn, info, debug)
            --[no-]load-events           Set the flag (not) to load data.json. Flag is in classes.json. Default: Set/Load.
            --[no-]extr-config           Do (not) read extr_helper.yml. Default: Read.
            --[no-]all-ics               Do (not) write an ICS file containing all events. Default: Do not write.
            --semplan FILE               Extract data from a HTMLed XLS Studienplan. Use extr_helper for XLS -> HTML.
            --ausbplan FILE              Extract data from a JSONed PDF Ausbildungsplan. Use extr_helper for PDF -> JSON.
        -h, --help                       Print this help.

## Converting files

Use `extr_helper.sh`:

To use PDF extraction dowload the tabula `...-jar-with-dependencies.jar` and set `EXTR_HELPER_TABULA_JAR` to the JAR's file path.

    Usage: ./extr_helper.sh extractor file [force|overwrite|reparse]

    Copies the file to it's corresponding directory in data/src, with unique prefix
    Extracts the data from the file, and stores output in corresponding directory in data/conv

    Extractors: moodle moodle-dl ausbplan|ausb_plan|ausbildungsplan

      moodle extracts from XLS file, aka ABB_Gesamtplan_Moodle.xls
      moodle-dl downloads the file from moodle (user and pw required) and then calls the above on the downloaded file.
      ausbildungsplan extracts from Ausbildungsplan_[...].pdf

    force disables extr_helper check for the correct filetype
    overwrite overwrites files that already exist in the corresponding data/src
    reparse reparses the file if it already exists in the corresponding data/src

    moodle, moodle-dl: data/src/xls/file.xls -- LibreOffice --> data/conv/html/file.html
    ausbildungsplan  : data/src/pdf/file.pdf --   Tabula    --> data/conv/json/file.json

Or convert manually:

 - .pdf: `$ tabula --spreadsheet --use-line-returns --format JSON [PDF_FILE] > [JSON_FILE]`
 - .xls: `$ loffice --convert-to html [XLS_FILE]`

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
Contains all classes (keys) and their parents (value array elements) in `data`. Header also contains the name of the iCalender directory, whether iCalendar files are "unified" (i.e. contain events from all parents) and whether you should load `data.json` (`load_events`).

    {
        json_data_version: VersionString,
        generated: TimeString,
        ical_dir: String,
        unified: Boolean,
        load_events: Boolean,
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

#### 1.04
* Now exports all `Clazz` objects that appear in events. Previosly exported only "full" Classes, i.e. with all of `NAME`, `COURSE`, `CERT` and `JAHRGANG` set.

#### 1.03
* Add `load_events` to `classes.json`.

#### 1.02
* `PlanElement` was replaced by an standard object. Well-known keys:
   * Strings: title, room, time, more, special
   * Clazz: class
* The file "headers" no longer contains `json_object_keys`, moved to the object that has the object keys.

#### 1.01
tbd

## Contribute

0. [Fork](https://github.com/criztovyl/studienplan5/fork) and clone the repo
0. Create a new branch off `develop`, e.g. `myfeature`
0. ...do work....
0. Fetch `develop` from upstream to download code updates
0. Rebase your branch on `develop` to apply the code updates to your base code (If nothing changed on `develop` that will do nothing)
0. Push `myfeature` to upload your changes
0. Create a pull request.

For the lazy ones, simply copy'n'paste:  
(Unless you use 2FA, then you have to add `-H "X-GitHub-OTP: CODE"` with your OTP code instead of `CODE` to `curl`) 

    read -p "GitHub username: " GHUSER
    curl https://api.github.com/repos/criztovyl/studienplan5/forks -d '{}' -u $GHUSER
    git clone https://github.com/$GHUSER/studienplan5.git studienplan5
    cd $_
    git checkout -b myfeature develop
    # ... do work, commits, etc... If you're done continue below.
    git fetch origin
    git rebase origin/develop
    git push

Inspired by [git flow](http://nvie.com/posts/a-successful-git-branching-model/), [git rebase](https://randyfay.com/node/91) and [GitHub](https://guides.github.com/introduction/flow/) workflows.

## Author

Christoph "criztovyl" Schulz

 - [GitHub](https://github.com/criztovyl)
 - [Blog](https://criztovyl.joinout.de)
 - [Twitter](https://twitter.com/criztovyl)

## License
GPLv3 and later.

## <3

    <3
