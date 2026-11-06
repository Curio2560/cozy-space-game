# Correio Cósmico (nome provisório)

Cozy delivery game em 3D para Android: entregas a pé e de rover em pequenos planetas com
gravidade para o centro, gerados aleatoriamente, com biomas, base, quinta, fábrica e defesa
noturna com mechs. Godot 4.7.2 · renderer Compatibility · paisagem · cel-shaded.

- **Visão e decisões:** `docs/design/` (visão, grills e respostas) e o spec na issue #1.
- **Fases:** milestones no GitHub (F0 e F1 concluídas; F2 em curso).
- **APKs de teste:** [Releases](../../releases) (a mais recente no topo).

## Estrutura

| Pasta | O quê |
|---|---|
| `assets/kit/` | Quaternius **Ultimate Platformer Pack** (personagens, mechs, naves, rovers, base, pickups, natureza) |
| `assets/nature/` | Quaternius **Ultimate Nature Pack** (árvores, arbustos, catos) — recoloridos por bioma |
| `assets/mdvl/` | Relva "mdvl" (paleta em textura) — recolorida por bioma |
| `assets/rocks/` | Rochas estilizadas — espalhadas, em pedregulhos e em montes, tingidas por bioma |
| `assets/terrain/` | Terreno modular (penhascos, colinas, montanhas) — relevo carimbado nos planetas |
| `assets/BinbunVFX_Vol2/` | Explosões (Binbun3D, CC0) — explosão do rover |
| `assets/monsters/` | Quaternius **Ultimate Monsters** — criaturas (à espera da textura e da versão glTF com animações) |
| `assets/icon/` | Ícone da app (gerado por `tools/`) |
| `entrada/` | **Onde pôr assets novos** (ver `entrada/LEIA-ME.md`) |
| `src/` | Código: `planet/` (geração), `player/`, `vehicle/`, `camera/`, `delivery/`, `economy/`, `render/` (cel-shading), `input/`, `ui/`, `debug/`, `game/`, `dev/` |
| `scenes/` | `game/` (jogo), `ui/` (arranque), `dev/` (vitrine, testes de controlos, planetas, paletas) |
| `shaders/` | Cel-shading e contorno |
| `i18n/` | Textos PT/EN |
| `tests/unit/` | Testes GUT |
| `tools/` | Ícone e utilitários |
| `docs/` | `design/` (visão, grill), `art/` (capturas), `perf.md` |

## Testes e APK

```bash
./run_tests.sh          # GUT em headless; falha também com parse errors
./build_apk.sh          # → build/correio-cosmico-debug.apk
```

O APK é gerado localmente (sem CI) e publicado nas Releases. A versão está em `project.godot`
e em `export_presets.cfg`; um teste garante que coincidem.

## Créditos

- Ultimate Platformer Pack e Ultimate Nature Pack — Quaternius (CC0 1.0).
- Stylized Explosion FX — Binbun3D (CC0), bun3d.com.
- Relva `mdvl_nature_grass_01` — enviada pelo autor do projeto (origem/licença a confirmar).
