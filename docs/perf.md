# Performance (F1)

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
