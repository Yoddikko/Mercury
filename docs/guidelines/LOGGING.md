# Logging Guidelines

## Purpose

Mercury uses structured application logs for diagnostics, QA, and incident triage.

Logs must be consistent across modules so debug exports can be read quickly.

---

## Canonical Log Shape

Use the `AppLogger` API and keep this structure:

`[DD-MM-YYYY HH:MM:SS.mmm][LEVEL][CATEGORY][SERVICE/MODULE][FILE:LINE][FUNCTION][REQUEST_ID] message | key=value key=value`

The implementation can serialize this format directly, but contributors should
focus on passing the correct semantic fields:

* level
* category
* service/module name
* request id (when the call belongs to a flow)
* useful key-value metadata

---

## Levels

* `TRACE` for detailed execution steps
* `DEBUG` for development diagnostics
* `INFO` for successful state transitions
* `WARN` for recoverable anomalies
* `ERROR` for failed operations
* `FATAL` for unrecoverable failures

---

## Categories

* `SYSTEM`
* `API`
* `AUTH`
* `DATABASE`
* `CACHE`
* `QUEUE`
* `UI`
* `BUSINESS`
* `SECURITY`
* `PERFORMANCE`
* `FILESYSTEM`
* `EMAIL`
* `NOTIFICATION`
* `ANALYTICS`

---

## Mandatory Rule for AI Contributors

For every new or modified function, add logging coverage.

Minimum expectation:

* at least one log entry describing the function action
* additional logs for failure branches and exceptional paths
* for async/multi-step flows, a start log and a completion/failure log

Do not leave newly introduced behavior without logs.

---

## Request ID Propagation

When a flow spans multiple layers (ViewModel -> Service -> Client -> Parser):

* generate a request id at the flow entrypoint
* pass it through downstream calls
* include it in all related logs

This is required for end-to-end traceability in exported logs.

---

## Metadata and Safety

Metadata should contain stable, grep-friendly keys such as:

* `source_id`
* `status_code`
* `duration_ms`
* `items_in`
* `items_out`

Never log secrets or sensitive data:

* tokens
* passwords
* private user content
* full authentication headers

---

## Debug Export Requirement

Debug mode must provide a way to export collected logs as a text file.

Current implementation uses the Developer Playground logging section and
`AppLogger.exportToTemporaryFile()`.

---

## PR Expectation

If behavior changes and logging is intentionally not added or updated,
the PR must include an explicit rationale.
