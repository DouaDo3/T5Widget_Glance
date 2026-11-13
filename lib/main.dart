import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AppTp5());

const _miel = Color(0xFFE0A100);
const _rougeAlerte = Color(0xFFB3261E);

class AppTp5 extends StatelessWidget {
  const AppTp5({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: _miel, brightness: b),
          cardTheme: const CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          ),
        );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TP 5 – Widget',
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const PageWidget(),
    );
  }
}

/// Tous les appels vers le code Kotlin du widget
class CanalWidget {
  static const _canal = MethodChannel('widget/maj');

  static Future<int> mettreAJour({
    required double valeur, // toujours un double (voir Erreurs fréquentes)
    String? titre,
    String? unite,
    double? seuil,
  }) async {
    final n = await _canal.invokeMethod<int>('mettreAJour', {
      'valeur': valeur,
      'titre': titre,
      'unite': unite,
      'seuil': seuil,
    });
    return n ?? 0;
  }

  static Future<int> nombreWidgets() async =>
      await _canal.invokeMethod<int>('nombreWidgets') ?? 0;

  static Future<bool> epingler() async =>
      await _canal.invokeMethod<bool>('epingler') ?? false;
}

class PageWidget extends StatefulWidget {
  const PageWidget({super.key});

  @override
  State<PageWidget> createState() => _PageWidgetState();
}

class _PageWidgetState extends State<PageWidget> with WidgetsBindingObserver {
  static const _titre = 'Ruche · température';

  double _valeur = 34;
  double _seuil = 38;
  int _nbWidgets = 0;
  bool _envoi = false;
  DateTime? _dernierEnvoi;

  bool get _alerte => _valeur >= _seuil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _compter();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Recompte les widgets quand on revient dans l'app (ex. après en avoir posé un)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _compter();
  }

  Future<void> _compter() async {
    try {
      final n = await CanalWidget.nombreWidgets();
      if (mounted) setState(() => _nbWidgets = n);
    } catch (_) {
      // canal indisponible (ex. tests) : on garde le compteur actuel
    }
  }

  void _message(String texte, {bool erreur = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texte),
        behavior: SnackBarBehavior.floating,
        backgroundColor: erreur ? cs.error : null,
      ));
  }

  Future<void> _envoyer() async {
    setState(() => _envoi = true);
    try {
      final n = await CanalWidget.mettreAJour(
        titre: _titre,
        valeur: _valeur,
        unite: '°C',
        seuil: _seuil,
      );
      if (!mounted) return;
      setState(() {
        _nbWidgets = n;
        if (n > 0) _dernierEnvoi = DateTime.now();
      });
      _message(n == 0 ? "Aucun widget sur l'écran d'accueil" : 'Envoyé à $n widget(s)',
          erreur: n == 0);
    } on PlatformException catch (e) {
      _message('Erreur ${e.code} : ${e.message}', erreur: true);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _epingler() async {
    final ok = await CanalWidget.epingler();
    if (!ok && mounted) {
      _message('Ajout automatique non pris en charge : ajoutez-le à la main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        title: const Row(children: [
          Icon(Icons.hive_rounded, color: _miel),
          SizedBox(width: 10),
          Text('Ruche connectée', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Recompter les widgets',
            onPressed: _compter,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _sectionTitre('Aperçu du widget'),
          _ApercuWidget(
            titre: _titre,
            valeur: _valeur,
            alerte: _alerte,
            heure: _dernierEnvoi,
          ),
          const SizedBox(height: 16),
          _carteWidgets(cs),
          const SizedBox(height: 24),
          _sectionTitre('Simulation du capteur'),
          _carteReglage(
            icone: Icons.thermostat_rounded,
            libelle: 'Mesure simulée',
            valeurTexte: '${_valeur.toStringAsFixed(1)} °C',
            couleur: _alerte ? _rougeAlerte : cs.primary,
            slider: Slider(
              value: _valeur, min: 20, max: 50, divisions: 60,
              activeColor: _alerte ? _rougeAlerte : null,
              label: '${_valeur.toStringAsFixed(1)} °C',
              onChanged: (v) => setState(() => _valeur = v),
            ),
          ),
          const SizedBox(height: 12),
          _carteReglage(
            icone: Icons.warning_amber_rounded,
            libelle: "Seuil d'alerte",
            valeurTexte: '${_seuil.round()} °C',
            couleur: cs.tertiary,
            slider: Slider(
              value: _seuil, min: 20, max: 50, divisions: 30,
              label: '${_seuil.round()} °C',
              onChanged: (v) => setState(() => _seuil = v),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _envoi ? null : _envoyer,
              style: FilledButton.styleFrom(
                backgroundColor: _alerte ? _rougeAlerte : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              icon: _envoi
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: const Text('Envoyer au widget'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitre(String texte) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(texte,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3,
                )),
      );

  Widget _carteWidgets(ColorScheme cs) {
    final aucun = _nbWidgets == 0;
    return Card(
      color: cs.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: aucun ? cs.errorContainer : cs.primaryContainer,
              child: Icon(aucun ? Icons.widgets_outlined : Icons.widgets_rounded,
                  color: aucun ? cs.onErrorContainer : cs.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aucun ? 'Aucun widget posé' : '$_nbWidgets widget(s) posé(s)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  Text("sur l'écran d'accueil",
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _epingler,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteReglage({
    required IconData icone,
    required String libelle,
    required String valeurTexte,
    required Color couleur,
    required Widget slider,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icone, color: couleur),
                const SizedBox(width: 10),
                Expanded(child: Text(libelle, style: const TextStyle(fontSize: 15))),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(valeurTexte,
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: couleur)),
                ),
              ],
            ),
            slider,
          ],
        ),
      ),
    );
  }
}

/// Reproduit en Flutter l'apparence du widget Glance, pour prévisualiser avant l'envoi
class _ApercuWidget extends StatelessWidget {
  const _ApercuWidget({
    required this.titre,
    required this.valeur,
    required this.alerte,
    required this.heure,
  });

  final String titre;
  final double valeur;
  final bool alerte;
  final DateTime? heure;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fond = alerte ? _rougeAlerte : cs.secondaryContainer;
    final texte = alerte ? Colors.white : cs.onSecondaryContainer;
    final h = heure;
    final bas = alerte
        ? 'ALERTE'
        : h == null
            ? 'pas encore envoyé'
            : 'envoyé à ${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (alerte ? _rougeAlerte : Colors.black).withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: TextStyle(color: texte, fontSize: 15)),
          const SizedBox(height: 4),
          Text('${valeur.toStringAsFixed(1)} °C',
              style: TextStyle(
                  color: texte, fontSize: 44, fontWeight: FontWeight.bold, height: 1.1)),
          const Spacer(),
          Row(
            children: [
              if (alerte) ...[
                Icon(Icons.warning_rounded, color: texte, size: 18),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(bas,
                    style: TextStyle(color: texte, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.refresh_rounded, color: texte),
            ],
          ),
        ],
      ),
    );
  }
}
