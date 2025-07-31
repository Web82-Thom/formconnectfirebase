import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:formconnectfirebase/pages/edit_profile_page.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _refresh() async {
    setState(() {});
  }

  void _openEditProfile(Map<String, dynamic> user, String docId) {
    if (docId == currentUserId){Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(user: user, docId: docId),
      ),
    );}
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Accueil'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body:RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!.docs;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final userDoc = users[index];
                final user = userDoc.data() as Map<String, dynamic>;
                final docId = users[index].id;
                return SingleChildScrollView(
                  child: Card(
                    margin: EdgeInsets.all(10),
                    child: ListTile(
                      onTap: () => _openEditProfile(user, docId),
                      leading: user['photoPath'] != ''
                          ? Image.file(File(user['photoPath']), width: 50, height: 50, fit: BoxFit.fitWidth)
                          : Icon(Icons.person, size: 50),
                      title: Text(user['nickname'] ?? 'Sans nom'),
                      subtitle: Text(user['email'] ?? ''),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}


