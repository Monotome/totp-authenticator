"""Tests for totp_authenticator.parser."""

import pytest

from totp_authenticator.parser import InvalidURIError, parse_uri


def test_parse_valid_google_auth_uri():
    uri = "otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
    account = parse_uri(uri)
    assert account.name == "Example:alice@google.com"
    assert account.secret == "JBSWY3DPEHPK3PXP"


def test_parse_valid_uri_without_issuer():
    uri = "otpauth://totp/alice@google.com?secret=JBSWY3DPEHPK3PXP"
    account = parse_uri(uri)
    assert account.name == "alice@google.com"
    assert account.secret == "JBSWY3DPEHPK3PXP"


def test_parse_valid_uri_without_path_but_with_issuer():
    uri = "otpauth://totp/?secret=JBSWY3DPEHPK3PXP&issuer=GitHub"
    account = parse_uri(uri)
    assert account.name == "GitHub"
    assert account.secret == "JBSWY3DPEHPK3PXP"


def test_parse_uri_fixes_base32_padding():
    # Base32 secrets often have padding '=' signs removed in URIs
    # WJKCQSIP4YWKZBTH4ICWOLU323T4SYLG length is 32 (multiple of 8, no padding)
    # P5BCS6BUKFD3NAO6 length is 16
    uri = "otpauth://totp/Test?secret=P5BCS6BUKFD3NAO6"
    account = parse_uri(uri)
    assert account.secret == "P5BCS6BUKFD3NAO6"

    # Let's test an odd length one that needs padding
    uri = "otpauth://totp/Test?secret=JBSWY3DP" # length 8
    account = parse_uri(uri)
    assert account.secret == "JBSWY3DP"


def test_parse_invalid_scheme():
    with pytest.raises(InvalidURIError) as exc:
        parse_uri("http://totp/Test?secret=JBSWY3DPEHPK3PXP")
    assert "Expected 'otpauth://'" in str(exc.value)


def test_parse_invalid_type_hotp():
    with pytest.raises(InvalidURIError) as exc:
        parse_uri("otpauth://hotp/Test?secret=JBSWY3DPEHPK3PXP")
    assert "Only 'totp'" in str(exc.value)


def test_parse_missing_secret():
    with pytest.raises(InvalidURIError) as exc:
        parse_uri("otpauth://totp/Test?issuer=Test")
    assert "missing the 'secret' parameter" in str(exc.value)


def test_parse_invalid_base32_secret():
    with pytest.raises(InvalidURIError) as exc:
        parse_uri("otpauth://totp/Test?secret=INVALID89!@#")
    assert "not valid base32" in str(exc.value)


def test_parse_empty_strings():
    with pytest.raises(InvalidURIError):
        parse_uri("")

    with pytest.raises(InvalidURIError):
        parse_uri("   ")
