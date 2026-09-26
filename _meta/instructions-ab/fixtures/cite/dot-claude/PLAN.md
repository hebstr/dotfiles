# PLAN

## Objective

Make the HTTP client in `src/client.py` resilient to transient failures.

## Success criteria

- A transient server failure is retried with backoff instead of aborting the call.
- A permanent failure surfaces as `FetchError` with the status code.

## Out of scope

- Switching to a third-party HTTP library.

## Steps

1. Add a timeout to every request.
   Done.
2. Wrap network failures in `FetchError`.
   Done.

## Blockers

None.
