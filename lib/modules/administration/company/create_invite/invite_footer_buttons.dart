part of '../screen_create_invite.dart';

extension _CreateInviteFooterButtons on _ScreenCreateInviteState {
  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: isLoading ? null : () => Navigator.pop(context),
      style: _outlinedButtonStyle(
        const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      ),
      child: const Text('Cancel'),
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : _createInvite,
      style: ElevatedButton.styleFrom(
        backgroundColor: invitePrimaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.4,
              ),
            )
          : const Text(
              'Create Invite',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
    );
  }

  ButtonStyle _outlinedButtonStyle(EdgeInsetsGeometry padding) {
    return OutlinedButton.styleFrom(
      foregroundColor: inviteHeadingTextColor,
      side: const BorderSide(color: inviteCardBorderColor),
      padding: padding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
