import 'package:flutter/material.dart';

import 'consent_storage.dart';

const _consentText = '''
HabitQ es un asistente conversacional que ofrece orientación general sobre hábitos saludables (sueño, alimentación, actividad física, hidratación, uso de pantallas y manejo del estrés), basada en evidencia científica.

Antes de continuar, es importante que sepas:

• HabitQ no diagnostica enfermedades ni reemplaza la consulta con un profesional de la salud.
• HabitQ no prescribe medicamentos ni tratamientos.
• Las respuestas se basan en evidencia científica disponible y pueden no aplicar a tu situación particular.
• Si tienes una condición de salud, síntomas que te preocupan o dudas médicas específicas, consulta a un profesional.
• Guardamos tu perfil básico y los hábitos que registres únicamente para personalizar las recomendaciones. No compartimos esta información con terceros.
• Puedes cerrar sesión en cualquier momento desde la pantalla de Inicio.

Al continuar, confirmas que entendiste lo anterior y aceptas usar HabitQ como una herramienta de orientación, no como un servicio médico.''';

/// Shown once per device (plan section 2, "Consentimiento inicial"),
/// between Login and Onboarding/Home. [nextRoute] is read from the
/// pushReplacementNamed arguments unless overridden for tests.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, this.nextRoute, this.consentStorage});

  final String? nextRoute;
  final ConsentStorage? consentStorage;

  Future<void> _handleAccept(BuildContext context) async {
    final resolvedNextRoute =
        nextRoute ?? ModalRoute.of(context)!.settings.arguments as String;
    final storage = consentStorage ?? const ConsentStorage();
    await storage.accept();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(resolvedNextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antes de empezar')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_consentText, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _handleAccept(context),
                child: const Text('Acepto y continúo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
