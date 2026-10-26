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
5. Sobre a cabeça de cada freguês fica um **bafômetro** (4 faixas, de Sóbrio a Chumbado) e um
   ícone de **fome**. Cada bebida alcoólica dá fome. Quando a coxinha do ícone fica laranja
   com "!", ele já está alegre e pode pedir um **salgado** da estufa (coxinha ou pastel).
   Atender **corta o porre**, e o bafômetro pisca em azul. Deixar estourar a paciência conta
   como vacilo. Água e refrigerante também "rebatem".

O cardápio de giz na parede atrás do balcão mostra cor, letra, símbolo e preço de cada bebida.

## Testes automatizados

```bash
# headless: 47 verificações de ponta a ponta (movimento, raycast, preparo, entrega,
# validação, atraso, embriaguez individual, fome/salgados, capotar, liberar banqueta,
# fim de turno)
godot --headless --path pinguco -- --autotest

# com janela, salvando screenshots em user://shots
godot --path pinguco -- --autotest --shots

# benchmark de FPS
godot --path pinguco -- --bench

# vitrine: garrafas, fichas e os 6 fregueses (sóbrios e bêbados) em user://shots/gallery_*
godot --path pinguco -- --gallery
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
- **12 bebidas + 2 salgados** em um banco central (`BeverageDatabase`): Cerveja, Pinga,
  Vinho, Caipirinha, Batida, Refrigerante, Quentão, Whisky, Tequila, Gin Tônica, Jurubeba e
  Água, mais Coxinha e Pastel. Cada item tem nome, cor, letra, símbolo, modelo 3D, tempo de
  preparo, força, preço e gírias. Os 14 símbolos (estrela, losango, círculo, limão, coração,
  raio, chama, coroa, sol, lua, gota, folha, coxinha e pastel) usam o mesmo polígono no HUD e
  em 3D. No HUD eles têm sombra, brilho e detalhes desenhados; em 3D, borda exata
  (`Geometry2D.offset_polygon`).
- **Garrafas por revolução (lathe)**: ombro e gargalo suaves, gerados a partir de um perfil.
  Os modelos incluem:
  - long neck com tampinha;
  - garrafa de cachaça com rolha;
  - garrafa de vinho com cápsula;
  - garrafa quadrada de importado com selo;
  - jarra com alça, gelo e limão;
  - panela de quentão no fogareiro;
  - lata;
  - pratinho de salgado.

  O rótulo tem listras na cor da bebida, um medalhão com o símbolo e a letra, e acompanha a
  curva do vidro. Cada bebida tem seu enfeite no copo (colarinho, gelo, sal e limão, canela,
  canudinho...).
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
- **6 perfis de freguês** (`CustomerDatabase`), cada um com visual, falas, tolerância,
  sensibilidade, paciência, ritmo, número de vacilos tolerados, gorjeta, ritmo de fome,
  bebidas favoritas e gestos próprios. Os bonecos têm pescoço e queixo, mãos com dedão e
  dedos, olhos com íris colorida, pupila e brilho, sobrancelhas grossas, boca com dentes e
  língua, orelhas com parte interna, roupas com detalhes e calçados próprios. Cada freguês
  **sorteia** tom de pele, cor da roupa, cor dos olhos e proporções (com semente no
  apelido).
  - **O Tiozão**: regata, careca brilhante, bigodão, caneta na orelha, palito, cordão,
    bermuda e chinelo. Tolerância alta, barrigão que balança na risada.
  - **O Valentão**: braços de academia, tatuagem "MÃE", cicatriz, boné pra trás, brinco,
    corrente e coturno. Impaciente, soca o balcão.
  - **O Falante**: camisa havaiana com gola, botões, bolso e caneta, além de topete e óculos
    com lente. Gesticula sem parar e muda de ideia.
  - **A Fofoqueira**: bobes no cabelão, cílios, pinta, batom, pérolas, saia rodada, bolsa e
    leque. Se abana, põe a mão na boca para fofocar e é fraca para bebida.
  - **O Universitário** (novo): moletom com capuz e cordinhas, mochila, touca, cavanhaque,
    olheiras, fone e celular aceso na mão. Duro, fraco e sempre com fome.
  - **O Malandro** (novo): chapéu panamá, camisa listrada, bigodinho fino, sapato bicolor e
    anel. Batuca samba no balcão, tira o chapéu quando gosta e aguenta muito.
- **Bafômetro sobre a cabeça** (`StatusTag`): sempre visível com o freguês no bar. Mostra
  uma carinha com a cor do estágio, a barra de 4 faixas, o marcador animado e o ícone de
  fome. O painel do freguês mirado mostra também a fome (●●●○○).
- **Fome e salgados**: cada bebida alcoólica soma `hunger_rate` (mais rápido quando
  bêbado). Com fome **e** já alegre, o freguês pode pedir coxinha ou pastel com frases
  próprias ("Mestre, tem coxinha? Não almocei..."). O pedido também é distorcido pela
  bebedeira. O salgado vem pronto da estufa (sem copo): o jogador pega e entrega. Ao comer,
  o freguês zera a fome e a embriaguez **cai**, o que é ruim para o objetivo de fazê-lo
  capotar. Com fome, ele põe a mão na barriga.
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
  interaction/ Interactable (base), BottleDispenser, GlassStack, PrepStation, SnackTray,
               TrashBin, HeldItem
  customers/   CustomerController, CustomerRig, CustomerHitbox, Seat
  ui/          HUDController, SpeechBubble, StatusTag, BeverageChip, Crosshair, DrunkMeter,
               StarRow, UiTheme
  visual/      Mats (toon + contorno), SymbolShapes, BeverageModels
  world/       BarBuilder, BarShaders
  tests/       auto_test.gd, bench.gd, gallery.gd
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
- **Refrigerante e água "rebatem"**: têm força negativa e baixam um pouco a embriaguez. É um
  detalhe de humor e de estratégia.
- **Salgados reaproveitam `BeverageData`** (`category = FOOD`, força negativa). Pedido,
  validação, pistas, ficha e distorção funcionam iguais, sem código duplicado.
  `BeverageDatabase.drinks()` e `foods()` separam os dois onde importa (garrafas,
  preferências). O salgado é um **dilema**: atender corta o porre, recusar gera vacilo e
  pode fazer o freguês ir embora bravo.
- **Com 12 cores, a cor sozinha fica ambígua**. Por isso, quando um pedido "Chumbado" mostra
  só 1 pista, ela é sempre letra ou símbolo, nunca só a cor.
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
- Na GT 210 o jogo roda a ~24–28 FPS (os bonecos e as garrafas mais detalhados custaram ~2
  FPS). A física ainda é estável, mas o ideal é uma GPU mais
  recente.

## Próximas melhorias prioritárias

1. Menu de opções: sensibilidade, FOV, volume por bus, qualidade gráfica, reduzir tremida.
2. Navegação com desvio entre fregueses e animação de sentar/levantar mais rica.
3. Áudio real (vozes gravadas, foley) no lugar dos placeholders. A arquitetura já carrega
   por nome.
4. Progressão: várias noites, upgrades do bar, novos fregueses (o Bebum Filósofo, o
   Turista), bebidas misturadas (receitas com 2 garrafas) e salgados que precisam ser
   fritos.
5. Eventos de caos: jogo na TV (todo mundo pede ao mesmo tempo), queda de energia, fiscal.
6. Visual: texturas pintadas à mão, partículas (espuma, respingos) e luz baked para GPUs
   fracas.

## Créditos

- Fontes: [Lilita One](https://fonts.google.com/specimen/Lilita+One) e
  [Fredoka](https://fonts.google.com/specimen/Fredoka), ambas sob a SIL Open Font License
  (licenças em `assets/fonts/`).
- Todo o resto (modelos, shaders, sons e música) é procedural e foi criado para este
  projeto.
