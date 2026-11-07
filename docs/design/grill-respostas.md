# Grill — respostas

## Ronda 1 (05 nov 2026)
1. F1 = planeta + rover + entregas contra o relógio.
2. A pé e de rover: sai do rover para entregar à porta e ir a zonas onde o rover não chega.
3. Joystick à esquerda; botões à direita (saltar/ação/sair do rover); arrastar o lado direito roda a câmara, que volta sozinha para trás.
4. Câmara em terceira pessoa atrás do jogador/rover, "cima" = normal do planeta.
5. Cada planeta é um nível (vários dias, boss no fim); o mapa da galáxia abre o seguinte.
6. Nave-mãe persistente (tecnologia, upgrades) + posto avançado novo em cada planeta (quinta, fábrica, defesa).
7. Dia de ~10 min (7 dia + 3 noite).
8. À noite pilotas um mech e as torres automáticas ajudam. **Nota:** os mechs que o utilizador vai pôr no repo são ajudantes da quinta e do tower defense, desbloqueados com o tempo (item avançado).
9. Sem game over: entrega falhada = sem pagamento; noite perdida = edifícios danificados, reparáveis com recursos.
10. Créditos + 4 recursos: minério, cristal, colheitas, dados de pesquisa.
11. Fábrica: edifícios produzem por tempo e enchem um armazém; ligações simples, sem tapetes.
12. Quinta leve: plantar de manhã, colher ao fim do dia; colheitas = entregas valiosas ou ingredientes do lab.
13. Biomas: sem resposta (bug no HTML, as caixas não se podiam marcar); repetida na ronda 2.
14. Planetas pequenos: ~30 s de rover, ~1,5 min a pé.
15. Relógio suave: a tempo dá bónus; fora de tempo paga menos, mas paga.
16. Tripulação: os 4 astronautas trocam-se durante o jogo; cada um tem a sua vantagem e a sua evolução por níveis, separada dos upgrades permanentes do jogador.
17. Cel-shading: 3 tons + contorno fino escuro da cor do objeto + rim light suave.
18. Renderer Compatibility (GLES3), 60 fps num Android médio.
19. Paisagem.
20. Usar os 4 inimigos do kit como provisórios até chegarem os packs de criaturas e bosses.
21. Nome provisório: "Correio Cósmico".
22. Sem monetização por agora.
23. Fluxo igual ao Deriva Estelar: issues + milestones por fase, ramo + PR por fase com merge sem esperar, APK local, release debug por fase e quando há correções.
24. Sem multijogador.

## Ronda 2 (06 nov 2026) — todas as recomendadas
1. Biomas iniciais: Prado (tutorial), Ácido (rios tóxicos, bolhas de O₂), Lava (calor abranda o rover).
2. Covil do boss: abre com KeyCards ganhos em X entregas importantes; sem limite de dias.
3. Luta com o boss no mech, numa arena perto do covil (mesmo combate da noite).
4. Encomendas: normal, urgente, frágil, perecível (colheitas da quinta).
5. Clientes: colonos com nome e casinha, com reputação (contentes → pedem mais, pagam melhor).
6. Tripulação: Barbara (abelha) quinta · Fernando (flamingo) salto/agilidade a pé · Finn (sapo) resiste a ácido/toxinas · Rae (panda-vermelho) condução/rover.
7. Troca de tripulante só na base/nave-mãe, ao preparar o dia.
8. XP só para o tripulante ativo; cada nível melhora a sua vantagem.
9. Cada tripulante tem o seu mech do kit (mesmo animal); upgrades do mech partilhados.
10. Mechs ajudantes (pack do utilizador): desbloqueados por pesquisa na nave-mãe (item avançado).
11. Ajudantes: de dia regam e colhem a quinta; à noite defendem como torres móveis com IA simples.
12. Nave: transição animada (descolar → mapa da galáxia → aterrar), sem pilotagem.
13. Posto avançado: slots fixos à volta do núcleo; tocar no slot → escolher edifício.
14. Entre planetas passam créditos, dados de pesquisa, tripulação e upgrades; minério, cristal e colheitas ficam (vender antes de partir).
15. Criaturas calmas de dia (só atacam de perto), agressivas à noite.
16. Tutorial guiado no primeiro planeta (prado), primeira noite mais fácil.
17. Português e inglês desde o início (traduções do Godot).
18. Música/som: placeholders CC0 até ao fim da F4.
19. Telemóvel de teste: o mesmo do Deriva Estelar.

## Ronda 3 (06 nov 2026)
1. Apagar só os ramos antigos; manter as releases.
2. Relva "mdvl": pack gratuito do Sketchfab (nome esquecido; conta Epic Games). **Mais relva no mundo.**
3. Rios de ácido estreitos e sinuosos; atravessar por pontes ou a saltar.
4. O ar do planeta ácido gasta O₂ a pé, mais depressa junto aos rios; bolhas repõem; tocar no rio tira vida.
5. Sem O₂ ou sem vida: desmaias e acordas no posto avançado; a encomenda atual falha (paga 0); nada mais se perde.
6. A cabine do rover protege do O₂; atravessar ácido estraga o rover, reparável no posto.
7. Lava: o rover aquece com a velocidade e perto de fissuras; sobreaquecido fica lento; arrefece à sombra ou parado.
8. Criaturas: **empurram e tiram um pouco de vida; às vezes roubam a encomenda (e fogem com ela); um empurrão faz a encomenda perder valor.**
9. Sem combate a pé (combate no mech, à noite e no boss).
10. Monstros do pack: criaturas de todos os mundos, cor ajustada a cada bioma.
11. Ordem dos planetas fixa no início (Prado → Ácido → Lava), depois mais variada.
12. 3 KeyCards por planeta.
13. Amizade 1–5 por colono; pagam mais; encomendas especiais a partir do nível 3.
14. Árvores entre a câmara e o jogador ficam semitransparentes.
15. FPS no telemóvel: **120 fps**.
16. Controlos e câmara: bons.
17. Rover e entregas: divertidos, velocidade e tempos bons. **Quer física mais bouncy (dá para capotar o rover); o rover tem vida e, quando acaba, explode e renasces na base.**

## Ronda 5 — F3: economia, posto e quinta (07 nov 2026)

1. Ordem: save → carteira/venda → slots e edifícios → quinta → upgrades do rover → tripulação.
2. Construção em slots fixos (tocar num slot → menu de edifícios); o construtor livre fica no DBG.
3. 6 slots no início, +2 com um upgrade (até 10).
4. Edifícios da F3: mineiro, laboratório (minério → cristal), centro de pesquisa (dados), painel solar, armazém, talhões da quinta.
5. Energia: cada edifício gasta 1, cada painel dá 3; sem energia suficiente produzem a 50%.
6. Produção: mineiro 1 minério / 20 s; lab 1 cristal / 40 s (gasta 2 minério); pesquisa 1 dado / 60 s; armazém de 20 por edifício.
7. O mineiro produz sozinho no slot (sem depósitos no mapa).
8. Quinta: 4 talhões; 3 culturas (rápida 2 min, média 4 min, lenta 7 min; pagam mais as mais lentas); plantar e colher com um toque.
9. Algumas encomendas perecíveis pedem colheitas da quinta.
10. Upgrades do rover: velocidade, carga, escudo, suspensão; 3 níveis; 150 / 400 / 900 ¢ (+ cristal no nível 3).
11. Terminal no posto avançado: construir, upgrades, vender, tripulação (um menu com separadores).
12. Venda: minério 4 ¢, cristal 15 ¢, colheitas 6–20 ¢ conforme a cultura.
13. Tripulação: os 4 disponíveis já; troca no terminal; vantagem pequena que cresce com o nível; XP por entrega.
14. Save automático (ao sair da app, a cada entrega e a cada construção); um só espaço; "Novo jogo" no menu.
15. Dano e reparação de edifícios: F4.
