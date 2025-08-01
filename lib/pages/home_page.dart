import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:formconnectfirebase/pages/edit_profile_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  Future<List<String>> getFriendIds() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<List<String>> getPendingRequests() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();

    List<String> pending = [];
    for (var doc in snapshot.docs) {
      final req = await FirebaseFirestore.instance
          .collection('users')
          .doc(doc.id)
          .collection('friendRequests')
          .doc(currentUserId)
          .get();
      if (req.exists && req['status'] == 'pending') {
        pending.add(doc.id);
      }
    }
    return pending;
  }

  void removeFriend(String friendId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(friendId)
        .delete();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(friendId)
        .collection('friends')
        .doc(currentUserId)
        .delete();
  }

  void openFriendProfile(BuildContext context, String docId, Map<String, dynamic> userData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(userData['nickname'] ?? 'Profil')),
          body: Column(
            children: [
              if (userData['photoPath'] != null && userData['photoPath'] != '')
                Image.file(File(userData['photoPath']), width: 100, height: 100),
              Text(userData['nickname'] ?? ''),
              ElevatedButton(
                onPressed: () async {
                  removeFriend(docId);
                  Navigator.pop(context); // Retour
                  setState(() {}); // Refresh
                },
                child: Text("Ne plus être ami"),
              )
            ],
          ),
        ),
      ),
    );
  }

  void openOwnProfile(BuildContext context) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    final userData = doc.data() as Map<String, dynamic>;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          user: userData,
          docId: currentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Accueil'),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () => openOwnProfile(context),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: getFriendIds(),
        builder: (context, friendSnapshot) {
          if (!friendSnapshot.hasData) return Center(child: CircularProgressIndicator());
          List<String> friends = friendSnapshot.data!;

          return FutureBuilder<List<String>>(
            future: getPendingRequests(),
            builder: (context, pendingSnapshot) {
              if (!pendingSnapshot.hasData) return Center(child: CircularProgressIndicator());
              List<String> pendingRequests = pendingSnapshot.data!;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                  final users = snapshot.data!.docs;
                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView(
                      children: users.map((doc) {
                        if (doc.id == currentUserId) return SizedBox.shrink();
                        final data = doc.data() as Map<String, dynamic>;
                        final isFriend = friends.contains(doc.id);
                        final isPending = pendingRequests.contains(doc.id);
                        return Card(
                          child: ListTile(
                            leading: data['photoPath'] != null && data['photoPath'] != ''
                                ? Image.file(File(data['photoPath']), width: 50, height: 50)
                                : Icon(Icons.person, size: 50),
                            title: Text(data['nickname'] ?? 'Sans surnom'),
                            subtitle: isFriend
                                ? Text('Ami')
                                : isPending
                                    ? Text('Demande en attente')
                                    : null,
                            trailing: isFriend
                                ? null
                                : isPending
                                    ? Text('En attente')
                                    : ElevatedButton(
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(doc.id)
                                              .collection('friendRequests')
                                              .doc(currentUserId)
                                              .set({'status': 'pending'});
                                          setState(() {});
                                        },
                                        child: Text('Ajouter en ami'),
                                      ),
                            onTap: () async {
                              final userData = doc.data() as Map<String, dynamic>;
                              if (isFriend) {
                                openFriendProfile(context, doc.id, userData);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditProfilePage(
                                      user: userData,
                                      docId: doc.id,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

 