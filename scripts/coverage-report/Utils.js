/**
 * Code based on https://dev.to/musatov/improving-code-coverage-reporting-in-monorepos-115e
 */
const fs = require('fs')
const path = require('path')

function getAllPathsForPackagesSummaries() {
  const getDirectories = (source) =>
    fs
      .readdirSync(source, { withFileTypes: true })
      .filter((dirent) => dirent.isDirectory())
      .map((dirent) => dirent.name)

  const appsPath = 'packages'
  const appsNames = getDirectories(appsPath)

  const appsSummaries = appsNames.reduce((summary, appName) => {
    return {
      ...summary,
      [appName]: path.join(appsPath, appName, 'coverage', 'coverage-summary.json'),
    }
  }, {})

  const packagesPath = 'packages'
  const packageNames = getDirectories(packagesPath)

  const packagesSummaries = packageNames.reduce((summary, packageName) => {
    return {
      ...summary,
      [packageName]: path.join(packagesPath, packageName, 'coverage', 'coverage-summary.json'),
    }
  }, {})

  return { ...appsSummaries, ...packagesSummaries }
}

function readSummaryPerPackageAndCreateJoinedSummaryReportWithTotal(packagesSummaryPaths) {
  return Object.keys(packagesSummaryPaths).reduce(
    (summary, packageName) => {
      const reportPath = packagesSummaryPaths[packageName]
      if (fs.existsSync(reportPath)) {
        const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'))

        const { total } = summary

        Object.keys(report.total).forEach((key) => {
          if (total[key]) {
            total[key].total += report.total[key].total
            total[key].covered += report.total[key].covered
            total[key].skipped += report.total[key].skipped
            total[key].pct = Number(((total[key].covered / total[key].total) * 100).toFixed(2))
          } else {
            total[key] = { ...report.total[key] }
          }
        })

        return { [packageName]: report.total, ...summary, total }
      }

      return summary
    },
    { total: {} },
  )
}

function createCoverageReportForVisualRepresentation(coverageReport) {
  const separator = {
    ['-------------']: {
      'lines (%)': '-----',
      'statements (%)': '-----',
      'functions (%)': '-----',
      'branches (%)': '-----',
    },
  }

  return Object.keys(coverageReport).reduce((report, packageName) => {
    if (
      coverageReport[packageName] === undefined ||
      Object.keys(coverageReport[packageName]).length === 0
    ) {
      return report
    }

    const { lines, statements, functions, branches } = coverageReport[packageName]

    if (packageName === 'total') {
      return {
        ...report,
        ...separator,
        ['TOTAL']: {
          'lines (%)': lines.pct,
          'statements (%)': statements.pct,
          'functions (%)': functions.pct,
          'branches (%)': branches.pct,
        },
      }
    }

    return {
      ...report,
      [packageName]: {
        'lines (%)': lines.pct,
        'statements (%)': statements.pct,
        'functions (%)': functions.pct,
        'branches (%)': branches.pct,
      },
    }
  }, {})
}

module.exports = {
  getAllPathsForPackagesSummaries,
  readSummaryPerPackageAndCreateJoinedSummaryReportWithTotal,
  createCoverageReportForVisualRepresentation,
}
