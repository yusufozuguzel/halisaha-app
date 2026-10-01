import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'support_contact.dart';

class AccountRestrictionBanner extends StatelessWidget {
  const AccountRestrictionBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .doc('_moderationAccounts/$uid')
          .snapshots(),
      builder: (context, snapshot) => snapshot.data?.exists == true
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Hesabınız moderasyon nedeniyle kısıtlandı. Profil, fotoğraf, maç ve arkadaşlık değişiklikleri kapalı. İtiraz ve destek için ${SupportContact.email} adresine yazabilirsiniz.',
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
