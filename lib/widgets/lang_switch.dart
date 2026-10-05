import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// 🇩🇪 / 🇬🇧 language switch.
class LangSwitch extends StatelessWidget {
  const LangSwitch({super.key});

  static const langs = {'de': '🇩🇪', 'en': '🇬🇧'};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in langs.entries)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ChoiceChip(
              label: Text('${e.value} ${e.key.toUpperCase()}'),
              selected: app.lang == e.key,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => app.setLang(e.key),
            ),
          ),
      ],
    );
  }
}
