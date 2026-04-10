from __future__ import annotations

from flask import Flask

from app import config as app_config
from app.api.errors import register_error_handlers
from app.api.routes import register_routes
from app.services.job_service import JobService
from app.services.queue_service import QueueService
from app.services.storage_service import StorageService


def create_app() -> Flask:
    app = Flask(__name__)


    # Ensure runtime directories exist
    app_config.JOB_STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    app_config.PLOT_STORAGE_DIR.mkdir(parents=True, exist_ok=True)

    app.config.update(
        JOB_STORAGE_DIR=app_config.JOB_STORAGE_DIR,
        PLOT_STORAGE_DIR=app_config.PLOT_STORAGE_DIR,
        REDIS_URL=app_config.REDIS_URL,
        RQ_QUEUE_NAME=app_config.RQ_QUEUE_NAME,
        OCTAVE_TIMEOUT_SECONDS=app_config.OCTAVE_TIMEOUT_SECONDS,
        FLASK_HOST=app_config.FLASK_HOST,
        FLASK_PORT=app_config.FLASK_PORT,
        FLASK_DEBUG=app_config.FLASK_DEBUG,
    )

    storage_service = StorageService(
        root_dir=app_config.JOB_STORAGE_DIR,
        plot_dir=app_config.PLOT_STORAGE_DIR,
    )
    queue_service = QueueService(
        redis_url=app_config.REDIS_URL,
        queue_name=app_config.RQ_QUEUE_NAME,
    )
    job_service = JobService(
        storage_service=storage_service,
        queue_service=queue_service,
    )

    app.extensions['storage_service'] = storage_service
    app.extensions['queue_service'] = queue_service
    app.extensions['job_service'] = job_service

    register_routes(app)
    register_error_handlers(app)

    return app
