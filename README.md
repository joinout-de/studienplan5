# studienplan5.rb
A utility to convert HTMLed-XLS Studienpläne into iCals.

It's under heavy development, so please take a look at other [branches](https://github.com/joinout-de/studienplan5/branches).

## Requirements

 - Nokogiri
 - iCalendar

With [Bundler](https://bundler.io/):

    $ bundler install


## XLS -> HTML

Use LibreOffice. My version\* also exports comments.

    loffice --convert-to html XLS_file

or

    soffice --convert-to html XLS_file


\* LibreOffice 5.1.2.1.0 10m0(Build:1)

## Usage

    Usage: ./studienplan5.rb [options] [FILE]

    FILE is a HTMLed XLS Studienplan.
    FILE is optional to be able to do -w/--web without reparsing everything.

        -c, --calendar                   Generate iCalendar files to "ical" directory. (Change with --calendar-dir)
        -j, --json                       Generate JSON data file (data.json).
        -d, --classes                    Generate JSON classes structure (classes.json).
        -o, --output NAME                Specify output target, if ends with slash, will be output directory. If not, will be name of calendar dir and suffix for JSON files.
        -k, --disable-json-object-keys   Stringify hash keys.
        -p, --json-pretty                Write pretty JSON data.
        -w, --web                        Export simple web-page for browsing generated icals. Does nothing unless -o/--output is a directory.
        -n, --calendar-dir NAME          Name for the diretory containing the iCal files. Program exits status 5 if -o/--output is specified and not a directory.
        -u, --disable-unified            Do not create files that contain all parent events recursively.
        -a, --disable-apache-config      Do not export .htaccess and other Apache-specific customizations.
        -h, --help                       Print this help.

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

#### 1.04
* Now exports all `Clazz` objects that appear in events. Previosly exported only "full" Classes, i.e. with all of `NAME`, `COURSE`, `CERT` and `JAHRGANG` set.

#### 1.02
* `PlanElement` was replaced by an standard object. Well-known keys:
   * Strings: title, room, time, more, special
   * Clazz: class
* The file "headers" no longer contains `json_object_keys`, moved to the object that has the object keys.

#### 1.01
Soon.

## Contribute

Use a combination of the [git flow](http://nvie.com/posts/a-successful-git-branching-model/), [git rebase](https://randyfay.com/node/91) and [GitHub](https://guides.github.com/introduction/flow/) workflows.

0. [Fork](https://github.com/criztovyl/studienplan5/fork) and clone the repo (GitHub worklow)
0. Create a new branch off `develop`, e.g. `myfeature` (git-flow workflow)
0. ...do work....
0. Fetch `develop` from upstream to download code updates (git-rebase workflow)
0. Rebase your branch on `develop` to apply the code updates to your base code (git-rebase workflow; If nothing changed on `develop` that will do nothing)
0. Push `myfeature` to upload your changes (any workflow)
0. Create a pull request. (GitHub workflow)

For the lazy ones:  
(Unless you use Two-Factor Auth, then you have to add `-H "X-GitHub-OTP: CODE"` with your OTP code instead of `CODE` to `curl`) 

    read -p "GitHub username: " GHUSER
    curl https://api.github.com/repos/criztovyl/studienplan5/forks -d '{}' -u $GHUSER
    git clone https://github.com/$GHUSER/studienplan5.git studienplan5
    cd $_
    git checkout -b myfeature develop
    # ... do work, commits, etc... If you're done continue below.
    git fetch origin
    git rebase origin/develop
    git push

## Author

Christoph "criztovyl" Schulz

 - [GitHub](https://github.com/criztovyl)
 - [Blog](https://criztovyl.joinout.de)
 - [Twitter @criztovyl](https://twitter.com/criztovyl)

## License
GPLv3 and later.

## <3

    <3
