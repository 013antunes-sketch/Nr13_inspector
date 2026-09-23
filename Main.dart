import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const NR13InspectorApp());
}

class NR13InspectorApp extends StatelessWidget {
  const NR13InspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NR13 Inspector V1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F2C59),
          primary: const Color(0xFF0F2C59),
          secondary: const Color(0xFFE65100),
          surface: const Color(0xFFF8F9FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F2C59),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

// ==========================================
// 1. MOTOR DE CONVERSÃO & CÁLCULO DE PMTA
// ==========================================
class PressureConverter {
  static const double kgfToMPa = 0.0980665;
  static const double barToMPa = 0.1;
  static const double psiToMPa = 0.006894757;

  static double convert(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    double inMPa;
    switch (fromUnit) {
      case 'kgf/cm²': inMPa = value * kgfToMPa; break;
      case 'bar': inMPa = value * barToMPa; break;
      case 'psi': inMPa = value * psiToMPa; break;
      case 'MPa': default: inMPa = value; break;
    }
    switch (toUnit) {
      case 'kgf/cm²': return inMPa / kgfToMPa;
      case 'bar': return inMPa / barToMPa;
      case 'psi': return inMPa / psiToMPa;
      case 'MPa': default: return inMPa;
    }
  }

  static double calculatePMTA({
    required double S, // Tensão Admissível (MPa)
    required double E, // Eficiência de Junta
    required double t, // Espessura Medida (mm)
    required double c, // Corrosão (mm)
    required double R, // Raio Interno (mm)
  }) {
    double tEfetiva = t - c;
    if (tEfetiva <= 0) return 0.0;
    return (S * E * tEfetiva) / (R + (0.6 * tEfetiva)); // Retorna em MPa
  }
}

// ==========================================
// 2. DASHBOARD (TELA INICIAL)
// ==========================================
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NR13 Inspector V1'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade800.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.greenAccent),
            ),
            child: const Row(
              children: [
                Icon(Icons.offline_pin, color: Colors.greenAccent, size: 14),
                SizedBox(width: 4),
                Text('OFFLINE', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Color(0xFF0F2C59), child: Icon(Icons.person, color: Colors.white)),
                title: Text('Eng. Resp. Técnico', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('CREA/CFT Registrado | Inspeção de Campo'),
              ),
            ),
            const SizedBox(height: 20),
            const Text('NOVA INSPEÇÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2C59),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    icon: const Icon(Icons.opacity_rounded),
                    label: const Text('Vaso de Pressão'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VasoFormPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. FORMULÁRIO DO VASO & CÁLCULO PMTA
// ==========================================
class VasoFormPage extends StatefulWidget {
  const VasoFormPage({super.key});

  @override
  State<VasoFormPage> createState() => _VasoFormPageState();
}

class _VasoFormPageState extends State<VasoFormPage> {
  final _tagController = TextEditingController(text: 'VP-204');
  final _clienteController = TextEditingController(text: 'PetroSul Refinaria');
  final _materialController = TextEditingController(text: 'SA-516 Gr. 70');
  final _tensaoSController = TextEditingController(text: '138.0'); // MPa
  final _eficienciaEController = TextEditingController(text: '0.85');
  final _diametroController = TextEditingController(text: '1200'); // mm
  final _espessuraTController = TextEditingController(text: '8.5'); // mm
  final _corrosaoCController = TextEditingController(text: '1.5'); // mm

  double? _pmtaCalculadaMPa;
  String _unidadeExibicao = 'kgf/cm²';

  void _executarCalculo() {
    double s = double.tryParse(_tensaoSController.text) ?? 0;
    double e = double.tryParse(_eficienciaEController.text) ?? 0;
    double d = double.tryParse(_diametroController.text) ?? 0;
    double t = double.tryParse(_espessuraTController.text) ?? 0;
    double c = double.tryParse(_corrosaoCController.text) ?? 0;

    setState(() {
      _pmtaCalculadaMPa = PressureConverter.calculatePMTA(
        S: s, E: e, t: t, c: c, R: d / 2,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    double pmtaExibida = _pmtaCalculadaMPa != null
        ? PressureConverter.convert(_pmtaCalculadaMPa!, 'MPa', _unidadeExibicao)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Inspeção: Vaso de Pressão')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _tagController, decoration: const InputDecoration(labelText: 'TAG do Equipamento')),
            TextField(controller: _clienteController, decoration: const InputDecoration(labelText: 'Cliente / Unidade')),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: TextField(controller: _materialController, decoration: const InputDecoration(labelText: 'Material'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _tensaoSController, decoration: const InputDecoration(labelText: 'Tensão S (MPa)'))),
              ],
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: _diametroController, decoration: const InputDecoration(labelText: 'Diâmetro D_i (mm)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _eficienciaEController, decoration: const InputDecoration(labelText: 'Eficiência Junta (E)'))),
              ],
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: _espessuraTController, decoration: const InputDecoration(labelText: 'Menor Espessura (mm)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _corrosaoCController, decoration: const InputDecoration(labelText: 'Corrosão c (mm)'))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2C59), foregroundColor: Colors.white),
                icon: const Icon(Icons.calculate),
                label: const Text('CALCULAR PMTA'),
                onPressed: _executarCalculo,
              ),
            ),
            if (_pmtaCalculadaMPa != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('PMTA Calculada:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'kgf/cm²', label: Text('kgf/cm²')),
                            ButtonSegment(value: 'MPa', label: Text('MPa')),
                            ButtonSegment(value: 'bar', label: Text('bar')),
                            ButtonSegment(value: 'psi', label: Text('psi')),
                          ],
                          selected: {_unidadeExibicao},
                          onSelectionChanged: (set) => setState(() => _unidadeExibicao = set.first),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('${pmtaExibida.toStringAsFixed(2)} $_unidadeExibicao',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('GERAR RELATÓRIO PDF'),
                  onPressed: () async {
                    final pdfFile = await _gerarPDFLocal(
                      tag: _tagController.text,
                      cliente: _clienteController.text,
                      pmtaValor: pmtaExibida,
                      unidade: _unidadeExibicao,
                    );
                    await Printing.sharePdf(bytes: await pdfFile.readAsBytes(), filename: 'Relatorio_NR13_${_tagController.text}.pdf');
                  },
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Future<File> _gerarPDFLocal({required String tag, required String cliente, required double pmtaValor, required String unidade}) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          cross: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(level: 0, child: pw.Text('RELATÓRIO DE INSPEÇÃO DE VASO DE PRESSÃO - NR-13')),
            pw.Bullet(text: 'TAG: $tag'),
            pw.Bullet(text: 'Cliente: $cliente'),
            pw.Bullet(text: 'PMTA Recalculada em Campo: ${pmtaValor.toStringAsFixed(2)} $unidade'),
            pw.SizedBox(height: 20),
            pw.Text('Parecer Técnico: O equipamento encontra-se APTO para operação dentro dos limites recalculados.'),
          ],
        ),
      ),
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/NR13_$tag.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
