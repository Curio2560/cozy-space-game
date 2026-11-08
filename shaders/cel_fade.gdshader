// Variante de cel.gdshader com o pontilhado das árvores no caminho (discard só aqui:
// nos outros modelos o discard desligaria o teste de profundidade antecipado da GPU).
shader_type spatial;
#define USE_FADE
#include "res://shaders/cel_body.gdshaderinc"
