class TeamMember {
  const TeamMember({
    required this.teamMemberId,
    required this.providerProfileId,
    required this.displayName,
    this.email,
    this.role,
  });

  final String teamMemberId;
  final String providerProfileId;
  final String displayName;
  final String? email;
  final String? role;

  Map<String, dynamic> toMap() => {
        'teamMemberId': teamMemberId,
        'providerProfileId': providerProfileId,
        'displayName': displayName,
        'email': email,
        'role': role,
      };

  factory TeamMember.fromMap(Map<String, dynamic> m) => TeamMember(
        teamMemberId: m['teamMemberId'] as String? ?? '',
        providerProfileId: m['providerProfileId'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        email: m['email'] as String?,
        role: m['role'] as String?,
      );
}
