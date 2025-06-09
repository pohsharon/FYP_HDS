import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';


class CreateTreePage extends StatefulWidget {
  const CreateTreePage({super.key});

  @override
  _CreateTreePageState createState() => _CreateTreePageState();
}

class _CreateTreePageState extends State<CreateTreePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController plantingDateController = TextEditingController();

  String selectedSpecies = 'Musang King';
  String selectedStatus = 'Flowering';

  final speciesList = ['Musang King', 'D24', 'Black Thorn'];
  final statusList = ['Flowering', 'Fruiting', 'Dormant'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Tree', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        leading: const BackButton(),
        backgroundColor: AppColors.background
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: selectedSpecies,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Species',
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: speciesList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) => setState(() {
                  selectedSpecies = newValue!;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: plantingDateController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Planting Date',
                  suffixIcon: Icon(Icons.calendar_today),
                  filled: true,
                  fillColor: Colors.white,
                ),
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2020, 4, 30),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    plantingDateController.text =
                        '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Height',
                  hintText: 'eg. 2.5m',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Width',
                  hintText: 'eg. 1.6m',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Flowering Period',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Status',
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: statusList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) => setState(() {
                  selectedStatus = newValue!;
                }),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Handle save logic
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004225), // pakistanGreen
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
