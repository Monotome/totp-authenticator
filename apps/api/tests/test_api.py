import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker

os.environ["DATABASE_URL"] = "sqlite:///./test_api.db"
os.environ["SECRET_KEY"] = "test-secret"

from server.main import app
from server.database import Base, get_db, engine

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

def test_health_check_endpoints():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
    assert "version" in response.json()

    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_register_and_login():
    response = client.post("/register", json={"username": "testuser", "password": "testpassword"})
    assert response.status_code == 200
    
    # Duplicate registration
    response = client.post("/register", json={"username": "testuser", "password": "testpassword"})
    assert response.status_code == 400
    
    response = client.post("/login", data={"username": "testuser", "password": "testpassword"})
    assert response.status_code == 200
    assert "access_token" in response.json()
    
    # Case-insensitive login verification (e.g. TestUser -> testuser)
    response = client.post("/login", data={"username": "TestUser", "password": "testpassword"})
    assert response.status_code == 200
    assert "access_token" in response.json()

    # Case-insensitive duplicate registration check
    response = client.post("/register", json={"username": "TestUser", "password": "testpassword"})
    assert response.status_code == 400

    # Wrong password
    response = client.post("/login", data={"username": "testuser", "password": "wrong"})
    assert response.status_code == 401


def test_registration_validation():
    # Username too short (< 3 chars)
    response = client.post("/register", json={"username": "ab", "password": "validpassword"})
    assert response.status_code == 422

    # Password too short (< 6 chars)
    response = client.post("/register", json={"username": "validuser", "password": "123"})
    assert response.status_code == 422

    # Invalid characters in username
    response = client.post("/register", json={"username": "user name!", "password": "validpassword"})
    assert response.status_code == 422

def test_sync_endpoints():
    client.post("/register", json={"username": "testuser", "password": "testpassword"})
    response = client.post("/login", data={"username": "testuser", "password": "testpassword"})
    token = response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # Get initial empty state
    response = client.get("/sync", headers=headers)
    assert response.status_code == 200
    assert response.json()["encrypted_payload"] == ""
    assert response.json()["last_updated"] == 0.0
    
    # Post first update
    payload = {"encrypted_payload": "gAAAAAB_mock_data", "last_updated": 100.0}
    response = client.post("/sync", json=payload, headers=headers)
    assert response.status_code == 200
    assert response.json()["last_updated"] == 100.0
    
    # Get to verify
    response = client.get("/sync", headers=headers)
    assert response.json()["encrypted_payload"] == "gAAAAAB_mock_data"
    assert response.json()["last_updated"] == 100.0
    
    # Post older update (conflict)
    payload_old = {"encrypted_payload": "gAAAAAB_older_data", "last_updated": 50.0}
    response = client.post("/sync", json=payload_old, headers=headers)
    assert response.status_code == 409
    assert "newer version" in response.json()["detail"]
