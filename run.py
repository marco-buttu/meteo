from __future__ import annotations

import sys
from pathlib import Path

if __package__ in {None, ''}:
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from app import create_app


app = create_app()


if __name__ == '__main__':
    app.run(
        host=app.config['FLASK_HOST'],
        port=app.config['FLASK_PORT'],
        debug=app.config['FLASK_DEBUG'],
    )
