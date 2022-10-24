package sqlcmd

import (
	"bytes"
	"database/sql"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/google/uuid"
)

// csvFormatter
type csvFormatter struct {
	out             io.Writer
	err             io.Writer
	vars            *Variables
	ccb             ControlCharacterBehavior
	columnDetails   []columnDetail
	ncol            int
	rowcount        int
	writepos        int64
	maxColNameLen   int
	redirectMessage bool
	bytesbuff       *bytes.Buffer
	colsep          string
}

func NewCsvFormatter(redirectmessage bool) Formatter {
	return &csvFormatter{
		redirectMessage: redirectmessage,
		bytesbuff:       new(bytes.Buffer),
	}
}

func (f *csvFormatter) BeginBatch(_ string, vars *Variables, out io.Writer, err io.Writer) {
	f.out = out
	f.err = err
	f.vars = vars
	f.colsep = vars.ColumnSeparator()
	f.logMessage(fmt.Sprintf("%s [I] Begin Batch\n", time.Now().Format(time.RFC3339)))
}

func (f *csvFormatter) EndBatch() {
	f.logMessage(fmt.Sprintf("%s [I] End Batch \n", time.Now().Format(time.RFC3339)))
}

func (f *csvFormatter) BeginResultSet(cols []*sql.ColumnType) {
	f.logMessage(fmt.Sprintf("%s [I] Begin ResultSet\n", time.Now().Format(time.RFC3339)))
	f.rowcount = 0
	f.columnDetails, f.maxColNameLen = calcColumnDetails(cols, f.vars.MaxFixedColumnWidth(), f.vars.MaxVarColumnWidth())
	f.ncol = len(f.columnDetails)
	f.bytesbuff.Reset()
	for i, c := range f.columnDetails {
		if i > 0 {
			f.bytesbuff.WriteString(f.colsep)
		}
		f.bytesbuff.WriteString(csvValue(c.col.Name()))
	}
	f.bytesbuff.WriteString(SqlcmdEol)
	f.out.Write(f.bytesbuff.Bytes())
}

func (f *csvFormatter) EndResultSet() {
	f.logMessage(fmt.Sprintf("%s [I] End ResultSet\n", time.Now().Format(time.RFC3339)))
}

func (f *csvFormatter) AddRow(rows *sql.Rows) string {
	sf := scanRowFactory(f.columnDetails, f.ncol)
	cf := colValFactory(f.columnDetails, f.ccb)
	retval := ""
	val, err := sf(rows)
	if err != nil {
		f.err.Write([]byte(err.Error()))
		return retval
	}
	retval = val[0]
	f.bytesbuff.Reset()
	for i, v := range val {
		if i > 0 {
			f.bytesbuff.WriteString(f.colsep)
		}
		f.bytesbuff.WriteString(csvValue(cf(v, i)))
	}
	f.bytesbuff.WriteString(SqlcmdEol)
	f.out.Write(f.bytesbuff.Bytes())
	f.rowcount++
	return retval
}

func (f *csvFormatter) AddMessage(s string) {
	f.logMessage(s)
}

func (f *csvFormatter) AddError(e error) {
	f.err.Write([]byte(fmt.Sprintf("%v", e)))
	fmt.Printf("[E] %v\n", e)
}

// funcs
func (f *csvFormatter) logMessage(s string) {
	if f.redirectMessage {
		f.err.Write([]byte(s))
	} else {
		fmt.Println(s)
	}
}

func csvValue(s string) string {
	if strings.Contains(s, ",") {
		return `"` + strings.ReplaceAll(s, `"`, `""`) + `"`
	}
	return s
}

func scanRowFactory(cDetails []columnDetail, ncol int) func(*sql.Rows) ([]string, error) {
	return func(rows *sql.Rows) ([]string, error) {
		r := make([]interface{}, len(cDetails))
		for i := range r {
			r[i] = new(interface{})
		}
		if err := rows.Scan(r...); err != nil {
			return nil, err
		}
		row := make([]string, ncol)
		for n, z := range r {
			j := z.(*interface{})
			if *j == nil {
				row[n] = "NULL"
			} else {
				switch x := (*j).(type) {
				case []byte:
					if isBinaryDataType(&cDetails[n].col) {
						row[n] = decodeBinary(x)
					} else if cDetails[n].col.DatabaseTypeName() == "UNIQUEIDENTIFIER" {
						// Unscramble the guid
						// see https://github.com/denisenkom/go-mssqldb/issues/56
						x[0], x[1], x[2], x[3] = x[3], x[2], x[1], x[0]
						x[4], x[5] = x[5], x[4]
						x[6], x[7] = x[7], x[6]
						if guid, err := uuid.FromBytes(x); err == nil {
							row[n] = guid.String()
						} else {
							// this should never happen
							row[n] = uuid.New().String()
						}
					} else {
						row[n] = string(x)
					}
				case string:
					row[n] = x
				case time.Time:
					// Go lacks any way to get the user's preferred time format or even the system default
					switch cDetails[n].col.DatabaseTypeName() {
					case "DATE":
						row[n] = x.Format("2006-01-02")
					case "DATETIME":
						row[n] = x.Format(dateTimeFormatString(3, false))
					case "DATETIME2":
						row[n] = x.Format(dateTimeFormatString(cDetails[n].scale, false))
					case "SMALLDATETIME":
						row[n] = x.Format(dateTimeFormatString(0, false))
					case "DATETIMEOFFSET":
						row[n] = x.Format(dateTimeFormatString(cDetails[n].scale, true))
					case "TIME":
						format := "15:04:05"
						if cDetails[n].scale > 0 {
							format = fmt.Sprintf("%s.%0*d", format, cDetails[n].scale, 0)
						}
						row[n] = x.Format(format)
					default:
						row[n] = x.Format(time.RFC3339)
					}
				case fmt.Stringer:
					row[n] = x.String()
				// not sure why go-mssql reports bit as bool
				case bool:
					if x {
						row[n] = "1"
					} else {
						row[n] = "0"
					}
				default:
					var err error
					if row[n], err = fmt.Sprintf("%v", x), nil; err != nil {
						return nil, err
					}
				}
			}
		}
		return row, nil
	}
}

func colValFactory(cDetails []columnDetail, ccb ControlCharacterBehavior) func(s string, col int) string {
	return func(s string, col int) string {
		c := cDetails[col]
		if isNeedingControlCharacterTreatment(&c.col) {
			s = applyControlCharacterBehavior(s, ccb)
		}
		if isNeedingHexPrefix(&c.col) {
			s = "0x" + s
		}
		return s
	}
}
