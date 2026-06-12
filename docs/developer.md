# Developer Guide

This guide is for developers who need to understand the current codebase and
extend it.

It documents the application as it exists in this repository. It does not
describe components, test layers, or workflows that are not currently present.

New commands must be implemented as native Python operations. The legacy Octave
operations are kept for compatibility and comparison and are not extended.

## Project structure

Important files and directories:

```text
app/
  api/
    errors.py
    legacy_commands.py
    legacy_parser.py
    routes.py
  domain/
    exceptions.py
    job_models.py
  integrations/
    atm_ser_adapter.py
    octave_mdata_reader.py
    octave_runner.py
  operations/
    registry.py
    schemas.py
    handlers/
      data_catalog.py
      iwv.py
      legacy_passthrough.py
      meteo.py
      opacity.py
      rain.py
      tsys.py
  services/
    job_service.py
    operation_service.py
    queue_service.py
    storage_service.py
  workers/
    job_worker.py
  templates/
    ui.html

scripts/
  app/deployment/
  common/
  host/provisioning/
  host/vagrant/
  vm/provisioning/
  smoke_tests.py

tests/
  equivalence/
  fixtures/
```

## Runtime flow

The public job API is asynchronous:

```text
Client
  -> POST /jobs
  -> Flask route
  -> JobService
  -> StorageService saves queued metadata
  -> QueueService enqueues the job through Redis/RQ
  -> HTTP response with job_id

Separate worker process
  -> RQ receives the queued job
  -> JobWorker loads metadata
  -> JobWorker marks the job as started
  -> operation handler is selected from the registry
  -> handler executes
  -> result and optional plot are saved
  -> metadata is marked as finished or failed

Client
  -> GET /jobs/<job_id>
  -> GET /jobs/<job_id>/result
```

The HTTP process does not execute the operation directly. The worker process
executes it.

## HTTP layer

The HTTP routes are defined in:

```text
app/api/routes.py
```

Public endpoints:

```text
GET  /ui
GET  /legacy/commands
POST /jobs
GET  /jobs/<job_id>
GET  /jobs/<job_id>/result
GET  /jobs/<job_id>/plot
POST /legacy/command
```

`POST /jobs` accepts JSON with exactly two top-level fields:

```json
{
  "operation": "iwv",
  "parameters": {
    "date": "A2026011600",
    "hour": 1
  }
}
```

The route validates the request shape and delegates job creation to
`JobService`.

`POST /legacy/command` accepts a textual legacy command or a JSON object with a
`command` field. It converts the text command into a `legacy_*` operation and
then uses the same job flow as `/jobs`.

## Job metadata and results

Job models are defined in:

```text
app/domain/job_models.py
```

The main job metadata fields are:

```text
job_id
status
operation
validated_parameters
created_at
started_at
finished_at
has_result
has_plot
error
```

Valid job statuses used by the current code are:

```text
queued
started
finished
failed
```

Filesystem storage is handled by:

```text
app/services/storage_service.py
```

The storage service reads and writes metadata, JSON results, and plot bytes in
the configured runtime directories.

## Queue and worker

Queue submission is handled by:

```text
app/services/queue_service.py
```

Queued jobs are executed through Redis/RQ by:

```text
worker.py
app/workers/job_worker.py
```

The worker receives:

```text
job_id
operation
validated_parameters
```

It loads the stored metadata, marks the job as started, executes the registered
handler, validates the handler output, saves the result or plot, and finally
marks the job as finished or failed.

## Operation catalog and registry

The operation catalog is defined in:

```text
app/operations/schemas.py
```

It declares:

- operation names;
- descriptions;
- whether the operation produces a result;
- whether the operation produces a plot;
- required parameters;
- optional parameters.

The handler registry is defined in:

```text
app/operations/registry.py
```

It maps operation names to handler functions.

The registry validates consistency at import time: every operation in the
catalog must have a handler, and every registered handler must correspond to a
catalog entry.

## Current operations

Native Python operations:

```text
data
iwv
opacity
meteo
rain
tsys
```

Legacy Octave operations:

```text
legacy_iwv
legacy_opacity
legacy_meteo
legacy_rain
legacy_tsys
```

Legacy handlers are collected in:

```text
app/operations/handlers/legacy_passthrough.py
```

They delegate to the legacy backend through:

```text
app/integrations/atm_ser_adapter.py
```

Do not add new legacy Octave operations. New functionality belongs in native
Python handlers.

## Handler contract

A handler is a Python function that receives a dictionary of validated
parameters and returns a dictionary with this shape:

```python
{
    "result": {...},
    "plot_bytes": None,
}
```

At least one of `result` or `plot_bytes` must be present.

For the current operations, `result` is a JSON-serializable dictionary and
`plot_bytes` is `None`.

The worker rejects invalid handler output.

## How to add a new native Python operation

Use this path only for native Python operations. Do not extend the legacy Octave
operation set.

### 1. Add the handler module

Create a new file under:

```text
app/operations/handlers/
```

Example:

```text
app/operations/handlers/my_operation.py
```

The module must expose a handler function compatible with the current registry
pattern. Existing native handlers use the name `handle`.

Example shape:

```python
from __future__ import annotations

from typing import Any


def handle(params: dict[str, Any]) -> dict[str, Any]:
    value = params["value"]
    return {
        "result": {
            "value": value,
        },
        "plot_bytes": None,
    }
```

Keep returned values JSON-serializable.

### 2. Add the operation to the catalog

Edit:

```text
app/operations/schemas.py
```

Add the new operation to `OPERATION_CATALOG`:

```python
"my_operation": {
    "description": "Describe what the operation does.",
    "produces_result": True,
    "produces_plot": False,
    "required_parameters": {
        "value": "float",
    },
    "optional_parameters": {},
},
```

The currently supported symbolic parameter types are:

```text
string
float
integer
datetime_iso8601
```

### 3. Register the handler

Edit:

```text
app/operations/registry.py
```

Import the handler near the existing handler imports:

```python
from app.operations.handlers.my_operation import handle as handle_my_operation
```

Then add it to `_build_handler_registry()`:

```python
"my_operation": handle_my_operation,
```

The registry consistency check will fail at startup if the catalog and handler
registry do not match.

### 4. Add operation-specific validation only if needed

Generic parameter normalization is implemented in:

```text
app/services/operation_service.py
```

Add operation-specific constraints there only if type validation is not enough.

Do not add validation to the HTTP route if it belongs to an operation. Operation
validation belongs in the operation validation layer.

### 5. Make errors consistent

Use exceptions from:

```text
app/domain/exceptions.py
```

For execution failures inside an operation, existing handlers use
`OperationExecutionError`.

The worker maps operation errors into failed job metadata, and the API exposes
failed jobs consistently through the existing error handlers.

### 6. Update the user documentation

If the new operation is public, update:

```text
docs/user.md
```

Add:

- operation name;
- short description;
- required and optional parameters;
- one minimal `curl` example.

### 7. Update smoke tests if the public API should cover it

The current smoke test runner is:

```text
scripts/smoke_tests.py
```

If the new public operation must be covered by deployment smoke checks, add it
there.

### 8. Add or update equivalence tests only for Python replacements of legacy operations

The current equivalence tests are under:

```text
tests/equivalence/
```

They compare native Python operations with the corresponding legacy Octave
operations through the public asynchronous API.

Only add equivalence coverage when the new Python operation is meant to replace
or mirror an existing legacy operation.

## Parameter validation

Validation and normalization are implemented in:

```text
app/services/operation_service.py
```

The catalog defines the symbolic types. The validation layer:

- checks required parameters;
- rejects unexpected parameters;
- normalizes strings, floats, integers, and ISO 8601 datetimes;
- applies operation-specific constraints.

Current atmospheric operations use `date`, `hour`, `freq`, `theta`, `eta`, and
`trec` constraints. The `data` operation uses file timestamp filters and result
limits.

## Result and plot handling

Operation output is represented by `OperationOutput` in:

```text
app/domain/job_models.py
```

The current operations produce JSON results and no plots.

The plot endpoint exists:

```text
GET /jobs/<job_id>/plot
```

but the current catalog marks all available operations with:

```text
produces_plot = False
```

If a future native operation returns `plot_bytes`, the worker can store it and
the plot endpoint can return it as `image/png`.

## Legacy command compatibility

Legacy command parsing is implemented in:

```text
app/api/legacy_parser.py
app/api/legacy_commands.py
```

The endpoint:

```text
POST /legacy/command
```

converts textual commands into `legacy_*` operations.

This compatibility path remains available, but new operations should not be
added to the legacy Octave command set.

## Existing tests and checks

The repository currently contains these test/check entrypoints.

### Smoke tests

```text
scripts/smoke_tests.py
```

These tests exercise the running API. They are used by VM deployment unless
`RUN_SMOKE_TESTS=0` is set.

Run them manually against a reachable API:

```bash
BASE_URL=http://192.168.140.45:5000 python scripts/smoke_tests.py
```

### Equivalence tests

```text
tests/equivalence/
```

Current files:

```text
test_iwv_equivalence.py
test_meteo_equivalence.py
test_opacity_equivalence.py
test_rain_equivalence.py
test_tsys_equivalence.py
```

The tests use configuration files under:

```text
tests/fixtures/
```

Run an example equivalence test:

```bash
pytest tests/equivalence/test_iwv_equivalence.py
```

Run with the full configuration:

```bash
pytest tests/equivalence/test_iwv_equivalence.py \
  --equivalence-config tests/fixtures/equivalence_config_full.json
```

Do not document non-existing test layers as if they were part of the project.
If a new test category is introduced later, document it when it exists.

## Deployment scripts for developers

The deployment scripts are organized by execution context:

```text
scripts/app/deployment/
scripts/common/
scripts/host/provisioning/
scripts/host/vagrant/
scripts/vm/provisioning/
```

Keep the distinction clear:

- `scripts/app/deployment/` contains application deployment scripts;
- `scripts/common/` contains shared checks;
- `scripts/host/provisioning/` changes the host for shared VM management;
- `scripts/host/vagrant/` runs on the host and controls Vagrant;
- `scripts/vm/provisioning/` runs inside the VM during provisioning.

The user-facing deployment entrypoint is:

```text
admin.sh
```

If the menu or direct targets change, update the System Administration Guide.

## Environment variables

The application reads configuration from `.env` through `app/config.py`.

Important variables include:

```text
JOB_STORAGE_DIR
PLOT_STORAGE_DIR
DATA_DIR
ATM_SER_PATH
OCTAVE_BIN
OCTAVE_TIMEOUT_SECONDS
REDIS_URL
RQ_QUEUE_NAME
FLASK_HOST
FLASK_PORT
FLASK_DEBUG
MAX_JSON_BODY_BYTES
MAX_LEGACY_COMMAND_LENGTH
DATA_OPERATION_DEFAULT_LIMIT
DATA_OPERATION_MAX_LIMIT
LOG_LEVEL
```

The common environment check script is:

```text
scripts/common/check_env.sh
```

## Developer checklist for a new native operation

Before considering a new operation complete, check that:

- the handler exists under `app/operations/handlers/`;
- the operation is declared in `app/operations/schemas.py`;
- the handler is registered in `app/operations/registry.py`;
- parameter validation is sufficient;
- the result is JSON-serializable;
- operation errors are reported through the existing exception flow;
- `docs/user.md` documents the public operation;
- `scripts/smoke_tests.py` is updated if deployment smoke coverage is required;
- `tests/equivalence/` is updated only if the operation mirrors an existing
  legacy operation;
- no new Octave legacy operation has been added.
