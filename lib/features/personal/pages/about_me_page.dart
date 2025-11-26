import 'package:flutter/material.dart';
import 'package:jwlife/core/icons.dart';

import '../../../app/app_page.dart';

class AboutMePage extends StatefulWidget {
  const AboutMePage({super.key});

  @override
  _AboutMePageState createState() => _AboutMePageState();
}

class _AboutMePageState extends State<AboutMePage> {
  Map<String, dynamic> _me = {};

  // Contrôleurs pour les informations de l'utilisateur
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _jobController = TextEditingController();
  int _genderId = 1;

  // Contrôleurs pour la spiritualité
  final TextEditingController _baptismDateController = TextEditingController();
  final TextEditingController _lastVisitDateController = TextEditingController();

  // Variables pour les IDs
  int _roleId = 3;
  int _pioneerId = 0;
  bool _isAnointed = false;

  // Listes pour les options avec IDs
  final List<Map<String, dynamic>> _genderOptions = [
    {'id': 1, 'value': 'Homme'},
    {'id': 2, 'value': 'Femme'}
  ];
  List<Map<String, dynamic>> _assemblyOptions = []; // Remplissez cette liste avec vos données
  final List<Map<String, dynamic>> _groupOptions = []; // Remplissez cette liste avec vos données
  final List<Map<String, dynamic>> _roleOptions = [
    {'id': 1, 'value': 'Ancien'},
    {'id': 2, 'value': 'Assistant'},
    {'id': 3, 'value': 'Proclamateur'},
    {'id': 4, 'value': 'Proclamateur non baptisé'},
    {'id': 5, 'value': 'Étudiant de la Bible'}
  ];
  final List<Map<String, dynamic>> _pioneerOptions = [
    {'id': 0, 'value': 'Non'},
    {'id': 1, 'value': 'Pionnier Auxiliaire Permanent'},
    {'id': 2, 'value': 'Pionnier permanent'},
    {'id': 3, 'value': 'Pionnier Spécial'},
    {'id': 4, 'value': 'Missionaire'}
  ];

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        controller.text = "${pickedDate.toLocal()}".split(' ')[0];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMeData();
  }

  Future<void> _loadMeData() async {
    /*
    // Récupérer les données de l'utilisateur depuis Firebase Firestore
    final docRef = await getUserCollection();
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      _me = snapshot.data()!;
      setState(() {
        _nameController.text = _me['Name'] ?? '';
        _firstNameController.text = _me['FirstName'] ?? '';
        _birthDateController.text = _me['Birthday'] ?? '';
        _addressController.text = _me['Adress'] ?? '';
        _jobController.text = _me['Job'] ?? '';
        _genderId = _me['GenderId'] ?? 1;
        _roleId = _me['RoleId'] ?? 3;
        _baptismDateController.text = _me['BaptemDate'] ?? '';
        _lastVisitDateController.text = _me['LastVisitDate'] ?? '';
        _pioneerId = _me['PioneerId'] ?? 0;
        _isAnointed = _me['Anointed'] == 1;
      });
    }

     */
  }

  Future<void> _saveUserData() async {
    /*
    final docRef = await getUserCollection();
    await docRef.set({
      'Name': _nameController.text,
      'FirstName': _firstNameController.text,
      'Birthday': _birthDateController.text,
      'Adress': _addressController.text,
      'Job': _jobController.text,
      'GenderId': _genderId,
      'RoleId': _roleId,
      'BaptemDate': _baptismDateController.text,
      'LastVisitDate': _lastVisitDateController.text,
      'PioneerId': _pioneerId,
      'Anointed': _isAnointed ? 1 : 0,
    });

     */
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Informations avec fond coloré
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Informations',
                    style: Theme.of(context).textTheme.headlineMedium
                  ),
                  SizedBox(height: 10),
                  _buildTextField('Nom', _nameController),
                  _buildTextField('Prénom', _firstNameController),
                  _buildDatePickerField('Date de naissance', _birthDateController),
                  _buildAddressField('Adresse', _addressController),
                  _buildDropdown('Genre', _genderOptions, _genderId, (value) {
                    setState(() {
                      _genderId = value['id'];
                    });
                  }),
                  _buildTextField('Travail', _jobController),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Section Spiritualité avec un autre fond coloré
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1f1f1f) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Spiritualité',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  SizedBox(height: 10),
                  _buildDropdown('Rôle', _roleOptions, _roleId, (value) {
                    setState(() {
                      _roleId = value['id'];
                    });
                  }),
                  _buildDatePickerField('Date de baptême', _baptismDateController),
                  _buildDatePickerField('Date de la dernière visite', _lastVisitDateController),
                  _buildDropdown('Pionnier', _pioneerOptions, _pioneerId, (value) {
                    setState(() {
                      _pioneerId = value['id'];
                    });
                  }),
                  Row(
                    children: [
                      Checkbox(
                        value: _isAnointed,
                        onChanged: (value) {
                          setState(() {
                            _isAnointed = value!;
                          });
                        },
                      ),
                      Text('Oint'),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Bouton de sauvegarde
            ElevatedButton(
              style: ButtonStyle(
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
              ),
              onPressed: _saveUserData,
              child: Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // Méthode pour construire un champ texte avec un label
  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).primaryColor.withOpacity(0.1),
        ),
      ),
    );
  }

  // Méthode pour construire un champ avec un sélecteur de date
  Widget _buildDatePickerField(String label, TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTap: () => _selectDate(context, controller),
        child: AbsorbPointer(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              suffixIcon: Icon(JwIcons.calendar),
            ),
          ),
        ),
      ),
    );
  }

  // Méthode pour construire un champ pour l'adresse (recherche simulée)
  Widget _buildAddressField(String label, TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          suffixIcon: Icon(JwIcons.home),
        ),
        onChanged: (value) {
          // Simuler la recherche d'adresse
        },
      ),
    );
  }

  // Méthode pour construire un menu déroulant
  Widget _buildDropdown(String label, List<Map<String, dynamic>> options, int selectedId, Function(Map<String, dynamic>) onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: DropdownButtonFormField<Map<String, dynamic>>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).primaryColor.withOpacity(0.1),
        ),
        value: options.firstWhere((option) => option['id'] == selectedId, orElse: () => options.first),
        items: options.map((option) {
          return DropdownMenuItem<Map<String, dynamic>>(
            value: option,
            child: Text(option['value']),
          );
        }).toList(),
        onChanged: (value) => onChanged(value!),
      ),
    );
  }

  // Méthode pour construire un menu déroulant avec recherche
  Widget _buildDropdownWithSearch(
      String label,
      List<Map<String, dynamic>> options,
      int selectedId,
      Function(Map<String, dynamic>) onChanged,
      TextEditingController controller,
      ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        onChanged: (text) {
          // Filtrer les options selon le texte saisi
        },
      ),
    );
  }
}
