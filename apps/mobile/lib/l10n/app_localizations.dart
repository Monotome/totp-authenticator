import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// AppLocalizations provides compile-time safe, typed translations for Vietnamese and English.
abstract class AppLocalizations {
  static const supportedLocales = [
    Locale('vi'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        _vi;
  }

  static AppLocalizations fromLocale(Locale locale) {
    if (locale.languageCode == 'en') {
      return _en;
    }
    return _vi;
  }

  static final AppLocalizations _vi = _AppLocalizationsVi();
  static final AppLocalizations _en = _AppLocalizationsEn();

  // ── Common ──
  String get appName;
  String get save;
  String get cancel;
  String get delete;
  String get confirm;
  String get copiedToClipboard;
  String get unknown;
  String get importText;
  String get error;
  String get close;

  // ── Home Screen ──
  String get settingsTooltip;
  String get emptyAccountsTitle;
  String get emptyAccountsSubtitle;
  String get addAccountButton;
  String get addAccountModalTitle;
  String get scanQrOption;
  String get enterManualOption;
  String get refreshingIn;
  String get tapToCopy;
  String get deleteAccountDialogTitle;
  String deleteAccountDialogMessage(String accountName);

  // ── Add Account Screen ──
  String get addAccountTitle;
  String get editAccountTitle;
  String get accountNameLabel;
  String get accountNameHint;
  String get accountNameError;
  String get secretKeyLabel;
  String get secretKeyHint;
  String get secretKeyErrorEmpty;
  String get secretKeyErrorInvalid;
  String get issuerLabel;
  String get issuerHint;
  String get pasteUriButton;
  String get enterUriDialogTitle;
  String get enterUriDialogHint;
  String get extractSuccess;
  String accountSavedMessage(String accountName);

  // ── Scan Screen ──
  String get scanTitle;
  String get scanInstruction;
  String get flashTooltip;
  String get cameraSwitchTooltip;
  String get enterManualFallback;
  String get scanConfirmTitle;
  String get scanCurrentCode;
  String get saveAccountButton;
  String get scanAgainButton;
  String get cameraAccessDenied;
  String get cameraPermissionPrompt;

  // ── Lock Screen ──
  String get lockTitle;
  String lockSubtitle(String biometricName);
  String unlockButton(String biometricName);
  String get authenticating;
  String get secureHardwareReassurance;

  // ── Settings Screen ──
  String get settingsTitle;

  // Section 1: Cloud Sync
  String get cloudSyncSectionTitle;
  String get zkBannerTitle;
  String get zkBannerBody;
  String get serverUrlLabel;
  String get serverPresetsLabel;
  String get usernameLabel;
  String get passwordLabel;
  String get loginButton;
  String get registerSwitchButton;
  String get registerButton;
  String get loginSwitchButton;
  String get statusConnected;
  String get syncNowButton;
  String get pullButton;
  String get pushButton;
  String get logoutButton;
  String get lastSyncLabel;
  String get syncingStatus;
  String get rememberPasswordTitle;
  String get rememberPasswordSaved;
  String get rememberPasswordPrompt;
  String get forgetPasswordSuccess;
  String get syncSuccessMessage;
  String get pullSuccessMessage;
  String get pushSuccessMessage;

  // Section 2: Security & Biometrics
  String get securitySectionTitle;
  String get securityCardTitle;
  String biometricTitle(String biometricName);
  String get biometricSubtitleEnabled;
  String get biometricSubtitleDisabled;
  String get biometricSubtitleUnsupported;
  String get autoLockLabel;
  String get autoLockImmediate;
  String autoLockSeconds(int seconds);
  String autoLockMinutes(int minutes);
  String get lockNowButton;
  String get authFailedError;

  // Section 3: Appearance & Language
  String get appearanceAndLanguageSectionTitle;
  String get appearanceAndLanguageCardTitle;
  String get themeLabel;
  String get themeSystem;
  String get themeDark;
  String get themeLight;
  String get languageLabel;
  String get languageSystem;
  String get languageVi;
  String get languageEn;

  // Section 4: System Information
  String get systemInfoSectionTitle;
  String get appInfoTitle;
  String get versionLabel;
  String get twoFaStandardLabel;
  String get e2eeAlgorithmLabel;
  String get keyDerivationLabel;

  // ── Sync Password Dialog ──
  String get vaultPasswordTitle;
  String get vaultPasswordDescription;
  String get vaultPasswordLabel;
  String get vaultPasswordErrorEmpty;
  String get rememberOnDevice;

  // ── Form Validations & Cloud Sync Status ──
  String get serverUrlErrorEmpty;
  String get usernameErrorEmpty;
  String get passwordErrorEmpty;
  String get passwordErrorMinLength;
  String get registerSuccessMessage;
  String get loginSuccessMessage;
  String get neverSynced;

  // ── Biometrics & Credentials ──
  String get biometricFace;
  String get biometricFingerprint;
  String get biometricIris;
  String get biometricGeneric;
  String get biometricPinPasscode;
  String getBiometricName(List<BiometricType> types);

  // ── Misc ──
  String get orDivider;
}

/// Vietnamese translations.
class _AppLocalizationsVi implements AppLocalizations {
  @override
  String get appName => 'TOTP Authenticator';
  @override
  String get save => 'Lưu';
  @override
  String get cancel => 'Hủy';
  @override
  String get delete => 'Xóa';
  @override
  String get confirm => 'Xác nhận';
  @override
  String get copiedToClipboard => '✅ Đã sao chép mã vào khay nhớ tạm!';
  @override
  String get unknown => 'Không xác định';
  @override
  String get importText => 'Nhập';
  @override
  String get error => 'Lỗi';
  @override
  String get close => 'Đóng';

  @override
  String get settingsTooltip => 'Cài đặt & Cloud Sync';
  @override
  String get emptyAccountsTitle => 'Chưa có tài khoản 2FA';
  @override
  String get emptyAccountsSubtitle =>
      'Nhấn nút "+ Thêm tài khoản" để bắt đầu bảo vệ các tài khoản trực tuyến của bạn.';
  @override
  String get addAccountButton => 'Thêm tài khoản';
  @override
  String get addAccountModalTitle => 'Thêm tài khoản 2FA';
  @override
  String get scanQrOption => 'Quét mã QR';
  @override
  String get enterManualOption => 'Nhập khóa thiết lập thủ công';
  @override
  String get refreshingIn => 'Làm mới sau';
  @override
  String get tapToCopy => 'Chạm để sao chép';
  @override
  String get deleteAccountDialogTitle => 'Xóa tài khoản?';
  @override
  String deleteAccountDialogMessage(String accountName) =>
      'Bạn có chắc chắn muốn xóa vĩnh viễn "$accountName"?';

  @override
  String get addAccountTitle => 'Thêm tài khoản';
  @override
  String get editAccountTitle => 'Chỉnh sửa tài khoản';
  @override
  String get accountNameLabel => 'Tên tài khoản (Email, Username)';
  @override
  String get accountNameHint => 'Ví dụ: user@gmail.com';
  @override
  String get accountNameError => 'Vui lòng nhập tên tài khoản';
  @override
  String get secretKeyLabel => 'Khóa bí mật (Secret Key)';
  @override
  String get secretKeyHint => 'Ví dụ: JBSWY3DPEHPK3PXP';
  @override
  String get secretKeyErrorEmpty => 'Vui lòng nhập khóa bí mật';
  @override
  String get secretKeyErrorInvalid => 'Khóa bí mật không hợp lệ (chuỗi Base32)';
  @override
  String get issuerLabel => 'Nhà phát hành (Google, GitHub...)';
  @override
  String get issuerHint => 'Ví dụ: Google';
  @override
  String get pasteUriButton => 'Dán URI otpauth://';
  @override
  String get enterUriDialogTitle => 'Nhập URI otpauth://';
  @override
  String get enterUriDialogHint => 'otpauth://totp/...';
  @override
  String get extractSuccess => '✅ Đã trích xuất thông tin tài khoản thành công!';
  @override
  String accountSavedMessage(String accountName) =>
      '✅ Đã lưu tài khoản "$accountName"';

  @override
  String get scanTitle => 'Quét mã QR 2FA';
  @override
  String get scanInstruction =>
      'Hướng camera về phía mã QR trên màn hình hoặc tài liệu';
  @override
  String get flashTooltip => 'Bật/Tắt đèn flash';
  @override
  String get cameraSwitchTooltip => 'Đổi camera';
  @override
  String get enterManualFallback => 'Nhập thủ công';
  @override
  String get scanConfirmTitle => 'Xác nhận tài khoản 2FA';
  @override
  String get scanCurrentCode => 'Mã xác thực hiện tại:';
  @override
  String get saveAccountButton => 'Lưu tài khoản này';
  @override
  String get scanAgainButton => 'Quét lại';
  @override
  String get cameraAccessDenied => 'Không thể truy cập máy ảnh';
  @override
  String get cameraPermissionPrompt =>
      'Vui lòng cấp quyền máy ảnh trong Cài đặt để quét mã QR.';

  @override
  String get lockTitle => 'Ứng dụng đã bị khóa';
  @override
  String lockSubtitle(String biometricName) =>
      'Xác thực bằng $biometricName để truy cập các mã 2FA của bạn an toàn.';
  @override
  String unlockButton(String biometricName) => 'Mở khóa bằng $biometricName';
  @override
  String get authenticating => 'Đang xác thực...';
  @override
  String get secureHardwareReassurance =>
      'Bảo vệ bằng phần cứng an toàn của thiết bị';

  @override
  String get settingsTitle => 'Cài đặt & Cloud Sync';

  @override
  String get cloudSyncSectionTitle => 'ĐỒNG BỘ ĐÁM MÂY (E2EE)';
  @override
  String get zkBannerTitle => 'Bảo mật Zero-Knowledge (E2EE)';
  @override
  String get zkBannerBody =>
      'Máy chủ chỉ lưu trữ blob mã hóa. Khóa mật mã không bao giờ rời khỏi thiết bị.';
  @override
  String get serverUrlLabel => 'Địa chỉ máy chủ (Server URL)';
  @override
  String get serverPresetsLabel => 'Gợi ý:';
  @override
  String get usernameLabel => 'Tên người dùng';
  @override
  String get passwordLabel => 'Mật khẩu tài khoản';
  @override
  String get loginButton => 'Đăng nhập';
  @override
  String get registerSwitchButton =>
      'Chưa có tài khoản trên máy chủ? Đăng ký ngay';
  @override
  String get registerButton => 'Đăng ký';
  @override
  String get loginSwitchButton => 'Đã có tài khoản? Đăng nhập';
  @override
  String get statusConnected => 'Đã kết nối';
  @override
  String get syncNowButton => 'Đồng bộ ngay (Sync Now)';
  @override
  String get pullButton => 'Kéo về (Pull)';
  @override
  String get pushButton => 'Đẩy lên (Push)';
  @override
  String get logoutButton => 'Đăng xuất';
  @override
  String get lastSyncLabel => 'Đồng bộ gần nhất';
  @override
  String get syncingStatus => 'Đang đồng bộ...';
  @override
  String get rememberPasswordTitle => 'Ghi nhớ mật khẩu E2EE';
  @override
  String get rememberPasswordSaved => 'Đã lưu an toàn trong Keystore';
  @override
  String get rememberPasswordPrompt => 'Hỏi mật khẩu mỗi lần đồng bộ';
  @override
  String get forgetPasswordSuccess =>
      'Đã xóa mật khẩu E2EE khỏi bộ nhớ bảo mật.';
  @override
  String get syncSuccessMessage => 'Đồng bộ hai chiều thành công!';
  @override
  String get pullSuccessMessage => 'Kéo dữ liệu thành công!';
  @override
  String get pushSuccessMessage => 'Đẩy dữ liệu thành công!';

  @override
  String get securitySectionTitle => 'BẢO MẬT & SINH TRẮC HỌC';
  @override
  String get securityCardTitle => 'Bảo mật ứng dụng';
  @override
  String biometricTitle(String biometricName) => 'Khóa bằng $biometricName';
  @override
  String get biometricSubtitleEnabled =>
      'Yêu cầu xác thực mỗi khi mở ứng dụng';
  @override
  String get biometricSubtitleDisabled => 'Bảo vệ mã 2FA khỏi người lạ';
  @override
  String get biometricSubtitleUnsupported =>
      'Thiết bị không hỗ trợ hoặc chưa đăng ký sinh trắc học';
  @override
  String get autoLockLabel => 'Tự động khóa sau';
  @override
  String get autoLockImmediate => 'Ngay lập tức';
  @override
  String autoLockSeconds(int seconds) => '$seconds giây';
  @override
  String autoLockMinutes(int minutes) => '$minutes phút';
  @override
  String get lockNowButton => 'Khóa ứng dụng ngay (Lock Now)';
  @override
  String get authFailedError =>
      'Xác thực thất bại. Không thể thay đổi cài đặt.';

  @override
  String get appearanceAndLanguageSectionTitle => 'GIAO DIỆN & NGÔN NGỮ';
  @override
  String get appearanceAndLanguageCardTitle => 'Tùy chọn hiển thị';
  @override
  String get themeLabel => 'Chủ đề giao diện';
  @override
  String get themeSystem => 'Hệ thống';
  @override
  String get themeDark => 'Tối';
  @override
  String get themeLight => 'Sáng';
  @override
  String get languageLabel => 'Ngôn ngữ hiển thị';
  @override
  String get languageSystem => 'Mặc định hệ thống';
  @override
  String get languageVi => 'Tiếng Việt 🇻🇳';
  @override
  String get languageEn => 'English 🇬🇧';

  @override
  String get systemInfoSectionTitle => 'THÔNG TIN HỆ THỐNG';
  @override
  String get appInfoTitle => 'Thông tin ứng dụng';
  @override
  String get versionLabel => 'Phiên bản';
  @override
  String get twoFaStandardLabel => 'Tiêu chuẩn 2FA';
  @override
  String get e2eeAlgorithmLabel => 'Thuật toán E2EE';
  @override
  String get keyDerivationLabel => 'Dẫn xuất khóa';

  @override
  String get vaultPasswordTitle => 'Mật khẩu mã hóa (E2EE)';
  @override
  String get vaultPasswordDescription =>
      'Mật khẩu này được sử dụng để dẫn xuất khóa AES-256 mã hóa/giải mã toàn bộ tài khoản 2FA của bạn.';
  @override
  String get vaultPasswordLabel => 'Mật khẩu mã hóa';
  @override
  String get vaultPasswordErrorEmpty => 'Vui lòng nhập mật khẩu mã hóa.';
  @override
  String get rememberOnDevice =>
      'Ghi nhớ trên thiết bị này (lưu trong Keystore)';

  @override
  String get serverUrlErrorEmpty => 'Vui lòng nhập địa chỉ máy chủ';
  @override
  String get usernameErrorEmpty => 'Vui lòng nhập tên người dùng';
  @override
  String get passwordErrorEmpty => 'Vui lòng nhập mật khẩu';
  @override
  String get passwordErrorMinLength => 'Mật khẩu phải từ 6 ký tự trở lên';
  @override
  String get registerSuccessMessage =>
      'Đăng ký thành công! Vui lòng đăng nhập.';
  @override
  String get loginSuccessMessage => 'Đăng nhập thành công!';
  @override
  String get neverSynced => 'Chưa đồng bộ';

  @override
  String get biometricFace => 'Khuôn mặt (Face ID)';
  @override
  String get biometricFingerprint => 'Vân tay (Fingerprint)';
  @override
  String get biometricIris => 'Mống mắt (Iris)';
  @override
  String get biometricGeneric => 'Sinh trắc học';
  @override
  String get biometricPinPasscode => 'Mã PIN / Mật khẩu máy';

  @override
  String getBiometricName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) return biometricFace;
    if (types.contains(BiometricType.fingerprint)) return biometricFingerprint;
    if (types.contains(BiometricType.iris)) return biometricIris;
    if (types.isNotEmpty) return biometricGeneric;
    return biometricPinPasscode;
  }

  @override
  String get orDivider => 'hoặc';
}

/// English translations.
class _AppLocalizationsEn implements AppLocalizations {
  @override
  String get appName => 'TOTP Authenticator';
  @override
  String get save => 'Save';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get confirm => 'Confirm';
  @override
  String get copiedToClipboard => '✅ Code copied to clipboard!';
  @override
  String get unknown => 'Unknown';
  @override
  String get importText => 'Import';
  @override
  String get error => 'Error';
  @override
  String get close => 'Close';

  @override
  String get settingsTooltip => 'Settings & Cloud Sync';
  @override
  String get emptyAccountsTitle => 'No 2FA Accounts Yet';
  @override
  String get emptyAccountsSubtitle =>
      'Tap "+ Add Account" to start securing your online accounts.';
  @override
  String get addAccountButton => 'Add Account';
  @override
  String get addAccountModalTitle => 'Add 2FA Account';
  @override
  String get scanQrOption => 'Scan QR Code';
  @override
  String get enterManualOption => 'Enter setup key manually';
  @override
  String get refreshingIn => 'Refreshing in';
  @override
  String get tapToCopy => 'Tap to copy';
  @override
  String get deleteAccountDialogTitle => 'Delete Account?';
  @override
  String deleteAccountDialogMessage(String accountName) =>
      'Are you sure you want to permanently remove "$accountName"?';

  @override
  String get addAccountTitle => 'Add Account';
  @override
  String get editAccountTitle => 'Edit Account';
  @override
  String get accountNameLabel => 'Account Name (Email, Username)';
  @override
  String get accountNameHint => 'e.g. user@gmail.com';
  @override
  String get accountNameError => 'Please enter account name';
  @override
  String get secretKeyLabel => 'Secret Key';
  @override
  String get secretKeyHint => 'e.g. JBSWY3DPEHPK3PXP';
  @override
  String get secretKeyErrorEmpty => 'Please enter secret key';
  @override
  String get secretKeyErrorInvalid => 'Invalid secret key (Base32 encoded)';
  @override
  String get issuerLabel => 'Issuer (Google, GitHub...)';
  @override
  String get issuerHint => 'e.g. Google';
  @override
  String get pasteUriButton => 'Paste otpauth:// URI';
  @override
  String get enterUriDialogTitle => 'Enter otpauth:// URI';
  @override
  String get enterUriDialogHint => 'otpauth://totp/...';
  @override
  String get extractSuccess => '✅ Account information extracted successfully!';
  @override
  String accountSavedMessage(String accountName) =>
      '✅ Saved account "$accountName"';

  @override
  String get scanTitle => 'Scan 2FA QR Code';
  @override
  String get scanInstruction => 'Point camera at QR code on screen or document';
  @override
  String get flashTooltip => 'Toggle Flash';
  @override
  String get cameraSwitchTooltip => 'Switch Camera';
  @override
  String get enterManualFallback => 'Enter Manually';
  @override
  String get scanConfirmTitle => 'Confirm 2FA Account';
  @override
  String get scanCurrentCode => 'Current verification code:';
  @override
  String get saveAccountButton => 'Save this Account';
  @override
  String get scanAgainButton => 'Scan Again';
  @override
  String get cameraAccessDenied => 'Unable to access camera';
  @override
  String get cameraPermissionPrompt =>
      'Please grant camera permission in Settings to scan QR codes.';

  @override
  String get lockTitle => 'Application Locked';
  @override
  String lockSubtitle(String biometricName) =>
      'Authenticate with $biometricName to securely access your 2FA codes.';
  @override
  String unlockButton(String biometricName) => 'Unlock with $biometricName';
  @override
  String get authenticating => 'Authenticating...';
  @override
  String get secureHardwareReassurance =>
      'Protected by device secure hardware';

  @override
  String get settingsTitle => 'Settings & Cloud Sync';

  @override
  String get cloudSyncSectionTitle => 'CLOUD SYNC (E2EE)';
  @override
  String get zkBannerTitle => 'Zero-Knowledge Security (E2EE)';
  @override
  String get zkBannerBody =>
      'Server only stores encrypted blobs. Cryptographic keys never leave your device.';
  @override
  String get serverUrlLabel => 'Server Address (URL)';
  @override
  String get serverPresetsLabel => 'Presets:';
  @override
  String get usernameLabel => 'Username';
  @override
  String get passwordLabel => 'Account Password';
  @override
  String get loginButton => 'Log In';
  @override
  String get registerSwitchButton =>
      "Don't have an account on server? Register now";
  @override
  String get registerButton => 'Register';
  @override
  String get loginSwitchButton => 'Already have an account? Log In';
  @override
  String get statusConnected => 'Connected';
  @override
  String get syncNowButton => 'Sync Now';
  @override
  String get pullButton => 'Pull';
  @override
  String get pushButton => 'Push';
  @override
  String get logoutButton => 'Log Out';
  @override
  String get lastSyncLabel => 'Last Synced';
  @override
  String get syncingStatus => 'Syncing...';
  @override
  String get rememberPasswordTitle => 'Remember E2EE Password';
  @override
  String get rememberPasswordSaved => 'Securely saved in Keystore';
  @override
  String get rememberPasswordPrompt => 'Prompt password on each sync';
  @override
  String get forgetPasswordSuccess =>
      'Removed E2EE password from secure storage.';
  @override
  String get syncSuccessMessage => 'Two-way sync completed successfully!';
  @override
  String get pullSuccessMessage => 'Pull completed successfully!';
  @override
  String get pushSuccessMessage => 'Push completed successfully!';

  @override
  String get securitySectionTitle => 'SECURITY & BIOMETRICS';
  @override
  String get securityCardTitle => 'App Security';
  @override
  String biometricTitle(String biometricName) => 'Lock with $biometricName';
  @override
  String get biometricSubtitleEnabled =>
      'Require authentication whenever app is opened';
  @override
  String get biometricSubtitleDisabled => 'Protect 2FA codes from others';
  @override
  String get biometricSubtitleUnsupported =>
      'Biometrics not supported or not enrolled on this device';
  @override
  String get autoLockLabel => 'Auto-lock after';
  @override
  String get autoLockImmediate => 'Immediately';
  @override
  String autoLockSeconds(int seconds) => '$seconds seconds';
  @override
  String autoLockMinutes(int minutes) => '$minutes minutes';
  @override
  String get lockNowButton => 'Lock App Now';
  @override
  String get authFailedError =>
      'Authentication failed. Settings were not changed.';

  @override
  String get appearanceAndLanguageSectionTitle => 'APPEARANCE & LANGUAGE';
  @override
  String get appearanceAndLanguageCardTitle => 'Display Options';
  @override
  String get themeLabel => 'App Theme';
  @override
  String get themeSystem => 'System';
  @override
  String get themeDark => 'Dark';
  @override
  String get themeLight => 'Light';
  @override
  String get languageLabel => 'Display Language';
  @override
  String get languageSystem => 'System default';
  @override
  String get languageVi => 'Tiếng Việt 🇻🇳';
  @override
  String get languageEn => 'English 🇬🇧';

  @override
  String get systemInfoSectionTitle => 'SYSTEM INFORMATION';
  @override
  String get appInfoTitle => 'Application Info';
  @override
  String get versionLabel => 'Version';
  @override
  String get twoFaStandardLabel => '2FA Standard';
  @override
  String get e2eeAlgorithmLabel => 'E2EE Algorithm';
  @override
  String get keyDerivationLabel => 'Key Derivation';

  @override
  String get vaultPasswordTitle => 'Vault Encryption Password (E2EE)';
  @override
  String get vaultPasswordDescription =>
      'This password derives the AES-256 key used to encrypt/decrypt all your 2FA accounts.';
  @override
  String get vaultPasswordLabel => 'Encryption Password';
  @override
  String get vaultPasswordErrorEmpty => 'Please enter encryption password.';
  @override
  String get rememberOnDevice =>
      'Remember on this device (secure Keystore)';

  @override
  String get serverUrlErrorEmpty => 'Please enter server URL';
  @override
  String get usernameErrorEmpty => 'Please enter username';
  @override
  String get passwordErrorEmpty => 'Please enter password';
  @override
  String get passwordErrorMinLength => 'Password must be at least 6 characters';
  @override
  String get registerSuccessMessage =>
      'Registration successful! Please log in.';
  @override
  String get loginSuccessMessage => 'Login successful!';
  @override
  String get neverSynced => 'Never synced';

  @override
  String get biometricFace => 'Face ID / Facial Recognition';
  @override
  String get biometricFingerprint => 'Fingerprint';
  @override
  String get biometricIris => 'Iris Recognition';
  @override
  String get biometricGeneric => 'Biometrics';
  @override
  String get biometricPinPasscode => 'Device Passcode / PIN';

  @override
  String getBiometricName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) return biometricFace;
    if (types.contains(BiometricType.fingerprint)) return biometricFingerprint;
    if (types.contains(BiometricType.iris)) return biometricIris;
    if (types.isNotEmpty) return biometricGeneric;
    return biometricPinPasscode;
  }

  @override
  String get orDivider => 'or';
}

/// Localizations delegate that integrates with MaterialApp.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['vi', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations.fromLocale(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

/// Extension on BuildContext for quick access to translations.
extension LocalizationExt on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
