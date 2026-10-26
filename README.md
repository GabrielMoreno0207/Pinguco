# Pinguço

Comédia em primeira pessoa: você é dono do **Bar do Pinguço** e precisa servir os fregueses
até eles capotarem no balcão. Quanto mais bêbado o freguês, mais enrolado fica o pedido, e
você precisa decifrar o que ele quer pela cor, pela letra, pelo símbolo e pelo contexto.

Protótipo jogável feito em **Godot 4.7 (GDScript)**. Todo o conteúdo (modelos, texturas,
sons e música) é gerado proceduralmente no código. As únicas exceções são duas fontes
livres (OFL).

## Como rodar

1. Instale o [Godot 4.7](https://godotengine.org/download) (versão padrão, não a .NET).
   Neste repositório o executável fica em `../godot/`, que está fora do controle de versão.
2. Abra `pinguco/project.godot` no editor e aperte **F5**, ou rode pela linha de comando:

```bash
godot --path pinguco
```

### Controles

| Tecla | Ação |
|---|---|
| WASD | andar |
| Mouse | olhar |
| E / clique | interagir (**segure** para servir/preparar) |
| Q | descartar o que está na mão |
| Shift | correr |
| Esc / P | pausar |

### Como jogar

1. Pegue um **copo** (bandeja "COPOS" na bancada de trás) e apoie numa das 3 áreas de
   **PREPARO** do balcão.
2. Pegue a **garrafa** certa (geladeira, prateleira ou jarras da bancada), mire no copo e
   **segure E** até a barra encher. A garrafa volta sozinha para o lugar.
3. Pegue o copo pronto e entregue (E) ao **freguês certo**.
4. Cada dose aumenta a embriaguez **daquele** freguês. Ao chegar no limite, ele capota, dorme
   e depois vai embora, liberando a banqueta.

O cardápio de giz na parede atrás do balcão mostra cor, letra, símbolo e preço de cada bebida.

## Testes automatizados

```bash
# headless: 42 verificações de ponta a ponta (movimento, raycast, preparo, entrega,
# validação, atraso, embriaguez individual, capotar, liberar banqueta, fim de turno)
godot --headless --path pinguco -- --autotest

# com janela, salvando screenshots em user://shots
godot --path pinguco -- --autotest --shots

# benchmark de FPS
godot --path pinguco -- --bench
```

Outras opções: `-- --low` força o modo leve e `-- --high` força o modo completo.

## O que está implementado

- **Cenário**: buteco completo com balcão de madeira e azulejo, 4 banquetas, prateleiras,
  geladeira "GELADA" com porta de vidro, bancada com pia, copos, jarras, liquidificador e
  caixa registradora, estufa de salgados, mesas e cadeiras de plástico, sinuca, engradados,
  TV passando futebol, ventiladores de teto, bandeirinhas, cartazes ("FIADO? SÓ AMANHÃ!"),
  flâmula, calendário, relógio de parede que acompanha o turno, porta de enrolar e a rua lá
  fora. Piso de caquinhos vermelhos e azulejos são shaders procedurais.
- **Jogador**: CharacterBody3D com WASD, mouse, gravidade, colisão, balanço de câmera,
  passos, tremida de câmera e mãos em primeira pessoa que seguram, inclinam para servir e
  reagem. Paredes invisíveis mantêm o jogador atrás do balcão.
- **Interação**: raycast da câmera, destaque pulsante em amarelo no objeto mirado, prompt
  com a ação ("Pegar Cerveja", "Segure: Amassando o limão"), dicas quando a ação não é
  possível e anel de progresso na mira.
- **6 bebidas** em um banco central (`BeverageDatabase`), cada uma com nome, cor, letra,
  símbolo, modelo 3D (long neck, garrafa, jarra ou lata), tempo de preparo, força, preço e
  gírias. Os símbolos (estrela, losango, círculo, limão, coração e raio) usam o mesmo
  polígono no HUD e em 3D.
- **Pedidos**: balões de fala projetados sobre a cabeça do freguês, com texto, ficha da
  bebida com as pistas visíveis e barra de paciência. A entrega só é válida se for **este**
  freguês, com pedido aberto e a bebida certa. Entregar ao freguês errado conta como erro e
  o copo continua na sua mão.
- **Embriaguez em 4 estágios** (Sóbrio, Alegre, Bêbado e Chumbado), individual por freguês.
  O texto distorcido é gerado **a partir do pedido verdadeiro**, e o id da bebida nunca se
  perde:
  - Alegre: vogais esticadas, letras duplicadas, risadas.
  - Bêbado: gírias ("loira gelada", "marvada"), nome truncado, fala enrolada (s→x),
    trocas de letras e *hic*. A ficha mostra 2 das 3 pistas.
  - Chumbado: frases fragmentadas, palavras omitidas e frases absurdas ("cadê meu
    cavalo?"). A ficha mostra 1 pista, mas sempre sobra um pedaço do nome ou uma gíria.
    "Mais uma daquela!" usa o contexto (última bebida, mostrada no bafômetro).
  - Além do texto: pálpebras caindo, olhos vesgos, bochechas e nariz vermelhos, balanço do
    corpo, soluços, voz mais grave e arrastada, pedidos mais rápidos e imprevisíveis (o
    freguês às vezes muda de ideia ou pede qualquer coisa).
- **4 perfis de freguês** (`CustomerDatabase`), cada um com visual, falas, tolerância,
  sensibilidade, paciência, ritmo, número de vacilos tolerados, gorjeta, bebidas favoritas e
  gestos próprios:
  - **O Tiozão**: careca de bigode, barrigão que balança na risada, tolerância alta.
  - **O Valentão**: boné pra trás, corrente de ouro e monocelha. Impaciente, soca o
    balcão.
  - **O Falante**: topete, óculos e camisa estampada. Gesticula sem parar e muda de ideia.
  - **A Fofoqueira**: cabelão cacheado, pérolas e batom. Põe a mão na boca para fofocar e
    é fraca para bebida.
- **Capotar**: cabeça cai no balcão com quique, "tum", tremida de câmera, Zs flutuando e
  ronco. Aparece um banner engraçado ("Tio Valdir capotou contando a piada do pavê!"). Depois
  o freguês acorda assustado e sai cambaleando.
- **Turno**: das 18h às 2h (5 min reais). Os fregueses chegam cada vez mais rápido. A
  paciência estoura e gera atraso; vacilos demais e o freguês vai embora bravo e o bar
  perde fama. Com zero estrelas, o turno acaba mais cedo.
- **HUD**: dinheiro, atendidos, capotados, acertos/erros/atrasos, relógio de giz com tempo
  restante, fama (estrelas), item na mão, bafômetro do freguês mirado, textos flutuantes de
  acerto/erro/atraso com combo, telas de início, pausa e resultados (com título de
  ranking).
- **Áudio**: arquitetura de buses (Music, SFX, Voice, Ambience) e registro por nome. Se
  existir `assets/audio/<nome>.ogg|.wav`, ele é usado. Caso contrário, um placeholder é
  sintetizado: tilintar de copo, garrafa, líquido, acerto, erro, atraso, moedas, campainha,
  passos, vidro quebrando, vozes cartunescas em "sílabas" (tom por perfil, arrastadas
  quando bêbados), risadas, resmungos, ronco, burburinho de bar e um rádio tocando pagode
  (surdo, pandeiro, tamborim e cavaquinho em Karplus-Strong).

## Arquitetura

```
scripts/
  main.gd                       monta o mundo e controla menu/turno/pausa/resultados
  data/        BeverageData, CustomerProfile (Resources)
  systems/     BeverageDatabase*, CustomerDatabase*, GameManager*, AudioManager*  (*autoload)
               OrderSystem, DrunkennessSystem, CustomerSpawner, ShiftManager
  player/      PlayerController, InteractionSystem, Hands
  interaction/ Interactable (base), BottleDispenser, GlassStack, PrepStation, TrashBin, HeldItem
  customers/   CustomerController, CustomerRig, CustomerHitbox, Seat
  ui/          HUDController, SpeechBubble, BeverageChip, Crosshair, DrunkMeter, StarRow, UiTheme
  visual/      Mats (toon + contorno), SymbolShapes, BeverageModels
  world/       BarBuilder, BarShaders
  tests/       auto_test.gd, bench.gd
```

- Os sistemas se comunicam por **sinais**. O HUD escuta `GameManager`, `ShiftManager` e
  `InteractionSystem`, e só os balões acompanham a câmera a cada frame.
- **Adicionar uma bebida**: inclua um dicionário em `BeverageDatabase.CATALOG` ou salve um
  `BeverageData` `.tres` em `res://data/beverages/`. O dispenser aparece sozinho na
  geladeira, na prateleira ou na bancada, conforme `station`.
- **Adicionar um freguês**: inclua um perfil em `CustomerDatabase.PROFILES` ou salve um
  `.tres` em `res://data/customers/`.

## Decisões importantes

- **Godot 4 + GDScript**, como pede o prompt para projeto vazio. As skills do repositório
  [gamedev-agent-skills](https://github.com/minhhoit/gamedev-agent-skills) usadas como guia
  foram router, godot-gdscript, godot-nodes-scenes, godot-signals-groups,
  godot-3d-essentials, godot-physics, godot-ui-control, godot-animation, godot-resources,
  godot-audio, camera-systems, game-feel, game-ui-ux, audio-design, create-game-assets e
  prototype-fast.
- **Tudo gerado em código** (cenas montadas por scripts, sem `.tscn` complexos). Isso mantém
  o projeto diffável, sem assets binários, e torna os testes simples. A cena `main.tscn`
  só tem a raiz.
- **Arte**: estilo toon com contorno por casca invertida, cores saturadas e cabeças
  grandes. As animações são procedurais (tweens e senoides) em vez de AnimationPlayer, o
  que facilita reagir à embriaguez em tempo real.
- **Fluxo de preparo** com 3 etapas (copo → servir segurando E → entregar). Isso dá o
  "trabalho de bar" sem virar menu. A garrafa volta sozinha para evitar tédio.
- **Refrigerante "rebate"**: tem força negativa e baixa um pouco a embriaguez. É um detalhe
  de humor e de estratégia.
- **Renderer de compatibilidade (OpenGL 3.3)**. A máquina de desenvolvimento tem uma
  GeForce 210, sem Vulkan e sem D3D12. No renderer de compatibilidade, o jogo ativa um
  **modo leve** automaticamente:
  - uma luz direcional no lugar das 9 luzes pontuais;
  - Environment mínimo (sem glow, fog ou ajustes, que custavam metade do frame);
  - 3D a 60% da resolução, com o HUD nítido;
  - shading por vértice e piso pré-renderizado em textura.

  Além disso, toda a geometria estática é **mesclada por material** (≈1000 → ≈230 draw
  calls) e a tesselação se adapta ao tamanho. Resultado: de 3 para ~28 FPS na GT 210. Em
  GPUs modernas, troque o renderer para Forward+ no `project.godot` para ter luzes
  pontuais, sombras, glow e fog.

## Limitações conhecidas

- Os fregueses andam em linha reta (sem navmesh) e atravessam outros fregueses quando se
  cruzam.
- Os sons são sintetizados (placeholders) e as vozes são "blablablá", sem dublagem.
- Há um único turno/cenário, sem progressão entre noites nem save.
- Não há opções de sensibilidade do mouse, volume ou acessibilidade na interface (os
  valores ficam nos `@export` do `PlayerController` e nos buses do `AudioManager`).
- Na GT 210 o jogo roda a ~25–30 FPS. A física ainda é estável, mas o ideal é uma GPU mais
  recente.

## Próximas melhorias prioritárias

1. Menu de opções: sensibilidade, FOV, volume por bus, qualidade gráfica, reduzir tremida.
2. Navegação com desvio entre fregueses e animação de sentar/levantar mais rica.
3. Áudio real (vozes gravadas, foley) no lugar dos placeholders. A arquitetura já carrega
   por nome.
4. Progressão: várias noites, upgrades do bar, novos fregueses (o Bebum Filósofo, o
   Turista) e bebidas misturadas (receitas com 2 garrafas).
5. Eventos de caos: jogo na TV (todo mundo pede ao mesmo tempo), queda de energia, fiscal.
6. Visual: texturas pintadas à mão, partículas (espuma, respingos) e luz baked para GPUs
   fracas.

## Créditos

- Fontes: [Lilita One](https://fonts.google.com/specimen/Lilita+One) e
  [Fredoka](https://fonts.google.com/specimen/Fredoka), ambas sob a SIL Open Font License
  (licenças em `assets/fonts/`).
- Todo o resto (modelos, shaders, sons e música) é procedural e foi criado para este
  projeto.
