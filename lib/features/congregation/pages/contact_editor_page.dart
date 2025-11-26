import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:jwlife/core/utils/common_ui.dart';

import '../../../app/app_page.dart';

class ContactEditorPage extends StatefulWidget {
  final String congregationId;
  final String id;
  const ContactEditorPage({super.key, required this.congregationId, required this.id});

  @override
  _ContactEditorPageState createState() => _ContactEditorPageState();
}

class _ContactEditorPageState extends State<ContactEditorPage> {
  final _formKey = GlobalKey<FormState>();

  // Champs de formulaire
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    /*
    try {
      // Récupérer la référence de la collection
      CollectionReference congregationRef = await getCongregationCollection();
      DocumentReference congregationDoc = congregationRef.doc(widget.congregationId);
      CollectionReference brothersAndSisters = congregationDoc.collection('brothers_and_sisters');
      DocumentReference contactDoc = brothersAndSisters.doc(widget.id);

      // Récupérer les données du webview
      DocumentSnapshot contactSnapshot = await contactDoc.get();
      if (contactSnapshot.exists) {
        // Extraire les données
        final data = contactSnapshot.data() as Map<String, dynamic>;

        setState(() {
          _firstNameController.text = data['first_name'] ?? '';
          _lastNameController.text = data['last_name'] ?? '';
          _phoneController.text = (data['phones'] != null && data['phones'].isNotEmpty)
              ? data['phones'].first
              : '';
          _emailController.text = (data['emails'] != null && data['emails'].isNotEmpty)
              ? data['emails'].first
              : '';
          _addressController.text = (data['address'] != null && data['address'].isNotEmpty)
              ? data['address'].first
              : '';
        });
      } else {
        debugPrint('Aucun contact trouvé avec l\'ID fourni.');
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des données Firebase : $e');
    }
    finally {
      setState(() {
        _isLoading = false;
      });
    }

     */
  }

  Future<void> _updateContact() async {
    if (!_formKey.currentState!.validate()) return;

    Contact? contact = await FlutterContacts.getContact(widget.id, withAccounts: true);

    try {
      final updatedContact = Contact(
        id: contact!.id,
        name: Name(
          first: _firstNameController.text,
          last: _lastNameController.text,
        ),
        phones: [
          if (_phoneController.text.isNotEmpty)
            Phone(_phoneController.text),
        ],
        emails: [
          if (_emailController.text.isNotEmpty)
            Email(_emailController.text),
        ],
        addresses: [
          if (_addressController.text.isNotEmpty)
            Address(_addressController.text),
        ],
        accounts: contact.accounts,
      );

      // Mettre à jour le contact dans le téléphone
      await updatedContact.update();

      /*
      // Mettre à jour le contact dans Firebase
      final firebaseData = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'phones': [_phoneController.text],
        'emails': [_emailController.text],
        'address': [_addressController.text],
      };

      // Récupérer la collection des frères et sœurs dans la congrégation sélectionnée
      CollectionReference congregationRef = await getCongregationCollection();
      DocumentReference congregationDoc = congregationRef.doc(widget.congregationId);
      CollectionReference brothersAndSisters = congregationDoc.collection('brothers_and_sisters');

      // Ajouter le contact dans la base de données
      await brothersAndSisters.doc(widget.id).set(firebaseData);

       */

      showBottomMessage('Contact mis à jour avec succès !');

      Navigator.pop(context);
    }
    catch (e) {
      debugPrint('Erreur lors de la mise à jour du contact : $e');
      showBottomMessage('Erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: AppBar(
        title: const Text('Modifier le contact'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Veuillez entrer un prénom' : null,
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Veuillez entrer un nom' : null,
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Adresse'),
                ),
                const SizedBox(height: 32.0),
                ElevatedButton(
                  onPressed: _updateContact,
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
