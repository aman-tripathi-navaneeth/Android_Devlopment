"""Start the FastAPI backend from the repository root.

The application package lives in ``backend/app``.  Running Uvicorn from the
repository root directly with ``app.main:app`` therefore fails because the
``backend`` directory is not on Python's import path.  This small launcher
keeps the documented ``app.main:app`` import path and works from any cwd.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
BACKEND = ROOT / "backend"

# Make ``app`` importable before Uvicorn imports the application target.
sys.path.insert(0, str(BACKEND))
os.chdir(BACKEND)

import uvicorn  # noqa: E402


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host=os.getenv("BACKEND_HOST", "127.0.0.1"),
        port=int(os.getenv("BACKEND_PORT", "8000")),
        reload=os.getenv("BACKEND_RELOAD", "true").lower() in {"1", "true", "yes"},
    )
