/// Returns true if [email] is a valid @utexas.edu address.
bool isUtEmail(String? email) {
  if (email == null) return false;
  return RegExp(r'^[^\s@]+@\.utexas\.edu$', caseSensitive: false).hasMatch(email.trim());
}
