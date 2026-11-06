import jwt
from typing import Annotated

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from pydantic import BaseModel

from . import models, auth, database

# Create tables
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="TOTP Sync API", version="0.8.3")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

# --- Schemas ---
class UserCreate(BaseModel):
    username: str
    password: str

class SyncPayload(BaseModel):
    encrypted_payload: str
    last_updated: float

class SyncResponse(BaseModel):
    encrypted_payload: str | None
    last_updated: float

# --- Dependencies ---
def get_current_user(token: Annotated[str, Depends(oauth2_scheme)], db: Session = Depends(database.get_db)) -> models.User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, auth.SECRET_KEY, algorithms=[auth.ALGORITHM])
        username: str | None = payload.get("sub")
        if username is None:
            raise credentials_exception
    except jwt.PyJWTError as e:
        raise credentials_exception from e

    user = db.query(models.User).filter(models.User.username == username).first()
    if user is None:
        raise credentials_exception
    return user

# --- Routes ---
@app.get("/")
def root():
    return {
        "status": "healthy",
        "service": "TOTP Authenticator Cloud Sync API",
        "version": "0.8.3",
    }

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/register")
def register(user: UserCreate, db: Session = Depends(database.get_db)) -> dict[str, str]:
    db_user = db.query(models.User).filter(models.User.username == user.username).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")

    hashed_password = auth.get_password_hash(user.password)
    new_user = models.User(username=user.username, hashed_password=hashed_password)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Initialize empty sync state
    sync_data = models.SyncData(user_id=new_user.id, last_updated=0.0, encrypted_payload="")
    db.add(sync_data)
    db.commit()

    return {"message": "User created successfully"}

@app.post("/login")
def login(form_data: Annotated[OAuth2PasswordRequestForm, Depends()], db: Session = Depends(database.get_db)) -> dict[str, str]:
    user = db.query(models.User).filter(models.User.username == form_data.username).first()
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = auth.create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/sync", response_model=SyncResponse)
def get_sync_data(current_user: Annotated[models.User, Depends(get_current_user)], db: Session = Depends(database.get_db)) -> dict[str, str | float | None]:
    sync_data = db.query(models.SyncData).filter(models.SyncData.user_id == current_user.id).first()
    if not sync_data:
        sync_data = models.SyncData(user_id=current_user.id, last_updated=0.0, encrypted_payload="")
        db.add(sync_data)
        db.commit()
        db.refresh(sync_data)

    return {"encrypted_payload": sync_data.encrypted_payload, "last_updated": sync_data.last_updated}

@app.post("/sync")
def post_sync_data(payload: SyncPayload, current_user: Annotated[models.User, Depends(get_current_user)], db: Session = Depends(database.get_db)) -> dict[str, str | float]:
    sync_data = db.query(models.SyncData).filter(models.SyncData.user_id == current_user.id).first()
    if not sync_data:
        sync_data = models.SyncData(user_id=current_user.id, last_updated=0.0, encrypted_payload="")
        db.add(sync_data)
        db.commit()
        db.refresh(sync_data)

    # Last-Write-Wins Check
    if sync_data.last_updated > payload.last_updated:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Server has a newer version. Please Pull first."
        )

    sync_data.encrypted_payload = payload.encrypted_payload
    sync_data.last_updated = payload.last_updated
    db.commit()

    return {"message": "Sync successful", "last_updated": sync_data.last_updated}
