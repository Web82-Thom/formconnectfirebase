import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:formconnectfirebase/pages/auth_page.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final String docId;

  EditProfilePage({required this.user, required this.docId});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  List<DocumentSnapshot> requests = [];
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  late TextEditingController _nicknameController;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.user['nickname'] ?? '',
    );
    if (widget.docId == currentUserId) fetchRequests();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    final updateData = {'nickname': _nicknameController.text};
    if (_selectedImage != null) {
      updateData['photoPath'] = _selectedImage!.path;
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docId)
        .update(updateData);
    Navigator.pop(context);
  }

  void fetchRequests() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .get();

    setState(() {
      requests = snapshot.docs;
    });
  }

  Future<List<Map<String, dynamic>>> _loadFriends() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docId)
        .collection('friends')
        .get();
    List<Map<String, dynamic>> friends = [];
    for (var doc in snapshot.docs) {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(doc.id)
          .get();
      if (userData.exists) {
        final data = userData.data()!..['id'] = doc.id;
        friends.add(data);
      }
    }
    return friends;
  }

  Future<List<Map<String, dynamic>>> _loadFriendRequests() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docId)
        .collection('friendRequests')
        .get();
    List<Map<String, dynamic>> requests = [];
    for (var doc in snapshot.docs) {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(doc.id)
          .get();
      if (userData.exists) {
        final data = userData.data()!
          ..['status'] = doc['status']
          ..['id'] = doc.id;
        requests.add(data);
      }
    }
    return requests;
  }

  Future<List<Map<String, dynamic>>> _loadSentRequests() async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();
    List<Map<String, dynamic>> sent = [];
    for (var userDoc in usersSnapshot.docs) {
      final requests = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .collection('friendRequests')
          .doc(widget.docId)
          .get();
      if (requests.exists && requests['status'] == 'pending') {
        final userData = userDoc.data();
        userData['id'] = userDoc.id;
        sent.add(userData);
      }
    }
    return sent;
  }

  Future<void> _acceptRequest(String requesterId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docId)
        .collection('friends')
        .doc(requesterId)
        .set({});
    await FirebaseFirestore.instance
        .collection('users')
        .doc(requesterId)
        .collection('friends')
        .doc(widget.docId)
        .set({});
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docId)
        .collection('friendRequests')
        .doc(requesterId)
        .delete();
    setState(() {});
  }

  void rejectRequest(String requesterId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docId)
        .collection('friendRequests')
        .doc(requesterId)
        .delete();

    fetchRequests();
  }

  void cancelSentRequest(String recipientId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(recipientId)
        .collection('friendRequests')
        .doc(currentUserId)
        .delete();
    setState(() {});

    fetchRequests();
  }

  Future<void> _removeFriend(String friendId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docId)
        .collection('friends')
        .doc(friendId)
        .delete();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(friendId)
        .collection('friends')
        .doc(widget.docId)
        .delete();
  }

  Future<void> deleteFirebaseUser() async {
    try {
      await FirebaseAuth.instance.currentUser!.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Ici tu peux gérer la ré-authentification (exemple avec email/password)
        throw Exception(
          'Ré-authentification requise pour supprimer le compte.',
        );
      } else {
        throw Exception(
          'Erreur lors de la suppression du compte : ${e.message}',
        );
      }
    }
  }

  Future<void> _deleteProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer votre profil ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            child: Text('Annuler'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Supprime le document Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .delete();

        // Supprime le compte Firebase Auth
        await FirebaseAuth.instance.currentUser!.delete();

        // Navigue vers la page Auth (connexion)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AuthPage()),
          (route) => false,
        );
      } catch (e) {
        // Gérer l'erreur (ex: re-authentification requise)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression : $e')),
        );
      }
    }
  }

  bool _isOwnProfile() =>
      FirebaseAuth.instance.currentUser!.uid == widget.docId;

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = widget.docId == currentUserId;
    return Scaffold(
      appBar: AppBar(
        title: Text('Profil de ${widget.user['nickname']}'),
        actions: [
          if (isCurrentUser)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteProfile,
              tooltip: 'Supprimer mon profil',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.user['photoPath'] != null &&
                widget.user['photoPath'] != '')
              Image.file(
                File(widget.user['photoPath']),
                width: 100,
                height: 100,
              ),
            if (_selectedImage != null)
              Image.file(_selectedImage!, width: 100, height: 100),
            if (isCurrentUser)
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Changer la photo'),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _nicknameController,
                readOnly: !isCurrentUser,
                decoration: InputDecoration(labelText: 'Surnom'),
              ),
            ),
            if (isCurrentUser)
              ElevatedButton(
                onPressed: _saveProfile,
                child: Text('Enregistrer les modifications'),
              ),
            SizedBox(height: 20),
            if (!isCurrentUser) Icon(Icons.person, size: 100),
            SizedBox(height: 10),
            Text('Surnom : ${widget.user['nickname']}'),
            Text('Email : ${widget.user['email']}'),
            if (!_isOwnProfile())
              FutureBuilder(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('friends')
                    .doc(widget.docId)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return SizedBox.shrink();
                  if ((snapshot.data as DocumentSnapshot).exists)
                    return ElevatedButton(
                      onPressed: () async {
                        await _removeFriend(widget.docId);
                        Navigator.pop(context);
                      },
                      child: Text('Ne plus être ami'),
                    );
                  return SizedBox.shrink();
                },
              ),
            if (_isOwnProfile()) ...[
              Divider(),
              Text('Amis', style: TextStyle(fontWeight: FontWeight.bold)),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadFriends(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  if (snapshot.data!.isEmpty) return Text('Aucun ami.');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: snapshot.data!.map(
                      (friend) =>
                          Text('- ${friend['nickname'] ?? friend['id']}'),
                    )
                    .toList(),
                  );
                },
              ),
              Divider(),
              Text(
                'Demandes en attente (à accepter)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadFriendRequests(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  if (snapshot.data!.isEmpty) return Text('Aucune demande.');
                  return Column(
                    children: snapshot.data!.map((request) {
                      return ListTile(
                        title: Text(request['nickname'] ?? request['id']),
                        subtitle: Text('Statut: ${request['status']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green),
                              onPressed: () => _acceptRequest(request['id']),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () => rejectRequest(request['id']),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              Divider(),
              Text(
                "Demandes envoyées (en attente d'accord)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadSentRequests(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  if (snapshot.data!.isEmpty)
                    return Text('Aucune demande envoyée.');
                  return Column(
                    children: snapshot.data!
                        .map(
                          (user) => ListTile(
                            title: Text(user['nickname'] ?? user['id']),
                            subtitle: Text("En attente d'accord"),
                            trailing: IconButton(
                              icon: Icon(Icons.cancel, color: Colors.orange),
                              onPressed: () => cancelSentRequest(user['id']),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
