"""Compatibility package for running the backend from the repository root.

The actual application package is located at ``backend/app``.  Exposing that
directory as this package's search path lets commands such as
``python -m uvicorn app.main:app`` work from the repository root as well as
from inside ``backend``.
"""

from pathlib import Path


_BACKEND_APP = Path(__file__).resolve().parent.parent / "backend" / "app"
__path__ = [str(_BACKEND_APP)]
