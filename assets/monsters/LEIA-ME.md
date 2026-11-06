# Monstros (Quaternius Ultimate Monsters [Atlas], CC0)

Descarregados das pastas glTF do Google Drive indicadas pelo utilizador (06 nov 2026). Cada .gltf
tem tudo embutido (malha, esqueleto, textura `Atlas_Monsters`, animações).

| Pasta | Espécies | Animações |
|---|---|---|
| `gltf/big/` | 16 (Alien, Birb, BlueDemon, Bunny, Cactoro, Demon, Dino, Fish, Frog, Monkroose, MushroomKing, Ninja, Orc, Orc_Skull, Tribal, Yeti) | 14: Idle, Walk, Run, Jump, Punch, HitReact, Death, Wave… |
| `gltf/blob/` | 17 versões "bolinha" (inclui Cat, Chicken, Dog, GreenBlob, GreenSpikyBlob, Mushnub, Mushnub_Evolved, Pigeon, PinkBlob, Wizard) | 9: Idle, Walk, Jump, Bite_Front, HitRecieve, Death… |
| `gltf/flying/` | 17 voadores (Alpaking, Armabee, Dragon, Ghost, Glub, Goleling, Hywirl, Squidle — vários com versão Evolved — e Demon, Pigeon, Tribal voadores) | 8: Flying_Idle, Fast_Flying, Headbutt, Punch, HitReact, Death… (o Demon voador só traz Flying_Idle) |

O catálogo (`src/creatures/creature_catalog.gd`) liga cada família aos papéis do jogo (idle, move,
run, attack, hit, death). Vitrine: `scenes/dev/creature_sheet.tscn`.
