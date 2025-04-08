import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jwlife/core/utils/shared_preferences_helper.dart';
import 'package:jwlife/l10n/localization.dart';

class LoginView extends StatefulWidget {
  final Function(VoidCallback fn) update;
  final bool fromSettings;

  const LoginView({super.key, required this.update, required this.fromSettings});

  @override
  State<LoginView> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginView> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth auth = FirebaseAuth.instance;
  bool _isCreatingAccount = false;

  // Controllers for account creation
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  File? profileImage;

  @override
  void initState() {
    super.initState();

    init();
  }

  Future<void> init() async {
    String locale = await getLocale();
    FirebaseAuth.instance.setLanguageCode(locale);
  }

  void login() async {
    try {
      await auth.signInWithEmailAndPassword(
        email: emailController.text.toLowerCase().replaceAll(' ', ''),
        password: passwordController.text.replaceAll(' ', ''),
      );

      if(auth.currentUser!.emailVerified) {
        widget.update(() {});
        if(widget.fromSettings) {
          Navigator.pop(context);
        }
      }
      else {
        _showInfoTextFielDialog(localization(context).login_email_verification, localization(context).login_email_message_verification);
      }
    }
    catch (e) {
      if(emailController.text.isEmpty && passwordController.text.isEmpty) {
        _showErrorDialog(localization(context).login_error_message_email_password_required);
      }
      else if(emailController.text.isEmpty) {
        _showErrorDialog(localization(context).login_error_message_email_required);
      }
      else if (passwordController.text.isEmpty) {
        _showErrorDialog(localization(context).login_error_message_password_required);
      }
      else {
        _showErrorDialog(localization(context).login_error_message);
      }
    }
  }

  void createAccount() async {
    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: emailController.text.toLowerCase().replaceAll(' ', ''),
        password: passwordController.text.replaceAll(' ', ''),
      );

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(nameController.text);
        await userCredential.user!.sendEmailVerification();
        await _showInfoTextFielDialog(localization(context).login_email_verification, localization(context).login_email_message_verification).then((_) => {
          setState(() {
            _isCreatingAccount = false;
          })
        });
      }
    }
    catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _showInfoTextFielDialog(String title, String message) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localization(context).login_error_title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> pickProfileImage() async {
    // Use an image picker package to pick the image
    // Example with image_picker:
    // final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    // if (pickedFile != null) {
    //   setState(() {
    //     profileImage = File(pickedFile.path);
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isCreatingAccount ? _buildAccountCreationForm() : _buildLoginForm(),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            localization(context).login_title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: localization(context).login_email,
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: localization(context).login_password,
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
        ),
        // bouton forget password and create account
        const SizedBox(height: 4),
        TextButton(
          onPressed: () {
            if(emailController.text.isNotEmpty)
            {
              FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text.toLowerCase().replaceAll(' ', ''));
              _showInfoTextFielDialog(localization(context).login_password_reset, localization(context).login_password_message_reset_email);
            }
            else
            {
              _showErrorDialog(localization(context).login_error_message_email_required);
            }
          },
          style: TextButton.styleFrom(
            alignment: Alignment.centerRight,
          ),
          child:Text(localization(context).login_forgot_password),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ButtonStyle(shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))))),
          onPressed: login,
          child: Text(localization(context).login_sign_in),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(localization(context).login_dont_have_account),
            TextButton(
              onPressed: () {
                setState(() {
                  _isCreatingAccount = true;
                });
              },
              child: Text(localization(context).login_create_account),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountCreationForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localization(context).login_create_account_title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: localization(context).login_name,
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: localization(context).login_email,
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: localization(context).login_password,
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
        ),
        /*
        const SizedBox(height: 16),
        TextFormField(
          controller: phoneController,
          decoration: InputDecoration(
            labelText: localization(context).login_phone,
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            return null;
          },
        ),

         */
        const SizedBox(height: 16),
        ElevatedButton(
          style: ButtonStyle(shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))))),
          onPressed: createAccount,
          child: Text(localization(context).login_create_account),
        ),
      ],
    );
  }
}