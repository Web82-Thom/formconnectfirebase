import 'package:flutter/material.dart';
import 'package:formconnectfirebase/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _isLogin = true;
  bool _obscureText = true;
  File? _image;
  final AuthService _authService = AuthService();

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      if (_isLogin) {
        await _authService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          nickname: _nicknameController.text.trim(),
          imagePath: _image?.path ?? '',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Connexion' : 'Inscription')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) => value!.contains('@') ? null : 'Email invalide',
              ),
              if (!_isLogin)
                TextFormField(
                  controller: _nicknameController,
                  decoration: InputDecoration(labelText: 'Surnom'),
                  validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                ),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
                validator: (value) => value!.length >= 6 ? null : 'Minimum 6 caractères',
              ),
              if (!_isLogin)
                Column(
                  children: [
                    SizedBox(height: 10),
                    _image == null
                        ? Text('Aucune image sélectionnée')
                        : Image.file(_image!, height: 100),
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: Text('Sélectionner une photo'),
                    ),
                  ],
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: Text(_isLogin ? 'Connexion' : 'Inscription'),
              ),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? 'Créer un compte' : 'Se connecter'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
