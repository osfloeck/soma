/*
    builtins.odin
    Provides basic functions for templating engine
*/

#+vet explicit-allocators

package soma

import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:time"

Date :: struct {
	day: int,
	month: int,
	year: int
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
    2026-01-19 -> Sunday, 19th January 2026
*/
format_date :: proc(value: Value) -> string {
	#partial switch variant in value {
		case Date:
			weekday := WEEKDAY_NAMES[_weekday_index(variant)]
			month := MONTH_NAMES[variant.month]
			suffix := _ordinal_suffix(variant.day)
			return fmt.tprintf("%s, %d%s %s %d", 
				weekday, variant.day, suffix, month, variant.year)
		case string:
			// Likely in a template rendering a date
			parsed, ok := _parse_iso_date(variant)
			if ok { 
				return format_date(parsed) 
			} else {
				return "YYYY-MM-DD"
			}
		case:
			fmt.printfln("soma (err): wrong type passed to format_date()")
			return "YYYY-MM-DD"
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

_date_after :: proc(a, b: Date) -> bool {
    if a.year != b.year {
        return a.year > b.year
    }

    if a.month != b.month {
        return a.month > b.month
    }

    return a.day > b.day
}

_parse_iso_date :: proc(date_raw: string) -> (Date, bool) {
	/* The international ISO 8601 standard for dates is YYYY-MM-DD
	   which writes May 25, 2021, as 2021-05-25 */
	text := strings.trim(date_raw, "\"")
	
	if len(text) != 10 || (strings.count(text, "-") != 2) {
		fmt.printfln("soma (err): invalid iso date `%v`", text)
		return Date{}, false
	}
	
	parts := strings.split(text, "-", context.allocator)
	parsed_year, year_ok := strconv.parse_int(parts[0], 10)
	parsed_month, month_ok := strconv.parse_int(parts[1], 10)
	parsed_day, day_ok := strconv.parse_int(parts[2], 10)

	if !year_ok || !month_ok || !day_ok {
		fmt.printfln("soma (err): non-numeric component in date `%v`", text)
		return Date{}, false
	}

	if (parsed_year > 9999) || (parsed_month > 12) || (parsed_day > 31) ||
	   (parsed_year < 1500) || (parsed_month < 1)  || (parsed_day < 1) {
		fmt.printfln("soma (err): invalid date `%v`", text)
		return Date{}, false
	}

	return Date{day = parsed_day, month = parsed_month, year = parsed_year}, true
}

_weekday_index :: proc(date: Date) -> int {
	// Sakamoto's method
	month_offsets := [12]int{0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4}
	year := date.year
	if date.month < 3 {
		year -= 1
	}
	return (year + year/4 - year/100 + year/400 + month_offsets[date.month - 1] + date.day) % 7
}

_ordinal_suffix :: proc(day: int) -> string {
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
