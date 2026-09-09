# Backlog

## In flight

## Done
- [x] wrap-receipt-validation — Reject malformed receipts and report incomplete detector coverage (ship, local-only).
  Owner approved the audit follow-up on 2026-09-09. Public seam: detector CLI, environment inputs, stdout and exit status. Preserve valid receipt reporting and the explicit init-only write boundary. Invalid receipts must remain visible as invalid, never hide real unwrapped sessions. Database read failure must not look like successful coverage. Run the existing CLI suite plus negative fixtures. No receipt migration or deletion.

  Verified: 51 CLI assertions pass, including malformed receipt, date-only/null metadata, unreadable DB, and broken receipt link. Review findings corrected.
