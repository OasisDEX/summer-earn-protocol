/**
 * Code based on https://dev.to/musatov/improving-code-coverage-reporting-in-monorepos-115e
 */
const {
  getAllPathsForPackagesSummaries,
  readSummaryPerPackageAndCreateJoinedSummaryReportWithTotal,
  createCoverageReportForVisualRepresentation,
} = require('./Utils')

// Execution Stages
// 1. Read all coverage-total.json files
const packagesSummaryPaths = getAllPathsForPackagesSummaries()
// 2. Generate consolidated report
const currCoverageReport =
  readSummaryPerPackageAndCreateJoinedSummaryReportWithTotal(packagesSummaryPaths)
// 3. Reformat the report for visual representation
const coverageReportForVisualRepresentation =
  createCoverageReportForVisualRepresentation(currCoverageReport)
// 4. Print the report
console.table(coverageReportForVisualRepresentation)
