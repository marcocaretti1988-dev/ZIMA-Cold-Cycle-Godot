# ЗИМА · Cold Cycle — versione Godot

ЗАТО-42, 12 febbraio 1991, ore 23:40. Dmitri «Volk» Voronin si risveglia in una città
sovietica sepolta dalla neve. La neve ricorda tutto. Ogni passo resta.

Riscrittura in **Godot 4.7** (solo GDScript) del gioco HTML/Three.js
([repository originale](https://github.com/marcocaretti1988-dev/-L-inverno-lungo)).
Un solo progetto, due profili grafici.

## Come provarlo
1. Scarica lo ZIP da GitHub (Code → Download ZIP) e scompattalo.
2. Apri Godot 4.7 → **Importa** → scegli `project.godot`.
3. Premi **Play** (F5).

Se sul Mac lo schermo resta nero o va a scatti: in alto a destra in Godot cambia
il renderer da *Forward+* a **Compatibilità** e riavvia.

## Profili grafici
| | PC (PIENA) | Mobile (LEGGERA) |
|---|---|---|
| Renderer | Forward+ | Mobile / Compatibilità |
| Ombre | 4 livelli, morbide, anche da fuoco e torcia | solo il sole (spente su telefono e web) |
| Extra | SSAO, MSAA, rilievi e cristalli sulla neve | — |
| Neve che cade | 3200 fiocchi | 900 fiocchi |
| Impronte ricordate | 6000 | 2200 |
| Comandi | tastiera e mouse | joystick e pulsanti touch |

Il profilo si sceglie da solo all'avvio; il pulsante **GRAFICA** nel menu lo forza.

## Comandi
WASD/frecce muovi · SHIFT corri · E/SPAZIO esamina · T torcia · I zaino · H aiuto ·
Z/X ruota la camera · rotella zoom · ESC pausa.
Su telefono: joystick a sinistra, pulsanti a destra.

## Stato
- [x] **Task 1** — motore (camera isometrica, neve e impronte, sopravvivenza, testi, zaino,
  aiuti progressivi, vuoti di memoria, salvataggio, due profili) + **Capitolo I · Il Cortile**
- [ ] Task 2 — Capitolo II · La fermata (sentinelle, inseguitore, cavi, Nina)
- [ ] Task 3 — Capitolo III · Il posto di blocco (soldati, stealth, Semënov)
- [ ] Capitoli IV–X

## Struttura
- `scripts/main.gd` — motore · `scripts/chapter.gd` — base dei capitoli
- `scripts/chapters/chapter1.gd` — Capitolo I
- `scripts/batch.gd`, `props.gd` — palazzi e oggetti sovietici
- `scripts/snow.gd` — neve, impronte, nevicata · `scripts/hud.gd` — interfaccia
- `shaders/` — neve, impronte, effetto videocassetta
- `docs/` — bibbia del gioco e trame dei dieci capitoli

## Prova automatica
`ZIMA_TEST=1 godot --headless --path .` gioca da solo tutto il Capitolo I e stampa `TEST OK`.
