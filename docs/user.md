# User Guide

This guide is for API users. It explains how to submit a request, check the job
status, and retrieve the result.

The API is asynchronous. A request does not return the final result immediately.
It creates a job. The client then checks the job status and fetches the result
when the job is finished.

## Base URL

In the examples below, the service is assumed to be reachable at:

```bash
export BASE_URL=http://192.168.140.45:5000
```

Change this value if the administrator exposes the service on another host or
port.

## The protocol in three steps

This section uses the `iwv` operation as the first example. The other
operations follow the same job protocol and are listed later in this guide.

### 1. Submit a job

```bash
curl -sS -X POST "$BASE_URL/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "operation": "iwv",
    "parameters": {
      "date": "A2026011600",
      "hour": 1
    }
  }'
```

The response has HTTP status `202 Accepted` and includes the new `job_id`:

```json
{
  "job_id": "job-1234567890abcdef",
  "status": "queued",
  "operation": "iwv",
  "validated_parameters": {
    "date": "A2026011600",
    "hour": 1
  },
  "created_at": "2026-06-12T10:00:00Z",
  "started_at": null,
  "finished_at": null,
  "has_result": false,
  "has_plot": false,
  "error": null
}
```

Copy the returned `job_id`.

### 2. Check the job status

```bash
curl -sS "$BASE_URL/jobs/job-1234567890abcdef"
```

A job status can be:

- `queued`
- `started`
- `finished`
- `failed`

If the job is still `queued` or `started`, wait and repeat the status request.

### 3. Retrieve the result

When the job status is `finished` and `has_result` is `true`, retrieve the
result:

```bash
curl -sS "$BASE_URL/jobs/job-1234567890abcdef/result"
```

A single-epoch `iwv` result has this shape:

```json
{
  "job_id": "job-1234567890abcdef",
  "status": "finished",
  "operation": "iwv",
  "result": {
    "iwv_mm": 12.345678,
    "ilw_mm": 0.001234,
    "zdd_m": 2.123456,
    "zwd_m": 0.123456,
    "q": 0.123456
  }
}
```

## Request format

Create jobs with:

```text
POST /jobs
```

The JSON body must contain exactly these top-level fields:

```json
{
  "operation": "iwv",
  "parameters": {
    "date": "A2026011600",
    "hour": 1
  }
}
```

`operation` is the operation name.

`parameters` is a JSON object containing the parameters required by that
operation.

Unexpected top-level fields are rejected.

## Data timestamp and hour

Atmospheric operations use this data selector:

```text
<DB><YYYYMMDDHH>
```

Examples:

```text
A2026011600
B2026011600
```

`A` selects the current data catalog.

`B` selects the older data catalog.

The `hour` parameter must be an integer greater than or equal to `0`.

For the atmospheric operations:

- `hour: 1`, `hour: 2`, ... request one epoch;
- `hour: 0` requests the full time series when supported by the operation.

The valid maximum epoch depends on the selected data file. If the requested
epoch does not exist in that file, the job can fail during execution.

## Python example

The following Python example implements the same three steps: submit, poll,
retrieve.

```python
import time

import requests


BASE_URL = "http://192.168.140.45:5000"


def submit_job(operation, parameters):
    response = requests.post(
        f"{BASE_URL}/jobs",
        json={"operation": operation, "parameters": parameters},
        timeout=10,
    )
    response.raise_for_status()
    return response.json()["job_id"]


def wait_for_job(job_id, poll_interval=1.0, timeout=60.0):
    deadline = time.monotonic() + timeout

    while time.monotonic() < deadline:
        response = requests.get(f"{BASE_URL}/jobs/{job_id}", timeout=10)
        response.raise_for_status()
        metadata = response.json()

        if metadata["status"] in {"finished", "failed"}:
            return metadata

        time.sleep(poll_interval)

    raise TimeoutError(f"Job {job_id} did not finish within {timeout} seconds")


def fetch_result(job_id):
    response = requests.get(f"{BASE_URL}/jobs/{job_id}/result", timeout=10)
    response.raise_for_status()
    return response.json()["result"]


job_id = submit_job(
    "iwv",
    {
        "date": "A2026011600",
        "hour": 1,
    },
)

metadata = wait_for_job(job_id)

if metadata["status"] == "failed":
    raise RuntimeError(metadata["error"])

result = fetch_result(job_id)
print(result)
```

## Available operations

| Operation | Description | Required parameters | Optional parameters |
| --- | --- | --- | --- |
| `data` | List available data files. | none | `year`, `month`, `day`, `from`, `to`, `limit` |
| `iwv` | Compute integrated water vapor values. | `date`, `hour` | none |
| `opacity` | Compute atmospheric opacity for a frequency. | `date`, `hour`, `freq` | none |
| `meteo` | Extract meteorological values. | `date`, `hour` | none |
| `rain` | Extract rain information. | `date`, `hour` | none |
| `tsys` | Estimate system temperature. | `date`, `hour`, `freq`, `theta`, `eta`, `trec` | none |

## Operation examples

### `data`

```bash
curl -sS -X POST "$BASE_URL/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "operation": "data",
    "parameters": {
      "year": 2026,
      "month": 1,
      "day": 16
    }
  }'
```

All `data` parameters are optional. If no date filter is provided, the operation
returns files from the latest available month, limited by the configured default
limit.

### `opacity`

```bash
curl -sS -X POST "$BASE_URL/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "operation": "opacity",
    "parameters": {
      "date": "A2026011600",
      "hour": 1,
      "freq": 86.3
    }
  }'
```

### `meteo`

```bash
curl -sS -X POST "$BASE_URL/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "operation": "meteo",
    "parameters": {
      "date": "A2026011600",
      "hour": 1
    }
  }'
```

### `rain`

```bash
curl -sS -X POST "$BASE_URL/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "operation": "rain",
    "parameters": {
      "date": "A2026011600",
      "hour": 1
    }
  }'
```

### `tsys`

```bash
curl -sS -X POST "$BASE_URL/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "operation": "tsys",
    "parameters": {
      "date": "A2026011600",
      "hour": 1,
      "freq": 86.3,
      "theta": 45.0,
      "eta": 0.95,
      "trec": 50.0
    }
  }'
```

## Plot endpoint

A plot can be requested with:

```text
GET /jobs/<job_id>/plot
```

The current operation catalog marks all available operations as not producing a
plot. For these operations, the plot endpoint returns an error.

## Web UI

A simple web UI is available at:

```text
BASE_URL/ui
```

It is useful for manual checks. It uses the same asynchronous job protocol
internally.

## Error responses

Errors are returned as JSON:

```json
{
  "error": {
    "code": "INVALID_PARAMETERS",
    "message": "Missing required parameter(s): hour."
  }
}
```

Common error codes include:

- `INVALID_JSON`
- `INVALID_REQUEST`
- `UNKNOWN_OPERATION`
- `INVALID_PARAMETERS`
- `JOB_NOT_FOUND`
- `RESULT_NOT_READY`
- `RESULT_NOT_AVAILABLE`
- `PLOT_NOT_AVAILABLE`
- `JOB_FAILED`
- `QUEUE_SUBMISSION_FAILED`
- `REQUEST_TOO_LARGE`
- `INTERNAL_ERROR`

## Legacy compatibility

The operations described in this guide are the standard API operations. Some of
them also have a legacy implementation, available by adding the `legacy_` prefix
to the operation name.

Examples:

- `iwv` -> `legacy_iwv`
- `opacity` -> `legacy_opacity`
- `meteo` -> `legacy_meteo`
- `rain` -> `legacy_rain`
- `tsys` -> `legacy_tsys`

The legacy variants use the same `/jobs` protocol described above. They are
provided for compatibility and comparison. The implementation details are not
needed to use the API and are described in the Developer Guide.

A legacy command endpoint is also available for compatibility with the old text
command format:

```text
POST /legacy/command
```

It accepts either JSON:

```bash
curl -sS -X POST "$BASE_URL/legacy/command" \
  -H 'Content-Type: application/json' \
  -d '{"command": "iwv,2026011600,1"}'
```

or a plain text body:

```bash
curl -sS -X POST "$BASE_URL/legacy/command" \
  -H 'Content-Type: text/plain' \
  --data 'iwv,2026011600,1'
```

The supported legacy command catalog is available at:

```text
GET /legacy/commands
```

