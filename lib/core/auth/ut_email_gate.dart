/// Returns true if [email] is a valid utexas.edu address, including
/// subdomains like my.utexas.edu or eid.utexas.edu.
bool isUtEmail(String? email) {
  if (email == null) return false;
  return RegExp(
    r'^[^\s@]+@([a-z0-9-]+\.)*utexas\.edu$',
    caseSensitive: false,
  ).hasMatch(email.trim());
}
