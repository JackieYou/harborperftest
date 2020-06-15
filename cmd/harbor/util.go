package harbor

import (
	"perftest/pkg/report"
)

func newReport() report.Report {
	p := "%4.4f"
	return report.NewReport(p)
}
