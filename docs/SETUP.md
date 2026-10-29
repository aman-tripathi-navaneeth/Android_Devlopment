# PharmaPro_GM — Setup and Execution Guide

## Prerequisites
- **Python**: 3.11+
- **Flutter SDK**: 3.27+ with Dart 3+
- **Web Browser**: Google Chrome (for Flutter web evaluation) or Android / Windows build tools
- **Database**: PostgreSQL (optional; backend includes an in-memory fallback store for development)

---

## 1. Running the Backend (Python FastAPI)

1. Open a terminal in the `backend/` directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. (Optional) Initialize the PostgreSQL schema and indexes:
   ```bash
   python scripts/setup_database.py
   ```

4. Launch the FastAPI server:
   ```bash
   python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
   ```

5. Access interactive API documentation:
   - **Swagger UI**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
   - **Health Check**: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)

You can also start the backend from the repository root with:

```bash
python run_backend.py
```

---

## 2. Running the Frontend (Flutter App)

1. Open a terminal in the `frontend/` directory:
   ```bash
   cd frontend
   ```

2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```

3. Run the app in Chrome on port 8080:
   ```bash
   flutter run -d chrome --web-port=8080
   ```

4. Alternatively, run on Windows desktop:
   ```bash
   flutter run -d windows
   ```

---

## 3. Running Automated Tests

### Backend Unit & Integration Tests (19 tests)
```bash
cd backend
python -m pytest tests -v
```

### Frontend Widget, Contrast & Navigation Tests (13 tests)
```bash
cd frontend
flutter test
```

---

## 4. Other Team Prototype Preview
To interactively preview Member 1's design and screens directly in your browser without compiling, open:
`other_team_frontend_preview.html`
