# studienplan5.rb
A utitily to convert HTMLed-XLS studienpläne into iCals.

## Requirements

 - Nokogiri
 - iCalendar

## XLS -> HTML

Use LibreOffice. My version (LibreOffice 5.1.2.1.0 10m0(Build:1)) also exports comments.

    loffice --convert-to html [XLS file]

## Usage

    ./studienplan5.rb [htmled-xls-file]

Will put the iCals in `icals` directory.

## Author

Christoph "criztovyl" Schulz

 - [GitHub](https://github.com/criztovyl)
 - [Blog](https://criztovyl.joinout.de)
 - [Twitter @criztovyl](https://twitter.com/criztovyl)

## License
GPLv3 and later.

## <3

    <3
