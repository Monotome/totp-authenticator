/// Represents a single TOTP account.
class Account {
  final String id;
  final String name;
  final String secret;
  final String issuer;

  Account({
    required this.id,
    required this.name,
    required this.secret,
    this.issuer = '',
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      secret: json['secret'] as String,
      issuer: (json['issuer'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'secret': secret,
      'issuer': issuer,
    };
  }
}
