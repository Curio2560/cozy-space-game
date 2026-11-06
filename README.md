# Correio Cósmico (nome provisório)

Cozy delivery game em 3D para Android, em planetas pequenos com gravidade para o centro. Godot 4.7.2, renderer Compatibility, paisagem, cel-shaded.

- Visão e decisões: `docs/design/` (visão, grill e respostas) e o spec na issue #1.
- Fases: milestones F0–F6 no GitHub.

## Testes

```bash
./run_tests.sh          # GUT em headless; falha também com parse errors
```

## APK debug (local)

```bash
./build_apk.sh          # → build/correio-cosmico-debug.apk
```

Precisa dos export templates 4.7.2, do Android SDK e do keystore debug configurados nas editor settings. A versão está em `project.godot` (`application/config/version`) e no `export_presets.cfg` (`version/name`, `version/code`); um teste garante que as duas coincidem.

## Créditos

- Ultimate Platformer Pack, Quaternius (CC0 1.0) — `assets/kit`.
- Ultimate Nature Pack, Quaternius (CC0 1.0) — `assets/nature`.
