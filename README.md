# Meteo Job Server

This application lets you run atmospheric and meteorological calculations through a simple web API.

You send a request, the application starts the computation, and then you retrieve the result when it is ready.

---

## What this application is for

You can use this application to:

- request an atmospheric or meteorological computation
- wait for the computation to finish
- read the result as JSON
- retrieve a plot image for operations that produce one

The application currently supports both:

- **native operations**
- **legacy-compatible operations** exposed through the same API

Current legacy-compatible operations:

- `legacy_iwv`
- `legacy_opacity`
- `legacy_meteo`
- `legacy_rain`
- `legacy_tsys`

---

## What you need before using it

Before you can use the application, you need to install:

- **Python 3**
- **Redis**
- **Octave**
- the Python packages listed in `requirements.txt`

Octave is currently needed because some supported operations still rely on the existing legacy scientific backend.

---

## Installation

## 1. Clone the repository

```bash
git clone https://github.com/marco-buttu/meteo
cd meteo
```

## 2. Install Python

Use any Python 3 installation method you prefer.

### Ubuntu / Debian
```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv
```

### macOS with Homebrew
```bash
brew install python
```

Check that Python is available:

```bash
python3 --version
```

---

## 3. Install Redis

Redis is required because the application uses a job queue.

### Ubuntu / Debian
```bash
sudo apt update
sudo apt install -y redis-server
```

### macOS with Homebrew
```bash
brew install redis
```

Check that Redis is available:

```bash
redis-server --version
```

---

## 4. Install Octave

Octave is currently required for the legacy-compatible scientific operations.

### Ubuntu / Debian
```bash
sudo apt update
sudo apt install -y octave
```

### macOS with Homebrew
```bash
brew install octave
```

Check that Octave is available:

```bash
octave-cli --version
```

---

## 5. Create a Python virtual environment

```bash
python3 -m venv .venv
source .venv/bin/activate
```

## 6. Install Python dependencies

```bash
pip install -r requirements.txt
```

## 7. Prepare the project environment

```bash
inv setup
```

If you open a new shell later, activate the virtual environment again and rerun:

```bash
source .venv/bin/activate
inv setup
```

---

## How to start the application

You need **three terminals**:

- Terminal 1: Redis
- Terminal 2: the application
- Terminal 3: the worker

### Terminal 1 — start Redis

```bash
redis-server
```

If you prefer using the project tasks:

```bash
inv check
inv redis
```

### Terminal 2 — start the application

```bash
source .venv/bin/activate
inv setup
inv app
```

### Terminal 3 — start the worker

```bash
source .venv/bin/activate
inv setup
inv worker
```

If everything is working, the application should be available at:

```text
http://127.0.0.1:5000
```

---

## Smoke tests

The repository includes a smoke test runner that verifies the main application flow.

Run it in a new terminal:

```bash
source .venv/bin/activate
inv setup
inv smoke
```

This verifies things such as:

- job creation
- worker execution
- result retrieval
- plot generation
- validation errors
- legacy operation coverage


---

## First complete example

This is the simplest way to understand how to use the application.

First, define a base URL:

```bash
export BASE_URL=http://127.0.0.1:5000
```

## Step 1 — create a job

Run this command:

```bash
curl -sS -X POST "$BASE_URL/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "operation": "get_precipitable_water_vapor",
    "parameters": {
      "timestamp": "2026-03-27T10:00:00Z",
      "site_lat": 39.5,
      "site_lon": 9.2
    }
  }'
```

A typical response looks like this:

```json
{
  "job_id": "job-1234567890abcdef",
  "status": "queued"
}
```

Important: copy the value of `job_id`.

In this example, the job id is:

```text
job-1234567890abcdef
```

You will use that value in the next commands.

---

## Step 2 — check the job status

Replace `job-1234567890abcdef` with the real `job_id` returned by your request:

```bash
curl -sS "$BASE_URL/jobs/job-1234567890abcdef"
```

A running job may look like this:

```json
{
  "job_id": "job-1234567890abcdef",
  "status": "started"
}
```

A finished job may look like this:

```json
{
  "job_id": "job-1234567890abcdef",
  "status": "finished",
  "has_result": true,
  "has_plot": false
}
```

If the job is still `queued` or `started`, wait a moment and run the command again.

---

## Step 3 — get the result

When the job status becomes `finished`, run:

```bash
curl -sS "$BASE_URL/jobs/job-1234567890abcdef/result"
```

A typical result looks like this:

```json
{
  "job_id": "job-1234567890abcdef",
  "operation": "get_precipitable_water_vapor",
  "result": {
    "pwv_mm": 2.3,
    "quality": "good"
  },
  "status": "finished"
}
```

---

## Step 4 — get a plot, if the operation provides one

Some operations generate a plot.

Example request:

```bash
curl -sS -X POST "$BASE_URL/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "operation": "get_wind_profile",
    "parameters": {
      "timestamp": "2026-03-27T10:00:00Z",
      "site_lat": 39.5,
      "site_lon": 9.2,
      "max_altitude_m": 2000
    }
  }'
```

When that job is finished, you can save the plot to a file:

```bash
curl -sS "$BASE_URL/jobs/JOB_ID/plot" --output plot.png
```

Replace `JOB_ID` with the real job id returned by the create-job request.

---

## Example: legacy-compatible operation

The same workflow applies to legacy-compatible operations.

### Example: IWV

```bash
curl -sS -X POST "$BASE_URL/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "operation": "legacy_iwv",
    "parameters": {
      "date": "A2024030112",
      "hour": 1
    }
  }'
```

### Example: TSYS

```bash
curl -sS -X POST "$BASE_URL/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "operation": "legacy_tsys",
    "parameters": {
      "date": "A2024030112",
      "hour": 1,
      "freq": 86.3,
      "theta": 45.0,
      "eta": 0.95,
      "trec": 50.0
    }
  }'
```

Then use the returned `job_id` exactly as shown in the first complete example:

```bash
curl -sS "$BASE_URL/jobs/JOB_ID"
curl -sS "$BASE_URL/jobs/JOB_ID/result"
```

---

## Stopping the system

To stop the application, press `Ctrl+C` in each terminal.

---

## Troubleshooting

### The job stays queued forever
Most likely the worker is not running.

Make sure you started the worker in a separate terminal.

### The job fails immediately
Check:

- Redis is running
- Octave is installed
- the worker is running
- the required backend scripts and data files are available
- the environment is set up correctly

### Native operations work, but legacy operations fail
This usually means one of the following:

- Octave is missing
- legacy backend scripts are not found
- required legacy data files are missing
- the dataset does not support a specific legacy operation

### The plot endpoint returns 404
This usually means:

- the operation does not generate a plot
- the job has not finished yet
- the plot was not generated or stored

---

# Technical information for developers

Everything below is intended for developers or advanced users who want to understand the codebase.

---

## Architecture overview

The application follows a layered design:

- **API layer**: HTTP routes and request validation
- **Operation layer**: operation catalog and parameter schemas
- **Job service**: job lifecycle orchestration
- **Queue layer**: RQ enqueueing
- **Worker layer**: execution of operations
- **Storage layer**: metadata, results, and plot persistence
- **Integration layer**: scientific backend adapters

Public endpoints:

- `POST /jobs`
- `GET /jobs/<job_id>`
- `GET /jobs/<job_id>/result`
- `GET /jobs/<job_id>/plot`

---

## Execution flow

This section describes the internal execution flow of the application, from the
moment an HTTP request reaches the server to the moment the worker executes the
job and stores the result.

The application receives commands through Flask, creates asynchronous jobs,
enqueues them through Redis/RQ, and delegates execution to a separate worker
process.

For legacy-compatible operations, the worker eventually executes an Octave
script through `subprocess.run()`.

---

### Main components involved

The main components involved in the flow are:

- `run.py`: starts the Flask application.
- `app/api/routes.py`: defines the HTTP routes.
- `app/api/legacy_parser.py`: converts legacy textual commands into internal operations.
- `app/services/job_service.py`: creates and registers jobs.
- `app/services/storage_service.py`: reads and writes metadata, results, and plots on the filesystem.
- `app/services/queue_service.py`: enqueues jobs into Redis/RQ.
- `worker.py`: starts the RQ worker and defines the function executed by queued jobs.
- `app/workers/job_worker.py`: orchestrates job execution.
- `app/operations/registry.py`: maps operation names to their handlers.
- `app/operations/handlers/legacy_passthrough.py`: contains handlers for legacy-compatible operations.
- `app/integrations/atm_ser_adapter.py`: builds and executes the Octave command.

---

### 1. HTTP request arrival

For a legacy-compatible command, the client sends a request to:

```text
POST /legacy/command
```

The request is received by Flask and routed to:

```python
create_legacy_job()
```

defined in:

```text
app/api/routes.py
```

The first application-level operation is reading the request body:

```python
raw_body = request.get_data(cache=True)
```

If the request body is empty, the application raises an error:

```python
if not raw_body:
    raise InvalidRequestError("Request body is missing.")
```

The command can arrive as JSON:

```json
{
  "command": "iwv,20260428,12"
}
```

or as a plain text body:

```text
iwv,20260428,12
```

In both cases, the goal of this first step is to obtain a legacy command string.

---

### 2. Legacy command parsing

Once the command string has been extracted, the route calls:

```python
parsed = parse_legacy_command(command)
```

The function `parse_legacy_command()` is defined in:

```text
app/api/legacy_parser.py
```

It splits the command using commas:

```python
parts = [p.strip() for p in command.split(",")]
instr = parts[0]
```

For example, this command:

```text
iwv,20260428,12
```

is transformed into:

```python
parts = ["iwv", "20260428", "12"]
instr = "iwv"
```

The parser recognizes the command type and converts it into the internal standard representation used by the rest of the application:

```text
operation + parameters
```

For example:

```text
iwv,20260428,12
```

becomes:

```python
{
    "operation": "legacy_iwv",
    "parameters": {
        "date": "A20260428",
        "hour": 12,
    },
}
```

From this point on, the application no longer works with the original textual legacy command. It works with an internal operation name and a parameter dictionary.

---

### 3. Entering the job system

After parsing, the route retrieves the job service:

```python
job_service = current_app.extensions["job_service"]
```

and calls:

```python
metadata = job_service.create_job(
    operation=parsed["operation"],
    parameters=parsed["parameters"],
)
```

This still happens inside:

```text
app/api/routes.py
```

but from this point on the command has entered the general job flow.

The method `create_job()` is defined in:

```text
app/services/job_service.py
```

The first operations are:

```python
check_operation_exists(operation)
validated_parameters = validate_and_normalize_parameters(operation, parameters)
```

The application therefore:

1. checks that the operation exists;
2. validates and normalizes the parameters.

For example, the operation:

```text
legacy_iwv
```

must be registered among the supported operations, and its parameters must match the expected schema.

---

### 4. Job metadata creation

After validation, `JobService` creates a new `JobMetadata` object.

Conceptually, the initial metadata contains information like this:

```json
{
  "job_id": "job-...",
  "status": "queued",
  "operation": "legacy_iwv",
  "validated_parameters": {
    "date": "A20260428",
    "hour": 12
  },
  "created_at": "...",
  "started_at": null,
  "finished_at": null,
  "has_result": false,
  "has_plot": false,
  "error": null
}
```

In this application, a job is not an operating system process.

A job is a description of work to execute. It contains:

```text
job_id
operation
validated_parameters
```

For example:

```text
Execute the legacy_iwv operation with date A20260428 and hour 12,
and associate state, result, and possible errors with this job_id.
```

---

### 5. Saving job metadata on the filesystem

The metadata is saved on the filesystem through:

```python
self._storage_service.save_job_metadata(metadata)
```

The responsible component is:

```text
app/services/storage_service.py
```

`StorageService` centralizes filesystem access for the application. In this context, "centralizes" means that file reading and writing logic is not scattered across many classes, but goes through a single service.

`StorageService` handles operations such as:

```text
save_job_metadata()
load_job_metadata()
update_job_metadata()
save_job_result()
load_job_result()
save_job_plot()
load_job_plot()
```

Metadata is stored as JSON, for example under:

```text
JOB_STORAGE_DIR/metadata/<job_id>.json
```

Important: `StorageService` does not implement file locking.

It does use atomic writes: it first writes to a temporary file, then replaces the final file. This reduces the risk of reading a partially written JSON file, but it is not the same as complete concurrency control through locks.

---

### 6. Queue payload creation

After saving the metadata, `JobService` passes the job to `QueueService`:

```python
self._queue_service.submit_job(
    job_id=metadata.job_id,
    operation=metadata.operation,
    validated_parameters=metadata.validated_parameters,
)
```

The service is defined in:

```text
app/services/queue_service.py
```

At this point, a payload is created. The payload is a data structure containing the information the worker needs:

```text
job_id
operation
validated_parameters
```

For example:

```python
QueuePayload(
    job_id="job-...",
    operation="legacy_iwv",
    validated_parameters={
        "date": "A20260428",
        "hour": 12,
    },
)
```

This payload is not stored as a separate file. It is passed to Redis/RQ.

---

### 7. Enqueuing the job into Redis/RQ

`QueueService` connects to Redis:

```python
connection = Redis.from_url(self._redis_url)
```

opens the RQ queue:

```python
queue = Queue(name=self._queue_name, connection=connection)
```

and enqueues the job:

```python
queue.enqueue_call(
    func="worker.execute_queued_job",
    kwargs={
        "job_id": payload.job_id,
        "operation": payload.operation,
        "validated_parameters": payload.validated_parameters,
    },
    job_id=payload.job_id,
)
```

This is a key point.

The HTTP server does not execute the command directly. The server:

1. receives the request;
2. creates a job;
3. saves the metadata;
4. enqueues the job into Redis/RQ;
5. responds to the client.

The actual execution is performed by a separate process: the worker.

---

### 8. Redis, RQ, job, and worker

The distinction between these components is:

```text
job    = description of the work to execute
Redis  = system used as the queue backend
RQ     = Python library that manages job enqueueing and dequeueing
worker = separate Python process that takes jobs from the queue and executes them
```

The Redis/RQ job is not a process.

The process is the worker, started separately, for example with:

```bash
python worker.py
```

or through Invoke:

```bash
inv worker
```

The worker listens to the queue. When it finds a job, RQ calls the function that was specified when the job was enqueued:

```python
worker.execute_queued_job(
    job_id=...,
    operation=...,
    validated_parameters=...
)
```

---

### 9. Worker startup

The main worker file is:

```text
worker.py
```

The `main()` function creates the Redis connection, opens the queue, and starts the RQ worker:

```python
def main() -> None:
    from redis import Redis
    from rq import Queue, Worker

    connection = Redis.from_url(REDIS_URL)
    queue = Queue(name=RQ_QUEUE_NAME, connection=connection)
    worker = Worker([queue], connection=connection)
    worker.work()
```

The method:

```python
worker.work()
```

puts the worker process in listening mode.

From this moment on, the worker waits for available jobs in the configured queue.

---

### 10. Dequeueing the job

When a job becomes available, RQ automatically calls the function specified in the job:

```python
execute_queued_job(
    job_id=...,
    operation=...,
    validated_parameters=...
)
```

This function is defined in:

```text
worker.py
```

Conceptually, it has this structure:

```python
def execute_queued_job(job_id: str, operation: str, validated_parameters: dict) -> None:
    storage_service = StorageService(
        root_dir=JOB_STORAGE_DIR,
        plot_dir=PLOT_STORAGE_DIR,
    )
    worker = JobWorker(storage_service=storage_service)
    worker.execute_job(
        job_id=job_id,
        operation=operation,
        validated_parameters=validated_parameters,
    )
```

Three things happen here:

1. a `StorageService` is created;
2. a `JobWorker` is created;
3. `JobWorker.execute_job()` is called.

`StorageService` is created inside the worker because the worker is a separate process from the Flask server. It cannot directly reuse Python objects created by the server process.

The Flask server and the worker have distinct `StorageService` instances, but they point to the same filesystem directories.

---

### 11. Job execution in `JobWorker`

The actual job execution happens in:

```text
app/workers/job_worker.py
```

inside:

```python
JobWorker.execute_job()
```

The worker receives:

```text
job_id
operation
validated_parameters
```

For example:

```python
job_id = "job-..."
operation = "legacy_iwv"
validated_parameters = {
    "date": "A20260428",
    "hour": 12,
}
```

The first step is loading the metadata from the filesystem:

```python
metadata = self._storage.load_job_metadata(job_id)
```

Then the job is marked as started:

```python
started_metadata = self._mark_started(metadata)
self._storage.update_job_metadata(started_metadata)
```

The status changes from:

```text
queued
```

to:

```text
started
```

The metadata is also updated with the start timestamp.

---

### 12. Handler selection

After marking the job as started, the worker retrieves the handler associated
with the operation:

```python
handler = get_operation_handler(operation)
```

The function `get_operation_handler()` uses the registry defined in:

```text
app/operations/registry.py
```

The registry maps operation names to Python functions.

For example:

```text
legacy_iwv     -> handle_legacy_iwv
legacy_opacity -> handle_legacy_opacity
legacy_meteo   -> handle_legacy_meteo
legacy_rain    -> handle_legacy_rain
legacy_tsys    -> handle_legacy_tsys
```

Therefore, if the job contains:

```python
operation = "legacy_iwv"
```

the worker selects the corresponding handler:

```python
handle_legacy_iwv
```

---

### 13. Handler execution

The worker executes the handler by passing the validated parameters:

```python
raw_output = handler(validated_parameters)
```

For `legacy_iwv`, the call is conceptually:

```python
handle_legacy_iwv({
    "date": "A20260428",
    "hour": 12,
})
```

Legacy handlers are defined in:

```text
app/operations/handlers/legacy_passthrough.py
```

For legacy-compatible operations, the handler delegates the work to:

```python
run_atm_ser()
```

defined in:

```text
app/integrations/atm_ser_adapter.py
```

---

### 14. Building the Octave command

Inside `run_atm_ser()`, the command to execute is built with:

```python
cmd = _build_command(operation, parameters)
```

For example, for `legacy_iwv`, the command is conceptually:

```python
[
    "octave-cli",
    "./octave/scripts/atm_ser",
    "iwv",
    "A20260428",
    "12",
]
```

which corresponds to:

```bash
octave-cli ./octave/scripts/atm_ser iwv A20260428 12
```

For `legacy_opacity`, the command may look like:

```bash
octave-cli ./octave/scripts/atm_ser opacity A20260428 12 43.0
```

For `legacy_tsys`:

```bash
octave-cli ./octave/scripts/atm_ser tsys A20260428 12 <freq> <theta> <eta> <trec>
```

---

### 15. Launching the Octave subprocess

The Octave command is executed with:

```python
completed = subprocess.run(
    cmd,
    capture_output=True,
    text=True,
    timeout=OCTAVE_TIMEOUT_SECONDS,
    check=False,
    cwd=atm_dir,
    env=env,
)
```

This means that the worker launches an external subprocess.

The Redis/RQ job is not the subprocess. The job is the description of the work. The Octave subprocess is launched during job execution.

The main `subprocess.run()` arguments are:

```python
cmd
```

List of command arguments to execute.

```python
capture_output=True
```

Captures `stdout` and `stderr`.

```python
text=True
```

Returns `stdout` and `stderr` as strings.

```python
timeout=OCTAVE_TIMEOUT_SECONDS
```

Stops the process if it exceeds the configured timeout.

```python
check=False
```

Does not automatically raise an exception if the process exits with a non-zero return code. The code checks `completed.returncode` manually.

```python
cwd=atm_dir
```

Runs the command from the directory containing the `atm_ser` script.

```python
env=env
```

Passes a modified environment to the subprocess.

In particular, the following variable is passed:

```python
env["DATA_DIR"] = str(DATA_DIR)
```

This is how the legacy backend receives the data directory path.

---

### 16. Subprocess result handling

After Octave execution, the code reads:

```python
stdout = completed.stdout.strip()
stderr = completed.stderr.strip()
```

If the process exits with a non-zero return code:

```python
if completed.returncode != 0:
```

the job fails with an Octave execution error.

If the process exits successfully but the output starts with:

```text
Error:
```

the error is interpreted as an application-level error produced by the legacy backend.

This is the case for errors such as:

```json
{
  "code": "ATM_SER_ERROR",
  "message": "file not found"
}
```

In this scenario, Octave was executed, but the legacy script produced an application error.

---

### 17. Output parsing

If the Octave command completes successfully, the textual output is converted into a Python data structure:

```python
result = _parse_output(operation, stdout, parameters)
```

For example, a `legacy_iwv` result is transformed into a structured dictionary.

For some operations, if:

```python
hour == 0
```

the request is treated as a time-series request, so the parser expects tabular output instead of a single value.

At the end, `run_atm_ser()` returns a standard structure:

```python
{
    "result": result,
    "plot_bytes": None,
}
```

For legacy-compatible operations, a JSON result is normally produced, while no plot is produced.

---

### 18. Job output validation

Control returns to:

```text
app/workers/job_worker.py
```

The worker validates the output returned by the handler:

```python
output = self._validate_output(raw_output)
```

The expected format is:

```python
{
    "result": ...,
    "plot_bytes": ...
}
```

At least one between `result` and `plot_bytes` must be present.

For legacy-compatible operations, normally:

```python
result != None
plot_bytes == None
```

---

### 19. Saving the result

If a result is present, the worker saves it through `StorageService`:

```python
if output.result is not None:
    self._storage.save_job_result(job_id, output.result)
```

The result is saved on the filesystem, for example in:

```text
JOB_STORAGE_DIR/results/<job_id>.json
```

If a plot is present, it is saved with:

```python
if output.plot_bytes is not None:
    self._storage.save_job_plot(job_id, output.plot_bytes)
```

For the current legacy-compatible operations, `plot_bytes` is normally `None`.

---

### 20. Final metadata update

If execution succeeds, the worker marks the job as completed:

```python
finished_metadata = self._mark_finished(...)
self._storage.update_job_metadata(finished_metadata)
```

The metadata is updated with information like this:

```json
{
  "status": "finished",
  "finished_at": "...",
  "has_result": true,
  "has_plot": false,
  "error": null
}
```

If something fails, the worker builds failure metadata:

```python
failed_metadata = self._build_failed_metadata(...)
self._storage.update_job_metadata(failed_metadata)
```

In that case, the job is marked as:

```json
{
  "status": "failed",
  "finished_at": "...",
  "error": {
    "code": "...",
    "message": "..."
  }
}
```

---

### 21. Client status retrieval

After creating a job, the client can query the server using the `job_id`.

Conceptually, the request is:

```text
GET /jobs/<job_id>
```

The server reads the metadata from the filesystem and returns the current state.

The job may be in one of these states:

```text
queued
started
finished
failed
```

If the job completed successfully and produced a result, the metadata contains:

```json
{
  "has_result": true
}
```

The client can then retrieve the result through the corresponding endpoint.

---

### 22. Complete flow summary

The complete flow is:

```text
Client
→ POST /legacy/command
→ Flask route create_legacy_job()
→ request body reading
→ parse_legacy_command()
→ conversion into operation + parameters
→ JobService.create_job()
→ check_operation_exists()
→ validate_and_normalize_parameters()
→ JobMetadata creation with status="queued"
→ metadata saved on the filesystem
→ QueueService.submit_job()
→ Redis/RQ payload creation
→ enqueue of worker.execute_queued_job(...)
→ HTTP response to the client

Separate RQ worker
→ worker.py listens to the queue
→ RQ dequeues the job
→ RQ calls execute_queued_job(...)
→ StorageService creation
→ JobWorker creation
→ JobWorker.execute_job()
→ metadata loading
→ status="started"
→ get_operation_handler(operation)
→ handler(validated_parameters) execution
→ for legacy operations: run_atm_ser()
→ Octave command construction
→ subprocess.run(...)
→ stdout, stderr, and return code capture
→ output parsing
→ output validation
→ result saving
→ status="finished"

or, in case of error:

→ status="failed"
→ error code and message saved in the metadata
```

---

### 23. Conceptual summary

The HTTP server does not directly execute the heavy work.

The server is responsible for:

```text
receiving the request
validating it
creating a job
saving metadata
enqueueing the job
responding to the client
```

The worker is responsible for:

```text
reading jobs from the queue
executing the requested operation
launching possible subprocesses
saving result or error
updating metadata
```

Redis/RQ separates request handling from actual execution.

This allows the HTTP server to respond quickly, while the real work is performed asynchronously by the worker.



## Current status

The repository currently supports two families of operations.

### Native operations

These are implemented directly in Python and follow the application architecture natively.

### Legacy-compatible operations

These preserve the functional behavior of the historical atmospheric backend, but they are exposed through the same `/jobs` API and return structured JSON results.

Current legacy operations:

- `legacy_iwv`
- `legacy_opacity`
- `legacy_meteo`
- `legacy_rain`
- `legacy_tsys`

The long-term direction of the project is to preserve the same public API while progressively replacing the current legacy backend implementation with native Python code.

---

## Environment variables

The project may require environment variables depending on your local configuration and backend paths.

In this project, local environment variables are typically stored in `.env`.

---

## Notes for developers

Important constraints:

- the public `/jobs` API should remain stable
- operation validation should remain strict
- workers should own execution logic, not the API layer
- results must remain JSON-serializable
- plots should remain separate resources
- backend details should not leak to clients

If you modify the legacy branch, preserve the external contract even if the internal backend changes.

---

## Future direction

The long-term goal is to keep the same public API while progressively replacing the current legacy scientific backend with native Python implementations.

That means:

- preserve the `/jobs` contract
- keep the modern architecture
- migrate legacy computations away from Octave
- eventually remove transitional legacy adapters once they are no longer needed
