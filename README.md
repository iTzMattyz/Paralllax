# PARALLAX

Un'escape room punta-e-clicca in **due livelli**, interamente in italiano,
realizzata con **Godot 4.6** (GDScript puro, niente addon).

Una notte di Perseidi, uno studio chiuso a chiave, una fotografia strappata.
Le stanze ricordano — date, colori, stelle — e per aprire la porta bisogna
ricomporre il ricordo.

- 2 stanze esplorabili, 2 livelli, enigmi concatenati (diario, telescopio,
  codici, frammenti di fotografia)
- cutscene narrative di intro e fine livello
- grafiche originali dipinte a mano, font 29LT Makina, musica e suoni

## Come si gioca

**Da Godot (consigliato):**

1. Scarica Godot 4.x (versione Standard) da https://godotengine.org/download
   — è un singolo eseguibile portable, niente da installare.
2. Apri il Project Manager → **Importa** → seleziona `project.godot` di questa
   cartella → **Importa e modifica**.
3. Premi **F5** per giocare.

**Comandi:** solo mouse. Clic sugli oggetti per esaminarli e interagire,
`ESC` per chiudere finestre/overlay o aprire il menu di pausa. Un clic salta
le cutscene.

> ⚠️ **Spoiler:** `PROGRESS.md` documenta lo sviluppo e contiene le
> **soluzioni complete** dei due livelli. Se vuoi giocare, non leggerlo.

## Struttura del progetto

```
project.godot          configurazione (scena principale, risoluzione 1280×720)
scenes/MainMenu.tscn   schermata iniziale
scenes/Intro.tscn      cutscene introduttiva
scenes/Game.tscn       il gioco (la UI è costruita in codice)
scripts/Game.gd        tutta la logica di gioco: stanze, enigmi, cutscene
scripts/Intro.gd       intro narrativa (stelle in parallasse, foto strappata)
scripts/AudioManager.gd autoload per musica e suoni
assets/parallax/       grafiche, font, audio del gioco
PROGRESS.md            diario di sviluppo (CONTIENE LE SOLUZIONI)
```

## Crediti

- **Codice e sviluppo:** Mattia Prugnoli
- **Grafiche, direzione artistica e testi:** [NOME ARTISTA]
- **Font:** 29LT Makina

## Licenza

**© 2026 — Tutti i diritti riservati.** Questo repository è pubblicato solo
per consultazione e valutazione: **non** è consentito ridistribuire il gioco
né riutilizzare codice, grafiche o altri contenuti senza autorizzazione
scritta. Dettagli in [LICENSE](LICENSE).
