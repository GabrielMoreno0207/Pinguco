# Pinguço

Comédia em primeira pessoa: você é dono do **Bar do Pinguço** e precisa servir os fregueses
até eles capotarem no balcão. Quanto mais bêbado o freguês, mais enrolado fica o pedido, e
você precisa decifrar o que ele quer pela cor, pela letra, pelo símbolo e pelo contexto.

Protótipo jogável feito em **Godot 4.7 (GDScript)**. Todo o conteúdo (modelos, texturas,
sons e música) é gerado proceduralmente no código. As únicas exceções são duas fontes
livres (OFL). As malhas dos fregueses e das mãos do jogador são esculpidas por código fora
do jogo (`tools/bake_customers.py` e `tools/bake_hands.py`) e ficam gravadas em
`assets/customers/` e `assets/hands/`.

## Como rodar

1. Instale o [Godot 4.7](https://godotengine.org/download) (versão padrão, não a .NET).
   O executável fica fora do controle de versão; aponte `godot` para onde você o salvou.
2. Num clone novo, importe uma vez. A pasta `.godot/` não é versionada, e sem ela o Godot
   não conhece as classes do projeto: o jogo abre numa tela preta.

```bash
godot --headless --path . --import
```

3. Abra `project.godot` no editor e aperte **F5**, ou rode pela linha de comando:

```bash
godot --path .
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

### Abertura, menu e opções

O jogo abre com a tela de abertura (aperte qualquer tecla). Depois vem o menu principal, com
a câmera passeando pelo bar atual ao fundo:

- **ABRIR O BAR / CONTINUAR · DIA N**: começa o turno.
- **BAR FECHADO**: entra sem abrir o turno, para recolher o caixa, investir e arrumar.
- **COMO JOGAR**, **OPÇÕES** (volume geral, música, efeitos, sensibilidade do mouse e tela
  cheia, salvos em `user://settings.cfg`), **NOVO JOGO** (apaga o progresso, com confirmação)
  e **SAIR**.

Na pausa (Esc) também há Opções e Menu principal.

### Fora do expediente: caixa, investimentos e arrumação

No fim do turno a féria vai para a **gaveta da caixa registradora** (bancada de trás, perto
da geladeira). Em **FECHAR O CAIXA** a freguesia vai embora e você anda livre pelo bar fechado.
Também dá para entrar direto pelo menu, em **ARRUMAR O BAR**.

- **Caixa registradora**: o primeiro E recolhe o dinheiro da gaveta para o saldo. Depois, o E
  abre o **caderninho do bar**, que tem três abas:
  - **Atendimento**: banqueta extra (+2 lugares), cardápio reajustado (preços +15%),
    equipamento novo (preparo 15% mais rápido), amendoim de cortesia (paciência +15%) e
    letreiro de neon (placa ABERTO na fachada; fregueses chegam 12% mais rápido).
  - **Reformas**: mudam o visual do bar, e cada nível rende +R$ 1 de gorjeta por pedido.
    Pintura nova (some a parede descascada), piso novo, iluminação (varal de lâmpadas, depois
    neon nas paredes), TV de tela grande (troca a TV de tubo e põe uma segunda TV), decoração
    (plantas e quadros, depois a jukebox, que passa a tocar phonk no lugar do rádio) e mobília nova (banquetas estofadas, toalha e vela
    nas mesas).
  - **Mudar de ponto**: depois de um tempo o Pinguço pode abrir um bar totalmente novo
    (veja abaixo).

  Tudo vale a partir do próximo turno.
- **Arrumar as bebidas**: pegue qualquer garrafa e aponte para um **círculo amarelo** (lugar
  vazio na geladeira, na prateleira ou na bancada) ou para outra garrafa, para trocar as duas
  de lugar. A arrumação vale para os turnos seguintes.
- **Esc → ABRIR O BAR** começa o próximo dia.

### Mudar de ponto

| Ponto | Onde | Requisitos | Preço | Economia |
|---|---|---|---|---|
| Bar do Pinguço | Vila Esperança | início | | preços x1.0, 4 banquetas |
| Choperia do Pinguço | Centro da cidade | dia 5 e 3 reformas | R$ 1.200 | preços x1.5, 5 banquetas, mais movimento |
| Pinguço Beach Club | Orla da praia | dia 10 e 4 reformas | R$ 3.200 | preços x2.2, 5 banquetas, muito movimento |

Cada ponto é um bar novo. Mudam as paredes, o piso, o teto, o balcão, a geladeira, os móveis
do salão (mesa de plástico e sinuca; mesas de madeira com barris e alvo de dardos; guarda-sol
com espreguiçadeiras e pranchas), os cartazes, o letreiro, a decoração e o mundo lá fora,
montado em 3D: rua de bairro com calçada, fiação, carro e casas de janela acesa; avenida do
Centro com torres, faixa de pedestre e ponto de ônibus; ou a praia, com areia, mar ondulando
até o horizonte, coqueiros e torre de salva-vidas.

**A praia não é um salão, é um quiosque**: telhado de palha sobre pilares, piso de deck,
guarda-corpo baixo nas laterais e parede só no fundo. O salão vira a areia — as mesas com
guarda-sol ficam lá fora, de frente para o mar. Mesmo assim a área atrás do balcão continua
idêntica à dos outros pontos, então o jeito de jogar não muda. Melhorias, reformas e arrumação
começam do zero (e custam mais) no ponto novo.

Dia, ponto, saldo, gaveta, melhorias e arrumação ficam salvos em `user://bar_progress.json`. O botão
"zerar progresso" do menu apaga tudo. Os modos de teste não leem nem gravam esse arquivo.

## Testes automatizados

```bash
# headless: 47 verificações de ponta a ponta (movimento, raycast, preparo, entrega,
# validação, atraso, embriaguez individual, fome/salgados, capotar, liberar banqueta,
# fim de turno)
godot --headless --path . -- --autotest

# com janela, salvando screenshots em user://shots
godot --path . -- --autotest --shots

# benchmark de FPS
godot --path . -- --bench

# vitrine: garrafas, mãos, fichas, os 6 fregueses (de frente, 3/4, perfil, sentados) e as
# expressões neutro/feliz/bravo/bêbado de cada um em user://shots/gallery_*
godot --path . -- --gallery

# vitrine do cenário: cada ponto (original e reformado) de 6 ângulos fixos, para
# conferir iluminação, materiais e a vista lá de fora em user://shots/view_*
godot --path . -- --views
godot --path . -- --views --full --loc=praia   # só o quiosque reformado
```

Outras opções: `-- --low` força o modo leve, `-- --high` força o modo completo e
`-- --escala=0.85` muda a resolução de renderização do 3D no modo leve (padrão 0,6).

## O que está implementado

- **Cenário**: buteco completo com balcão de madeira e azulejo, 4 banquetas, prateleiras,
  geladeira "GELADA" com porta de vidro, bancada com pia, copos, jarras, liquidificador e
  caixa registradora, estufa de salgados, mesas e cadeiras de plástico, sinuca, engradados,
  TV passando futebol, ventiladores de teto, bandeirinhas, cartazes ("FIADO? SÓ AMANHÃ!"),
  flâmula, calendário, relógio de parede que acompanha o turno, porta de enrolar, espelho
  com fita de luz atrás das prateleiras e a rua lá fora, montada em 3D. Piso de caquinhos,
  azulejo, madeira (veio, nós e verniz), fachadas, asfalto, areia e mar são shaders
  procedurais. A iluminação é por zonas — lâmpadas com cúpula jogando a luz para baixo,
  calha sobre a bancada, geladeira acesa, letreiro e neon —, cada uma com o seu feixe no ar
  e a sua poça no chão.
- **Jogador**: CharacterBody3D com WASD, mouse, gravidade, colisão, balanço de câmera,
  passos, tremida de câmera e mãos em primeira pessoa esculpidas (malha contínua com
  esqueleto em cada falange, unhas, nós dos dedos, antebraço com pelinhos, manga dobrada e
  relógio). Ao pegar algo, cada dedo fecha até encostar no item (o raio é medido pela malha,
  então a mão abraça uma long neck ou abre numa jarra), o dedão cruza a frente, e o
  antebraço gira para servir. Paredes invisíveis mantêm o jogador atrás do balcão.
- **Interação**: raycast da câmera, destaque pulsante em amarelo no objeto mirado, prompt
  com a ação ("Pegar Cerveja", "Segure: Amassando o limão"), dicas quando a ação não é
  possível e anel de progresso na mira.
- **12 bebidas + 2 salgados** em um banco central (`BeverageDatabase`): Cerveja, Pinga,
  Vinho, Caipirinha, Batida, Refrigerante, Quentão, Whisky, Tequila, Gin Tônica, Jurubeba e
  Água, mais Coxinha e Pastel. Cada item tem nome, cor, letra, símbolo, modelo 3D, tempo de
  preparo, força, preço e gírias. Os 14 símbolos são temáticos: caneca de chope (cerveja),
  barril (pinga), cacho de uva (vinho), meia rodela de limão (caipirinha), morango (batida),
  raio, chama, coroa, sol, lua, folha, gota, coxinha e pastel. Eles usam o mesmo polígono no
  HUD e em 3D e têm estilo de adesivo (miolo claro e contorno escuro, legível em qualquer
  cor de ficha). No HUD ganham detalhes desenhados (espuma, aduelas, gomos, sementes...),
  e a ficha mostra a letra num selinho no canto. Em 3D a borda é exata
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
  curva do vidro. O vidro tem reflexo, e as geladas têm gotas de condensação. As jarras têm
  líquido translúcido, rodelas de limão com gomos ou morangos com folhinha. O copo servido
  mostra a superfície do líquido, e cada bebida tem seu enfeite (colarinho cremoso,
  rodelas de limão e gelo, borda de sal, rodela de pepino, laranja e canela, canudinho...).
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
  bebidas favoritas e gestos próprios. Os bonecos são **modelados** no estilo bonequinho de
  vinil: malha contínua de plástico liso (sem contorno), cabeça oval, olhões brancos
  saltados com pupila pretinha, sobrancelhas grossas, nariz de bolinha e corpo esguio. O
  corpo é uma malha só, com esqueleto (ombro, cotovelo, quadril, joelho e a barriga do
  Tiozão) que dobra ao sentar, andar e gesticular. As roupas têm barras, golas, bolsos e
  estampas recortadas na malha, e cada tipo tem seu calçado (tênis, sapato, coturno,
  chinelo, scarpin). Cada freguês **sorteia** tom de pele, cor da roupa, variações de
  acessório (boné, touca, mochila) e altura (com semente no apelido).
  - **Expressões** (`CustomerRig.set_expression`): feliz (maçãs do rosto sobem, olhos
    apertados por baixo, boca em "U"), bravo (pálpebras inclinadas, sobrancelhas tortas,
    boca prensada em "∩") e bêbado (olhos desiguais, uma sobrancelha erguida, boca torta e
    meio aberta). O `CustomerController` só repassa o humor que já calculava.
  - **O Tiozão**: regata, careca brilhante, bigodão, caneta na orelha, cordão,
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
  existir `assets/audio/<nome>.ogg|.wav|.mp3`, ele é usado. Já vêm gravados: servir
  (`pour`), caixa registradora (`coin`), sininho da porta (`doorbell`), vidro quebrando
  (`glass_break`), a música do expediente (`music`, "Noite de Barzinho"), que é a
  faixa padrão em qualquer tela, e o phonk (`music_jukebox`), que só toca quando a jukebox está
  instalada — trocadas com crossfade (créditos em `assets/audio/CREDITS.txt`).
  O resto é sintetizado: tilintar de copo, garrafa, acerto, erro, atraso, passos, vozes
  cartunescas em "sílabas" (tom por perfil, arrastadas quando bêbados), risadas, resmungos,
  ronco e burburinho de bar.

## Arquitetura

```
scripts/
  main.gd                       monta o mundo e controla menu/turno/pausa/resultados
  data/        BeverageData, CustomerProfile (Resources), BarLocations (temas dos pontos)
  systems/     BeverageDatabase*, CustomerDatabase*, GameManager*, AudioManager*,
               BarProgress* (save: dia, ponto, saldo, melhorias, arrumação),
               Settings* (opções)  (*autoload)
               OrderSystem, DrunkennessSystem, CustomerSpawner, ShiftManager
  player/      PlayerController, InteractionSystem, Hands
  interaction/ Interactable (base), BottleDispenser, BottleSlot, CashRegister, GlassStack,
               PrepStation, SnackTray, TrashBin, HeldItem
  customers/   CustomerController, CustomerRig, CustomerHitbox, Seat
  ui/          HUDController, MainMenu, OptionsPanel, SpeechBubble, StatusTag, BeverageChip, Crosshair, DrunkMeter,
               StarRow, UiTheme
  visual/      Mats (toon + contorno, plástico, madeira, vidro), SymbolShapes,
               BeverageModels, DrinkShaders (vidro, líquido, espuma)
  world/       BarBuilder (salão fechado e quiosque), BarAtmosphere (céu, hora e
               pós-processamento), OutsideBuilder (rua, Centro, praia),
               LightFX (feixes e poças de luz), BarShaders
  tests/       auto_test.gd, bench.gd, gallery.gd, scene_shots.gd
tools/
  sdf_sculpt.py                 escultura por SDF -> malha (marching cubes, decimação,
                                regiões de material recortadas, pesos de esqueleto)
  bake_customers.py             os 6 fregueses; grava assets/customers/<perfil>.bin
  bake_hands.py                 mãos do jogador; grava assets/hands/hand_r.bin e hand_l.bin
```

- Os sistemas se comunicam por **sinais**. O HUD escuta `GameManager`, `ShiftManager` e
  `InteractionSystem`, e só os balões acompanham a câmera a cada frame.
- **Adicionar uma bebida**: inclua um dicionário em `BeverageDatabase.CATALOG` ou salve um
  `BeverageData` `.tres` em `res://data/beverages/`. O dispenser ocupa sozinho o primeiro
  `BottleSlot` livre da geladeira, da prateleira ou da bancada, conforme `station`. Se o
  jogador já tiver arrumado a garrafa, ela vai para o lugar salvo.
- **Adicionar um freguês**: inclua um perfil em `CustomerDatabase.PROFILES` ou salve um
  `.tres` em `res://data/customers/`. Um tipo de corpo novo também precisa de uma função de
  modelo em `tools/bake_customers.py` e de uma entrada em `CustomerRig.FILES`.
- **Mexer no visual dos fregueses**: edite `tools/bake_customers.py` e rode
  `python tools/bake_customers.py` (precisa de `numpy`, `scikit-image` e
  `fast-simplification`; `--fast` gera uma prévia com voxel maior). Cada freguês é a união
  suave de primitivas num campo de distância: o script extrai a malha, simplifica, recorta
  as bordas de cor (roupa, cabelo, listras, bolinhas) e calcula os pesos do esqueleto. A
  escultura é feita em pose A (braços e pernas afastados) para nada se fundir com o
  tronco. Confira com `godot --path . -- --gallery`.
- **Exportar o jogo**: os `.bin` não são recursos do Godot. No preset de exportação, inclua
  `assets/customers/*.bin` em *Filtros para exportar arquivos/pastas não-recurso*.
- **Mexer no ícone**: edite `tools/make_icon.py` e rode `python tools/make_icon.py` (precisa de
  `pillow`; `--preview` salva um PNG grande para conferir). Ele gera `assets/icon.png`, usado
  como ícone da janela, e `assets/icon.ico`, para apontar em *Application > Icon* ao exportar
  no Windows.

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
- **Arte**: o cenário usa estilo toon com contorno por casca invertida e cores saturadas.
  Os fregueses usam plástico liso, como bonequinhos de vinil, com malhas esculpidas por
  SDF em vez de primitivas encaixadas. As animações são procedurais (tweens e senoides)
  em vez de AnimationPlayer, o que facilita reagir à embriaguez em tempo real. O
  controlador gira nós comuns, e o `CustomerRig` copia esses nós para o esqueleto a cada
  frame.
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
- **Cartoon chapado, não realista**. O estilo é desenho animado: cor sólida, contorno e
  silhueta. Por isso os materiais são **foscos de propósito** — `SPECULAR_DISABLED` no
  toon, especular baixo nos shaders, nenhum mapa de normal e glow só no que é luz de
  verdade (lâmpada, neon, letreiro), com limiar alto. Reflexo e relevo puxam a cena para o
  realista e deixam tudo "brilhoso"; o que dá forma aqui é a **luz**, não o brilho.
  Quem quiser mexer: `Mats.toon()`, `BarShaders.WALL/WOOD/FLOOR`, `DrinkShaders.GLASS` e
  o bloco de pós-processamento em `BarAtmosphere.setup()`.

- **Borda lisa**: MSAA 4× no Forward+, que resolve o serrilhado de vez. No modo leve não
  há antisserrilhado possível — o renderer de compatibilidade não tem FXAA e MSAA ali é
  caro demais —, então o único botão é a resolução de renderização do 3D. Ela está em 60%,
  que é o que a GT 210 aguenta; em placa melhor suba com `-- --escala=0.85` (a conta é
  quadrática: 0,85 custa o dobro de 0,6).

- **Forward+ por padrão, com queda limpa para OpenGL**. O jogo pede `forward_plus` no
  `project.godot`. Em GPU sem Vulkan/D3D12 (a máquina de desenvolvimento tem uma GeForce
  210, de 2009) o Godot cai sozinho para `gl_compatibility`, e aí o jogo liga o **modo
  leve**. Geometria, shaders e materiais são os mesmos; o que muda é a iluminação:

  | | Forward+ | modo leve (OpenGL) |
  |---|---|---|
  | luzes | todas as pontuais, com sombra nas principais | **uma** direcional (ver abaixo) |
  | oclusão de contato | SSAO suave | — |
  | ar do bar | nevoeiro volumétrico + poças de luz | poças de luz |
  | feixe de luz no ar | sim | não (cone aditivo cobre muita tela) |
  | glow | só no que é luz, limiar alto | desligado |
  | correção de cor | sim | desligada |
  | resolução 3D | cheia, MSAA 4× | 60%, sem antisserrilhado |

  **Por que uma luz só.** No renderer de compatibilidade cada luz a mais faz o cenário ser
  redesenhado. Então lá existe o sol do `BarAtmosphere` e mais nada: dentro do salão
  fechado ele vira luz quente vinda de cima, fazendo o papel das lâmpadas, e o
  preenchimento vira luz de ambiente, que é de graça. A forma da luz — a poça clara
  debaixo de cada lâmpada, no chão e no teto — vem do `LightFX`, que são malhas aditivas
  sem sombreamento.

  O sombreado voltou a ser **por pixel** mesmo no modo leve: por vértice, numa caixa de 8
  vértices, não sobra variação nenhuma — era o que mais achatava o cenário.

  Além disso, toda a geometria estática é **mesclada por material** (≈1000 → ≈230 draw
  calls), cada shader é compilado uma vez só (`BarShaders.shader_for`), materiais iguais
  são compartilhados (`BarShaders.shared`) e a tesselação se adapta ao tamanho da peça.

- **O relógio do turno comanda o céu**. O turno vai das 18h às 2h e `BarAtmosphere.set_hour()`
  leva o céu do fim de tarde até a noite fechada: o sol poente baixa e esfria virando lua, o
  nevoeiro troca de cor e a luz que entra de fora acompanha. Custa zero por frame (são só
  propriedades do `Environment` e de duas luzes direcionais) e dá a passagem do tempo sem
  nenhum sistema novo.

- **A praia é um quiosque, não um salão**. Os outros dois pontos são salões fechados; a
  praia tem `open: true` e uma planta menor em `BarLocations`, e o `BarBuilder` monta
  telhado de palha sobre pilares, guarda-corpo baixo nas laterais e parede só no fundo.
  O salão vira a areia: as mesas saem de baixo da cobertura e o mar fica à vista. A área de
  trabalho atrás do balcão continua idêntica à dos outros pontos, então a jogabilidade e os
  testes não mudam.

- **O lado de fora é geometria, não um quadro pintado**. Antes a vista era um *quad* com
  um shader. Agora o `OutsideBuilder` monta rua, calçada, asfalto, fiação, carro e casas
  (bairro), avenida com torres, faixa de pedestre e ponto de ônibus (Centro), ou areia,
  mar com ondas no vertex, coqueiros e torre de salva-vidas (praia). O nevoeiro come o que
  está longe, então o custo fica no que se vê.

- **Vidro desenha só a face da frente**. O vidro antes era um material transparente com as
  duas faces desenhadas, o que fazia a garrafa aparecer por dentro de si mesma e o líquido
  brigar com o copo na ordenação. `DrinkShaders.GLASS` desenha só a frente e tem Fresnel na
  borda mais um brilho fixo de "estúdio" — é esse brilho que o olho lê como vidro mesmo
  num bar sem reflexo de ambiente. O líquido tem shader próprio, com a cor concentrando no
  fundo e bolhas subindo nas bebidas com gás.

- **Rótulo chapado em garrafa redonda precisa vencer a flecha do arco**. O medalhão e a
  letra ficavam a 2 mm do eixo e as pontas afundavam dentro do vidro. `_chord_gap()`
  calcula o afastamento a partir do raio e da largura da peça.

## Limitações conhecidas

- Os fregueses andam em linha reta (sem navmesh) e atravessam outros fregueses quando se
  cruzam.
- Os sons são sintetizados (placeholders) e as vozes são "blablablá", sem dublagem.
- Há um único turno/cenário, sem progressão entre noites nem save.
- Não há opções de sensibilidade do mouse, volume ou acessibilidade na interface (os
  valores ficam nos `@export` do `PlayerController` e nos buses do `AudioManager`).
- O "espelho" atrás das prateleiras não reflete de verdade: é um vidro escuro que abre a
  parede do fundo. Refletir mesmo pediria uma sonda de reflexão (Forward+) ou uma segunda
  câmera.
- Na GT 210 (modo leve) a iluminação é uma direcional só; o resto é mancha de luz pintada.
  Medido com `--bench` nessa placa (medição instável, varia de corrida para corrida):
  antes desta leva de mudanças, 14–15 FPS; hoje, 8–12 — o preço do mundo lá fora e dos
  shaders de material. Cuidado ao medir: o campo `proc=` do bench **não** é tempo de
  script. Quando a GPU satura, o driver OpenGL trava a thread principal e o tempo aparece
  ali; já vi `proc=418ms` num quadro em que o GDScript não fazia nada. Numa GPU com Vulkan o jogo
  roda em Forward+, com todas as luzes, sombras e resolução cheia.
- No modo leve não dá para tirar o serrilhado a não ser subindo `--escala`, e aí a GT 210
  não dá conta. Em Forward+ o MSAA 4× resolve.

## Próximas melhorias prioritárias

1. Menu de opções: sensibilidade, FOV, volume por bus, qualidade gráfica, reduzir tremida.
2. Navegação com desvio entre fregueses e animação de sentar/levantar mais rica.
3. Áudio real (vozes gravadas, foley) no lugar dos placeholders. A arquitetura já carrega
   por nome.
4. Progressão: mais pontos (com layout de balcão diferente), novos fregueses (o Bebum Filósofo, o
   Turista), bebidas misturadas (receitas com 2 garrafas) e salgados que precisam ser
   fritos.
5. Eventos de caos: jogo na TV (todo mundo pede ao mesmo tempo), queda de energia, fiscal.
6. Visual: partículas (fumaça de cigarro, respingos ao servir, poeira nos feixes de luz),
   sonda de reflexão no Forward+ para o espelho do fundo e luz baked para o modo leve.

## Créditos

- Fontes: [Lilita One](https://fonts.google.com/specimen/Lilita+One) e
  [Fredoka](https://fonts.google.com/specimen/Fredoka), ambas sob a SIL Open Font License
  (licenças em `assets/fonts/`).
- Todo o resto (modelos, shaders, sons e música) é procedural e foi criado para este
  projeto.
