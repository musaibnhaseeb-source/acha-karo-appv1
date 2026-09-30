import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_metadata.dart';

// DEV-ONLY probe for the v1.3.2 duplicate-photo check: is image_picker's resize/re-encode
// deterministic? Pick the same gallery photo more than once and compare the hashes. Uses the
// exact picker settings of SubmitDeedModal, then the same stripImageMetadata + SHA-256 as the
// upload. Own entry point, never imported by the app; no Supabase, nothing leaves the device.
//   flutter run -t lib/dev_prototypes/dup_hash_probe.dart
void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: _Probe()));

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final _lines = <String>[];

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 70);
    if (picked == null) return;
    final raw = await picked.readAsBytes();
    final clean = await stripImageMetadata(raw);
    final line = '#${_lines.length + 1} ${picked.name} raw=${raw.length}B '
        'rawsha=${sha256.convert(raw).toString().substring(0, 16)} '
        'clean=${clean == null ? 'null' : '${clean.extension} ${sha256.convert(clean.bytes).toString().substring(0, 16)}'}';
    debugPrint('PROBE $line'); // read by the headless/adb test harness
    setState(() => _lines.add(line));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ElevatedButton(key: const ValueKey('pick'), onPressed: _pick, child: const Text('PICK')),
            for (final l in _lines) SelectableText(l, key: ValueKey(l), style: const TextStyle(fontSize: 11)),
          ]),
        ),
      );
}
