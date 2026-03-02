/// Returns true if [email] is a valid @my.utexas.edu address.
bool isUtEmail(String? email) {
  if (email == null) return false;
  return RegExp(r'^[^\s@]+@my\.utexas\.edu$', caseSensitive: false).hasMatch(email.trim());
}
