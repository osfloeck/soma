/*
    builtins.odin
    Provides basic functions for templating engine
*/

#+vet explicit-allocators

package soma

import "core:fmt"
import "core:strings"
import "core:strconv"

Date :: struct {
	day: u16,
	month: u16,
	year: u16
}

Value :: union {
	string,
	[]string,
	int,
	bool,
	Date
}

MONTH_NAMES := [13]string {
	"", "January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
}

WEEKDAY_NAMES := [7]string {
	"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
}

Built_In_Function :: #type proc(value: Value) -> string


/*
    Formats date
    19-01-2026 -> Sunday, 19th January 2026
*/
format_date :: proc(value: Value) -> string {
	#partial switch variant in value {
		case Date:
			weekday := WEEKDAY_NAMES[_weekday_index(variant)]
			month := MONTH_NAMES[variant.month]
			suffix := _ordinal_suffix(variant.day)
			return fmt.tprintf("%s, %d%s %s %d", 
				weekday, variant.day, suffix, month, variant.year)
		case:
			fmt.printfln("soma (err): wrong type passed to format_date()")
			return ""
	}
}

/*
    Uppercases text
    test_case -> TEST_CASE
*/
uppercase :: proc(value: Value) -> string {
	#partial switch varient in value {
		case string:
			return strings.to_upper(varient, context.allocator)
		case:
			fmt.printfln("soma (err): passed non-string to `uppercase` builtin")
			return ""
	}
}

/*
    Reduces content of text to less than
    100 characters
    TODO(oskar): make word aware
*/
brief :: proc(value: Value) -> string {
	#partial switch variant in value {
		case string:
		if len(variant) < 100 {
        	return variant
    	}
		return variant[:100]
		case:
			fmt.printfln("soma (err): passed non-string to `brief` builtin")
			return ""
	}
}

_parse_iso_date :: proc(text: string) -> (Date, bool) {
	// TODO(oskar): validate month, year date etc
	if len(text) != 10 || (strings.count(text, "-") != 2) {
		fmt.printfln("soma (err): Error parsing iso date `%v`", text)
		return Date{}, false
	}

	parts := strings.split_after_n(text, "-", 3, context.allocator)
	parsed_day, _ := strconv.parse_int(parts[1], 10)
	parsed_month, _ := strconv.parse_int(parts[2], 10)
	parsed_year, _ := strconv.parse_int(parts[0], 10)

	return Date{
		day = cast(u16)parsed_day,
		month = cast(u16)parsed_month,
		year = cast(u16)parsed_year
	}, true
}

_weekday_index :: proc(date: Date) -> u16 {
	// Sakamoto's method
	month_offsets := [12]u16{0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4}
	year := date.year
	if date.month < 3 {
		year -= 1
	}
	return (year + year / 4 - year / 100 + year / 400 + month_offsets[date.month - 1] + date.day) % 7
}

_ordinal_suffix :: proc(day: u16) -> string {
	if 11 <= day && day <= 13 {
		return "th"
	}
	switch day % 10 {
	case 1:
		return "st"
	case 2:
		return "nd"
	case 3:
		return "rd"
	case:
		return "th"
	}
}
