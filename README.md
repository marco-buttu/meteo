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
