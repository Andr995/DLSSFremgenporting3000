# NVIDIA Frame Generation su RTX 3060 Ti — Cyberpunk 2077

Aggiornato il 24 settembre 2026.

Il percorso Ampere usa ora il backend esterno **dlssg_for_sm86 0.3.5**, con runtime NVIDIA DLSS-G 310.9.1 incorporato. Non usa FSR per generare i frame. Il vecchio core Ada del repository rimane un progetto separato e non deve essere caricato insieme a questo backend.

La precedente conclusione che mancasse una strada disponibile per RTX 30 era incompleta: il supporto ufficiale NVIDIA e le implementazioni sperimentali della comunità sono due questioni diverse. [Il progetto dell'autore](https://github.com/sdli1995/dlssg_for_sm86) pubblica un backend con kernel per SM86. Il materiale consultato contiene binari e documentazione, non tutti i sorgenti necessari a ricostruirli: questa integrazione fissa e verifica il pacchetto dell'autore, senza presentarlo come codice scritto qui.

## Installazione locale

La cartella del gioco individuata tramite il registro GOG è:

```text
H:\gog\Cyberpunk 2077\Cyberpunk 2077\bin\x64
```

`C:\Program Files (x86)\GOG Galaxy` contiene il launcher, non questa installazione del gioco.

Sono stati installati `version.dll` e `dlssg_sm86.ini`. I seguenti componenti precedenti sono stati spostati in un backup: il vecchio `version.dll`, `nvngx.dll`, `dlssg_to_fsr3_amd_is_better.dll`, `RTX40MFG.asi`, `RTX40MFGCore.dll` e `RTX40MFG-UI.addon64`. Il log della vecchia mod confermava esplicitamente la sostituzione di DLSS-G con FSR 3.

Il backup è:

```text
H:\gog\Cyberpunk 2077\Cyberpunk 2077\bin\x64\.rtx30fg-backup-317a22a77b06482d90073efed239255c
```

ReShade, salvataggi, runtime originali del gioco e driver non vengono sostituiti dall'installatore.

## Impostazioni per la prova

1. Avvia Cyberpunk normalmente da GOG.
2. In **Impostazioni → Grafica → Generazione fotogrammi**, seleziona **DLSS Frame Generation**. Applica, esci normalmente e **riavvia il gioco** quando richiesto; poi inizia da **2×**.
3. Mantieni NVIDIA Reflex attivo. FSR e XeSS Frame Generation devono essere disattivati. Il valore salvato dal menu è `FrameGeneration=DLSS`, non `DLSSG`.
4. Esegui il benchmark integrato. Dopo la prova 2× puoi verificare separatamente 3× e 4×.

Lo script installa il backend; la selezione FG viene effettuata nel menu del gioco. Nella prova locale DLSS Super Resolution era in modalità Qualità. Le impostazioni precedenti di questa macchina sono salvate byte per byte nel progetto locale, con percorso in `build-tests/cyberpunk-settings-restore.txt`; questo backup personale non viene distribuito nella release.

L'INI usa `Optimized=0` per iniziare con il percorso numerico stock, `MaxGeneratedFrames=3` come limite fino a 4×, e log di livello 3 per la verifica. Il limite nell'INI non imposta da solo il moltiplicatore del gioco. `Optimized=0` lascia attivo l'adattamento dei kernel ad Ampere. [Documentazione del backend](https://github.com/sdli1995/dlssg_for_sm86/blob/main/docs/INSTALL.en.md).

Questa installazione contiene Streamline 2.7.1 e il menu del gioco espone 2×/3×/4×. Non vengono forzati 6× né modificate le allocazioni interne del plugin.

## Verificare che sia realmente NVIDIA FG

I log del backend si trovano sotto:

```text
H:\gog\Cyberpunk 2077\Cyberpunk 2077\bin\x64\dlssg_sm86\logs
```

Controlla il PID della sessione appena eseguita. Il caricamento del proxy, il menu sbloccato o il solo contatore FPS non bastano. Occorrono una creazione riuscita della feature DLSS-G e successive valutazioni riuscite dei kernel sul dispositivo SM86. Per qualità visiva, fluidità e stabilità serve anche osservare scene in movimento.

Il resoconto locale delle prove è in `VALIDAZIONE_CYBERPUNK.md`. La disponibilità ufficiale NVIDIA continua a non includere RTX 30: questa resta una mod sperimentale, non un'estensione ufficiale del supporto. [Hardware supportato da NVIDIA](https://www.nvidia.com/en-eu/geforce/technologies/dlss/).

## Ricreare il pacchetto

Dalla cartella del repository:

```powershell
$pacchetto = .\scripts\prepare-ampere.ps1
.\tests\ampere_deployment_tests.ps1 -Package $pacchetto
```

Lo script scarica solo i file della revisione fissata se non sono già nella cache, ne verifica dimensione e SHA-256 e crea una nuova directory in `dist`. Non richiede la compilazione del vecchio core C++. I test di installazione usano una cartella fittizia, verificando backup, isolamento degli altri file, rifiuto dei file alterati e ripristino esatto; eseguili a gioco chiuso.

Per installare il pacchetto su questa copia di Cyberpunk, a gioco chiuso:

```powershell
.\scripts\install-ampere.ps1 -Package $pacchetto -GameExecutable 'H:\gog\Cyberpunk 2077\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe'
```

Non ripetere l'installazione già effettuata soltanto per provare il gioco. Ogni installazione crea un proprio backup e stampa il manifest di ripristino.

Revisione upstream fissata: `9621db573e07ed54f50c15bbb585ed9a7bdfac28`.

SHA-256 di `version.dll`:

```text
C3934A09399F022504227C72DF0BF8C0DE55F9A08880DDDDE898C5262CEFA838
```

Il controllo hash identifica il file scaricato; non equivale a una revisione completa del codice o a una certificazione. La firma dell'autore è autofirmata e non va confusa con una firma NVIDIA. Le attribuzioni upstream sono conservate nel pacchetto.

## Ripristino

Chiudi il gioco, poi dalla cartella del progetto:

```powershell
.\scripts\restore-ampere.ps1 -Manifest 'H:\gog\Cyberpunk 2077\Cyberpunk 2077\bin\x64\.rtx30fg-backup-317a22a77b06482d90073efed239255c\restore.json'
```

Il ripristino verifica tutti gli hash prima di spostare i file e conserva anche il backend rimosso nel backup. Se hai modificato l'INI dopo l'installazione, si ferma per non sovrascrivere le tue modifiche. Ripristina separatamente le impostazioni grafiche dalla copia indicata in `build-tests/cyberpunk-settings-restore.txt`, sempre a gioco chiuso.

## Stato del vecchio codice C++

Le tre correzioni precedenti — durata della DLL, percorsi condivisi, rifiuto della telemetria obsoleta — rimangono nel ramo di ricerca Ada. I relativi sei test sono passati. Le routine CPU FP8 non sono il backend impiegato da questa installazione Ampere e non vengono presentate come emulazione GPU funzionante.
