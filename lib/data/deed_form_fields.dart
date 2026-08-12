// Trimmed per the simplified Photo-mode submission design: ONLY fields with predefined
// (dropdown/select) options are kept — no free text, no plain numeric entry, no location
// (GPS is captured automatically at submission instead). 26 of 32 deeds end up with zero
// fields at all (photo only); 6 keep exactly one predefined dropdown.

class DeedFormField {
  final String id;
  final String label;
  final String type; // always 'select' now
  final List<String> options;
  const DeedFormField({required this.id, required this.label, required this.type, required this.options});
}

const Map<String, List<DeedFormField>> deedFormFields = {
  'litter': [
    DeedFormField(id: 'weight', type: 'select', label: 'Approximate weight?', options: ['<1kg', '1-5kg', '5-10kg', '10kg+']),
  ],
  'sweep': [],
  'water': [],
  'plantSapling': [],
  'cleanDrain': [],
  'recycle': [
    DeedFormField(id: 'type', type: 'select', label: 'What type of waste?', options: ['Plastic', 'Paper', 'Glass', 'Metal', 'Mixed']),
  ],
  'greenSpace': [],
  'waterCooler': [],
  'stray': [],
  'reportInjuredAnimal': [
    DeedFormField(id: 'type', type: 'select', label: 'What type of animal?', options: ['Dog', 'Cat', 'Bird', 'Cow', 'Other']),
  ],
  'waterAnimals': [],
  'buildShelter': [],
  'feedBirds': [],
  'neuterStray': [
    DeedFormField(id: 'type', type: 'select', label: 'Animal type?', options: ['Cat', 'Dog', 'Other']),
  ],
  'fosterAnimal': [
    DeedFormField(id: 'type', type: 'select', label: 'What type of animal?', options: ['Cat', 'Dog', 'Bird', 'Other']),
  ],
  'reportStreetlight': [],
  'reportPothole': [
    DeedFormField(id: 'size', type: 'select', label: 'Approximate size?', options: ['Small (<30cm)', 'Medium (30-60cm)', 'Large (60cm+)']),
  ],
  'paintBench': [],
  'helpCrossRoad': [],
  'cleanSchool': [],
  'cleanWorship': [],
  'reportHazard': [],
  'donateSupplies': [],
  'shareMeal': [],
  'donateBooks': [],
  'donateBlood': [],
  'visitElderly': [],
  'teachSkill': [],
  'carryBags': [],
  'donateFirstAid': [],
  'donateMedicines': [],
  'cleanClinic': [],
};