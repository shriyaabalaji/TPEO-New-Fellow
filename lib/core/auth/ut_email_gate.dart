bool isUtEmail(String? email) {
  if (email == null) return false;
  return RegExp(r'^[^@\s]+@utexas\.edu\$?', caseSensitive: false).hasMatch(email) || RegExp(r'^[^@\s]+@utexas\.edu$', caseSensitive: false).hasMatch(email);
}

