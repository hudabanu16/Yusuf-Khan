part of '../screen_join_company.dart';

extension _JoinCompanySections on _ScreenJoinCompanyState {
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        onPressed: isLoading ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: primaryColor),
      ),
      title: const Text(
        'Join Existing Company',
        style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: borderColor),
      ),
    );
  }

  Widget _buildJoinCompanyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderText(),
        const SizedBox(height: 24),
        const JoinCompanyOnboardingCard(),
        const SizedBox(height: 28),
        _buildEmployeeDetailsSection(),
        const SizedBox(height: 28),
        _buildInviteCodeSection(),
        const SizedBox(height: 18),
        const JoinCompanyOtpNote(),
        const SizedBox(height: 24),
        JoinCompanySubmitButton(isLoading: isLoading, onPressed: _joinCompany),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Need a new company workspace instead? Go back and choose Create New Workspace.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Join Your Company Workspace',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: primaryColor,
            height: 1.15,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'This is a one-time company joining process. Verify your employee email by OTP, create your login, and then use only email and password for future sign-ins.',
          style: TextStyle(
            fontSize: 14.5,
            color: mutedTextColor,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Employee Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'These credentials will become your permanent login after successful OTP verification.',
          style: TextStyle(color: mutedTextColor, fontSize: 13),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: nameController,
          decoration: joinCompanyInputDecoration(
            label: 'Full Name',
            hint: 'e.g. Bilal Khan',
            icon: Icons.badge_outlined,
          ),
          validator: validateJoinFullName,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: joinCompanyInputDecoration(
            label: 'Employee Email',
            hint: 'e.g. bilal@company.com',
            icon: Icons.email_outlined,
          ),
          validator: validateJoinEmail,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: joinCompanyInputDecoration(
            label: 'Password',
            hint: 'Minimum 6 characters',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              onPressed: _togglePasswordVisibility,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          validator: validateJoinPassword,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: confirmPasswordController,
          obscureText: obscureConfirmPassword,
          decoration: joinCompanyInputDecoration(
            label: 'Confirm Password',
            hint: 'Re-enter password',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              onPressed: _toggleConfirmPasswordVisibility,
              icon: Icon(
                obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          validator: (value) {
            return validateJoinConfirmPassword(value, passwordController.text);
          },
        ),
      ],
    );
  }

  Widget _buildInviteCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invite Code',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the code exactly as shared by your company admin.',
          style: TextStyle(color: mutedTextColor, fontSize: 13),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: inviteCodeController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: primaryColor,
          ),
          decoration: joinCompanyInputDecoration(
            label: 'Invite Code',
            hint: 'e.g. ABCD1234',
            icon: Icons.key_outlined,
          ),
          validator: validateJoinInviteCode,
          onFieldSubmitted: (_) {
            if (!isLoading) {
              _joinCompany();
            }
          },
        ),
      ],
    );
  }
}
