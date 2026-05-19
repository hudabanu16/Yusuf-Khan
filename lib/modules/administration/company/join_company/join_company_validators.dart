String? validateJoinFullName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Full name is required';
  }
  return null;
}

String? validateJoinEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) {
    return 'Email is required';
  }
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(email)) {
    return 'Enter a valid email';
  }
  return null;
}

String? validateJoinPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 6) {
    return 'Minimum 6 characters required';
  }
  return null;
}

String? validateJoinConfirmPassword(String? value, String password) {
  final confirmValue = value ?? '';
  if (confirmValue.isEmpty) {
    return 'Please confirm password';
  }
  if (confirmValue != password) {
    return 'Passwords do not match';
  }
  return null;
}

String? validateJoinInviteCode(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Invite code is required';
  }
  return null;
}
