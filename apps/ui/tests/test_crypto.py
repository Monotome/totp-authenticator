"""Tests for totp_authenticator.crypto."""

import pytest

from totp_authenticator.crypto import (
    InvalidPasswordError,
    decrypt_data,
    derive_key,
    encrypt_data,
    generate_salt,
)


def test_encryption_decryption_roundtrip():
    salt = generate_salt()
    key = derive_key("my_secure_password", salt)

    plaintext = "super_secret_data_123"
    ciphertext = encrypt_data(plaintext, key)

    assert ciphertext != plaintext
    assert isinstance(ciphertext, str)

    decrypted = decrypt_data(ciphertext, key)
    assert decrypted == plaintext


def test_decryption_fails_with_wrong_password():
    salt = generate_salt()
    # Encrypt with correct password
    key = derive_key("correct_password", salt)
    ciphertext = encrypt_data("some_data", key)

    # Try to decrypt with wrong password
    wrong_key = derive_key("wrong_password", salt)

    with pytest.raises(InvalidPasswordError) as exc_info:
        decrypt_data(ciphertext, wrong_key)

    assert "Invalid password" in str(exc_info.value)


def test_decryption_fails_with_wrong_salt():
    correct_salt = generate_salt()
    wrong_salt = generate_salt()

    key = derive_key("password", correct_salt)
    ciphertext = encrypt_data("some_data", key)

    wrong_key = derive_key("password", wrong_salt)

    with pytest.raises(InvalidPasswordError):
        decrypt_data(ciphertext, wrong_key)


def test_decryption_fails_with_corrupted_data():
    salt = generate_salt()
    key = derive_key("password", salt)
    ciphertext = encrypt_data("some_data", key)

    # Modifying the ciphertext even slightly
    corrupted_ciphertext = ciphertext[:-5] + "AAAAA"

    with pytest.raises(InvalidPasswordError):
        decrypt_data(corrupted_ciphertext, key)
