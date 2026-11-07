# Performance

Alvo: 60 fps num Android médio, renderer Compatibility (GLES3).

## Medições no PC de desenvolvimento (06 nov 2026)

Sem GPU (llvmpipe), por isso os FPS daqui não contam; contam as draw calls e os triângulos
(iguais no telemóvel). Cena "Jogar (protótipo)", seed 7, 1280×720:

| Situação | Draw calls | Triângulos |
|---|---|---|
| A pé, junto ao posto avançado | 106 | 212k |
| A conduzir o rover | 109 | 206k |

Antes das otimizações da #9: 75 dc · 248k tri (com culling incorreto: árvores podiam
desaparecer no horizonte).

## O que já está feito

- Decoração em MultiMesh, um material partilhado por paleta (~5 no kit todo).
- Culling por hemisfério com 42 regiões; a margem angular vem do objeto mais alto, por isso
  nada desaparece no horizonte.
- Variantes leves dos modelos com mais peso (Bush_3 640 tri vs Bush_1 2304; Tree_Blob_3
  1,9k vs Tree_Blob_1 6,1k).
- Relva sem passe de contorno; terreno sem rim nem brilho; sol sem sombras.

## Medir no telemóvel

O canto superior direito (builds debug) mostra `fps · draw calls · k tri`. O DBG tem
**Resolução 3D** (0,5–1,0) para testar o custo de fill rate.

## Plano se o telemóvel ficar abaixo de 60 fps

1. Baixar a resolução 3D por omissão (0,8) — maior ganho se o limite for fill rate.
2. Tirar o contorno a arbustos, plantas e rochas pequenas (metade dos triângulos deles).
3. Reduzir densidade ou distância de desenho da relva e plantas (visibility range por região).
4. LODs próprios para Tree_Blob_1/2 (as cópias com normais suaves perdem os LODs do import).

## F2 — fecho (07 nov 2026, v0.2.0)

### No telemóvel do utilizador (capturas da v0.1.15, contador do canto)

| Bioma / situação | FPS | Draw calls | Triângulos |
|---|---|---|---|
| Prado, a conduzir | 52 | 260 | 485k |
| Ácido, a pé junto à base | 45 | 343 | 602k |

### No PC (llvmpipe; só contam draw calls e triângulos), seed 7, 1280×720, v0.2.0

| Bioma | A pé | A conduzir |
|---|---|---|
| Prado | 184 dc · 418k tri | 218 dc · 438k tri |
| Ácido | 195 dc · 456k tri | 194 dc · 442k tri |
| Lava | 165 dc · 325k tri | 159 dc · 311k tri |

### O que a F2 acrescentou e quanto custa

- Relevo: 6–9 malhas (~7,7k tri no total por planeta), uma draw call cada, entram no culling
  por região.
- Rios/fissuras: uma malha e uma draw call para todos; pontes: uma malha cada.
- Bolhas de O₂: 26 esferas de 144 tri (só no ácido).
- Partículas ambiente: 50–80 partículas CPU numa só draw call.
- Árvores pontilhadas: o `discard` só existe na variante de shader das árvores
  (`cel_fade`/`outline_fade`); os outros modelos mantêm o teste de profundidade antecipado.
- Vento: só vértices (barato).

### Conclusão

45–52 fps no telemóvel com 485–600k triângulos: o limite parece ser a geometria (o ácido,
com mais triângulos, é o mais lento). Abaixo do alvo de 60 fps, mas jogável; o plano acima
continua válido, começando pelo passo 2 (contornos) e 3 (relva/plantas), que são os que mais
triângulos tiram. Fica para a F3.
