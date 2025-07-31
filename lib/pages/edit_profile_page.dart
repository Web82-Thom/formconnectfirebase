import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final String docId;

  EditProfilePage({required this.user, required this.docId});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  File? _image;

  @override
  void initState() {
    super.initState();
    _nicknameController.text = widget.user['nickname'] ?? '';
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('users').doc(widget.docId).update({
        'nickname': _nicknameController.text.trim(),
        'photoPath': _image?.path ?? widget.user['photoPath'],
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Modifier le profil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nicknameController,
                decoration: InputDecoration(labelText: 'Surnom'),
                validator: (value) => value!.isEmpty ? 'Champ requis' : null,
              ),
              SizedBox(height: 10),
              _image != null
                  ? Image.file(_image!, height: 100)
                  : widget.user['photoPath'] != ''
                      ? Image.file(File(widget.user['photoPath']), height: 100)
                      : Icon(Icons.person, size: 100),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Changer la photo'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                child: Text('Enregistrer'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
