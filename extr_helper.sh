#!/usr/bin/env bash
# Part of studienplan5
# GPLv3 or later
# Christoph 'criztovyl' Schulz, 2016

# Completition for bash in extr_helper.bash_completition.

###
# 1 - Declarations
# 2 - Functions
# 3 - CLI

# 1 - Declarations

DATA_DIR="data"

SRC_DIR="$DATA_DIR/src"
CONV_DIR="$DATA_DIR/conv"

HTML_DIR="$CONV_DIR/html"
XLS_DIR="$SRC_DIR/xls"
PDF_DIR="$SRC_DIR/pdf"
JSON_DIR="$CONV_DIR/json"

# If those constants are not set, tries to read from environment EXTR_HELPER_(NAME).
TABULA_JAR=""
LOFFICE="loffice"
MOODLE_DL_USER=

EXIT_OK=0
EXIT_HELP=6
EXIT_NO_SUCH_FILE=1
EXIT_MOODLE_NON_XLS=2
EXIT_AUSBPLAN_NON_PDF=3
EXIT_MOODLE_ALREADY_THERE=4
EXIT_AUSBPLAN_ALREADY_THERE=5
EXIT_MISSING_TABULA_JAR=7

trap "exit" "SIGINT"

# 2 - Functions

display_usage() {

    # Args: fullhelp
    # fullhelp - non-empty = true

    fullhelp=$1

    echo "Usage: $0 extractor file [force|overwrite|reparse]"

    if [ "$fullhelp" ]; then
        echo
        echo "Copies the file to it's corresponding directory in $SRC_DIR, with unique prefix"
        echo "Extracts the data from the file, and stores output in corresponding directory in $CONV_DIR"
        echo
        echo "Extractors: moodle moodle-dl ausbplan|ausb_plan|ausbildungsplan"
        echo
        echo "  moodle extracts from XLS file, aka ABB_Gesamtplan_Moodle.xls"
        echo "  moodle-dl downloads the file from moodle (user and pw required) and then calls the above on the downloaded file."
        echo "  ausbildungsplan extracts from Ausbildungsplan_[...].pdf"
        echo
        echo "force disables extr_helper check for the correct filetype"
        echo "overwrite overwrites files that already exist in the corresponding $SRC_DIR"
        echo "reparse reparses the file if it already exists in the corresponding $SRC_DIR"
        echo
        echo "moodle, moodle-dl: $XLS_DIR/file.xls -- LibreOffice --> $HTML_DIR/file.html"
        echo "ausbildungsplan  : $PDF_DIR/file.pdf --   Tabula    --> $JSON_DIR/file.json"
    fi

    exit $EXIT_HELP
}

already_there_msg()
{
    # Args: exit_code
    echo "File already exists in src. :)" >&2
    echo "Use \"overwrite\" or \"reparse\" as third argument to overwrite resp. reparse the file." >&2
    exit $exit
}

copy_src_file()
{
    # Args: src file must_exist callback force reparse
    # force - non-empty -> true
    src=$1
    src_dir=`dirname "$src"`
    src_name=`basename "$src"`

    file=$2
    file_dir=`dirname "$file"`
    file_name=`basename "$file"`

    must_exist=$3
    callback=$4
    force=$5
    reparse=$6

    if [ ! -f "$file_dir/$src_name" ] || ! cmp "$src" "$file_dir/$src_name" || [ $force ]; then
        cp "$src" "$file"
        ( cd "$file_dir" && ln -fs "$file_name" "$src_name" )
        $callback "$src" "$file"
    elif [ ! -f "$must_exist" ]; then
        ( cd "$file_dir" && ln -s "$src_name" "$file_name" )
        $callback "$src" "$file"
        rm -f "$file"
    elif [ $reparse ]; then
        $callback "$src" "$file"
    else
        return 1
    fi
}

replace_suffix()
{
    # Args: string suffix_replace
    echo ${1/%.${1##*.}/$2}
}

check_file()
{
    # Args: file mimeExpected name force
    local file=$1
    local mime=$2
    local name=$3
    local force=$4

    local filemime=`file --mime-type -b "$(realpath "$file")"`

    [[ "$filemime" == "$mime" ]] || [ $force ] || { echo -e "$name expects a $mime file, but $file is \"$filemime\".\nUse \"force\" as third argument to force extraction." >&2; return 1; }
}

file_existance_check()
{
    [ ! -f "$Src" ] && { echo "No such file \"$Src\"!"; exit $EXIT_NO_SUCH_FILE; }
}

# 3 - CLI

# Help
[[ "$0" =~ ^-{1,2}h(elp)?$ ]] || [ -z "$1" ] || [ -z "$2" ] && { display_usage full; }

Action=$1
Src=$2
Third=$3

Force=
Overwrite=
Reparse=

case $Third in
    force)
        Force=1
        ;;
    overwrite)
        Overwrite=1
        ;;
    reparse)
        Reparse=1
        ;;
esac


[ -z "$TABULA_JAR" ] && [[ "$EXTR_HELPER_TABULA_JAR" ]] && TABULA_JAR=$EXTR_HELPER_TABULA_JAR
[ -z "$LOFFICE" ] && [[ "$EXTR_HELPER_LOFFICE" ]] && LOFFICE=$EXTR_HELPER_LOFFICE
[ -z "$MOODLE_DL_USER" ] && [[ "$EXTR_HELPER_MOODLE_DL_USER" ]] && MOODLE_DL_USER=$EXTR_HELPER_MOODLE_DL_USER

[ -z "$TABULA_JAR" ] && { echo >&2 "Missing tabula jar file! Please set EXTR_HELPER_TABULA_JAR."; exit $EXIT_MISSING_TABULA_JAR; }

mkdir -p $DATA_DIR $HTML_DIR $XLS_DIR $PDF_DIR $JSON_DIR

Src_Name=`basename "$Src"`
New_Src_Name=`date +%Y-%m-%d-%s`_$Src_Name
LO_Tmpdir=`mktemp -d /tmp/libreoffice-XXXXXXXXXXXX`

trap "rm -rf $LO_Tempdir" EXIT INT

case "$Action" in
    moodle-dl)

        Cookie_File=`mktemp`
        Download_Target=`mktemp -d`

        [[ "$MOODLE_DL_USER" ]] || { echo "Missing download user. Is EXTR_HELPER_MOODLE_DL_USER set?" >&2; exit $EXIT_MISSING_DL_USER; }

        password=$( EXTR_HELPER_MOODLE_DL_PASSASK 2>/dev/null || { read -sp "Moodle Password for $MOODLE_DL_USER: " && echo $REPLY; } )

        curl --cookie-jar "$Cookie_File" --cookie "$Cookie_File" \
            --data username=$MOODLE_DL_USER --data "password=$password" \
            --location \
            https://siemens.lernvision.de/login/index.php $Src \
            --output /dev/null --output "$Download_Target/$Src_Name"

        bash $0 moodle "$Download_Target/$Src_Name"
        ;;
    moodle)

        file_existance_check
        check_file $Src "application/vnd.ms-excel" "Moodle" $Force || exit $EXIT_MOODLE_NON_XLS


        parse_moodle_xls()
        {
            src_name=`basename "$1"`
            xls_file=$2

            echo "Extracting w/ LibreOffice can take a moment."

            # https://ask.libreoffice.org/en/question/1686/how-to-not-connect-to-a-running-instance/
            ${LOFFICE:-loffice} "-env:UserInstallation=file://$LO_Tmpdir" --convert-to html "$xls_file" --outdir "$HTML_DIR"

            ( cd "$HTML_DIR" && ln -fs "`basename "$(replace_suffix "$xls_file" .html)"`" "$(replace_suffix "$src_name" .html)"; )
        }

        copy_src_file "$Src" "$XLS_DIR/$New_Src_Name" "$HTML_DIR/$(replace_suffix "$Src_Name" .html)" parse_moodle_xls $Overwrite $Reparse || echo `already_there_msg $EXIT_MOODLE_ALREADY_THERE`
        ;;
    ausbplan|ausb_plan|ausbildungsplan)

        file_existance_check
        check_file $Src "application/pdf" "Ausbildungsplan" $Force || exit $EXIT_AUSBPLAN_NON_PDF

        pdf_file= # TODO Is this still required?

        parse_ausbplan_pdf()
        {
            src_name=`basename "$1"`
            pdf_file=$2

            json_file=$JSON_DIR/$(replace_suffix "$New_Src_Name" .json)

            # https://github.com/tabulapdf/tabula-java (Pure Java) or https://github.com/tabulapdf/tabula-extractor (JRuby)
            # -l -> --lattice (it's a spreadsheet)
            # -f -> --format (the output format, JSON for us)
            # -u -> --use-line-returns (tabula ignores line returns by default)
            java -jar ${TABULA_JAR} -l -u -f JSON "$pdf_file" > "$json_file"

            # tabula seems to produce invalid JSON, each row is interpreted as seperate spreadsheet with an single row as
            # an [[element, element, element]] array, but they are not seperated by an ",", so there is [[...]][[...]][[...]]...)
            # TODO Check if only ][ or also ][][

            # Make Valid: Replace ]][[ with ],[
            sed 's/\]\]\[\[/\],\[/g' -i "$json_file"

            ( cd "$JSON_DIR" && ln -fs "`basename "$json_file"`" "$(replace_suffix "$src_name" .json)" )
        }

        copy_src_file "$Src" "$PDF_DIR/$New_Src_Name" "$JSON_DIR/$(replace_suffix "$Src_Name" .json)" parse_ausbplan_pdf $Overwrite || already_there_msg $EXIT_AUSBPLAN_ALREADY_THERE

        ;;
    *)
        display_usage
        ;;
esac
