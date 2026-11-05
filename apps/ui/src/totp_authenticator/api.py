"""API Client for connecting to the Cloud Sync Server."""

import httpx


class SyncClientError(Exception):
    """Base exception for API errors."""

class AuthenticationError(SyncClientError):
    """Raised when login fails or token is invalid."""

class ConflictError(SyncClientError):
    """Raised when trying to push but server has a newer version."""

class SyncClient:
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.token: str | None = None

    def set_token(self, token: str) -> None:
        """Set the active JWT token for authentication."""
        self.token = token

    def _headers(self) -> dict[str, str]:
        if not self.token:
            raise AuthenticationError("No authentication token available.")
        return {"Authorization": f"Bearer {self.token}"}

    def register(self, username: str, password: str) -> None:
        """Register a new account."""
        url = f"{self.base_url}/register"
        with httpx.Client() as client:
            resp = client.post(url, json={"username": username, "password": password})
            if resp.status_code == 400:
                raise SyncClientError("Username already registered.")
            resp.raise_for_status()

    def login(self, username: str, password: str) -> str:
        """Login and return the JWT token."""
        url = f"{self.base_url}/login"
        with httpx.Client() as client:
            resp = client.post(url, data={"username": username, "password": password})
            if resp.status_code == 401:
                raise AuthenticationError("Incorrect username or password.")
            resp.raise_for_status()

            data = resp.json()
            token: str = data["access_token"]
            self.set_token(token)
            return token

    def pull_sync_data(self) -> dict[str, str | float]:
        """
        Pull the latest sync data from the server.
        Returns:
            {"encrypted_payload": str, "last_updated": float}
        """
        url = f"{self.base_url}/sync"
        with httpx.Client() as client:
            resp = client.get(url, headers=self._headers())
            if resp.status_code == 401:
                raise AuthenticationError("Session expired. Please login again.")
            resp.raise_for_status()
            return resp.json()

    def push_sync_data(self, payload: str, last_updated: float) -> dict[str, str | float]:
        """
        Push new sync data to the server.
        """
        url = f"{self.base_url}/sync"
        data = {
            "encrypted_payload": payload,
            "last_updated": last_updated
        }
        with httpx.Client() as client:
            resp = client.post(url, json=data, headers=self._headers())
            if resp.status_code == 401:
                raise AuthenticationError("Session expired. Please login again.")
            if resp.status_code == 409:
                raise ConflictError("Server has a newer version. Please Pull first.")
            resp.raise_for_status()
            return resp.json()
