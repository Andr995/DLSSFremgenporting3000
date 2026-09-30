# Verifica locale — Cyberpunk 2077 / RTX 3060 Ti

Data: 24 settembre 2026. **NVIDIA FG verificato nei rapporti del gioco e nei log del backend su RTX 3060 Ti, a 2× e 4×.** Il primo benchmark osservato sullo schermo era senza FG; i successivi rapporti salvati documentano l'attivazione.

- GPU rilevata tramite driver CUDA: NVIDIA GeForce RTX 3060 Ti, SM 8.6.
- Gioco: Cyberpunk 2077, menu versione 2.3; eseguibile `3.0.5276805`.
- Directory: `H:\gog\Cyberpunk 2077\Cyberpunk 2077\bin\x64`.
- Plugin su disco: Streamline 2.7.1. Sono presenti anche override NVIDIA OTA caricati dal gioco.
- Backend: `dlssg_for_sm86` 0.3.5, commit `9621db573e07ed54f50c15bbb585ed9a7bdfac28`.
- Runtime selezionato dal loader: NVIDIA DLSS-G 310.9.1, SHA-256 `ff6e90eb78b827927dff5b4ecc6b1c870c2e9bca29ed9f48c7d348cc9e170b82`.
- Configurazione del pacchetto: kernel stock `Optimized=0`, `MaxGeneratedFrames=3`; selezione NVIDIA FG dal menu dopo il riavvio. Il valore corretto salvato dal gioco è `FrameGeneration=DLSS`; il tentativo iniziale con `DLSSG` non era valido.
- Test dell'installatore: superati backup, conservazione degli altri file, rifiuto di file/manifests alterati e ripristino esatto.

Il primo avvio, PID 24464, ha caricato correttamente il backend (`backend_install.status=0`) e si è chiuso normalmente senza eseguire FG (`evaluates=0`). Non costituisce una prova di frame generati.

Il secondo avvio, PID 6920, ha riportato `FrameGeneration.Available=1`, `NeedsUpdatedDriver=0`, `FeatureInitResult=1`, `DLSSG.MultiFrameCountMax=3`, ma non ha eseguito FG. Le prove riuscite successive sono distinte sotto.

Nessun risultato di FPS o qualità visiva viene dedotto dalla sola disponibilità della feature.

## Benchmark osservato sullo schermo

Sessione PID 6920, risultati letti direttamente dalla schermata del gioco:

| Misura | Risultato |
| --- | --- |
| FPS medi | 44,96 |
| FPS minimi | 40,19 |
| FPS massimi | 49,24 |
| Durata | 64,24 secondi |
| Fotogrammi | 2888 |
| Risoluzione | 1920 × 1080 |
| DLSS SR | Qualità, modello Transformer |
| Ray Reconstruction | Attivo |
| Ray tracing | Attivo; illuminazione Folle |
| Path tracing | Disattivato |
| Generazione fotogrammi | **No** |

Il log backend della stessa sessione, al momento della lettura, non contiene eventi `evaluate` né creazioni della feature DLSS-G (ID 11). L'unica creazione NGX riuscita ha ID 13 e non dimostra FG. Le tre righe `kernel_create` con `status=-14` sono sonde non instradate (`routed=false`, `image=original`), non esecuzioni riuscite dei kernel Ampere.

Questo benchmark è una base di confronto senza FG, non una misura dei benefici della mod. Il minimo riportato non è un valore 1% low, e una schermata dei risultati non permette di valutare ghosting o latenza di input.

## Prove NVIDIA riuscite, lette dai rapporti salvati

I file `summary.json` prodotti dal gioco sono riportati in [evidence/cyberpunk-benchmarks.json](evidence/cyberpunk-benchmarks.json), con hash dei file di origine. Questi risultati sono stati recuperati dai rapporti su disco; non si presume di aver osservato ogni prova sullo schermo.

| Versione | Prova del 24 settembre | FG | Medi | Minimi | Massimi |
| --- | --- | --- | ---: | ---: | ---: |
| 2.3 | 14:08:54 | No | 44,96 | 40,19 | 49,24 |
| 2.3 | 14:32:45 | NVIDIA 2× | 77,33 | 60,63 | 88,02 |
| 2.3 | 14:34:27 | NVIDIA 4× | 120,01 | 32,58 | 138,84 |
| 2.31 | 18:21:14 | NVIDIA 4× | 114,71 | 64,25 | 138,72 |

Per le tre prove 2.3 tutti i campi dei rapporti coincidono, tranne risultati, durata, numero di frame e selezione FG. I rapporti NVIDIA indicano `DLSSFrameGenEnabled=true`, `FSR3FrameGenEnabled=false`, con rispettivamente uno e tre frame da generare. Il confronto con la base dà +72,0% e +166,9% di FPS medi. La prova 2.31 ha le stesse impostazioni grafiche riportate ma cambia la versione del gioco: non è una ripetizione strettamente identica.

Il backend della sessione PID 29520, che comprende le prove NVIDIA delle 14:32 e 14:34, registra:

- Creazione riuscita della feature ID 11 (`status=0x1`).
- NVIDIA DLSS-G 310.9.1 su GPU SM86, immagine `cubin_sm86`, percorso stock.
- 12.516 valutazioni totali; campioni con stato riuscito, zero errori di lancio e nessun fallback di immagine.
- Uscita regolare, zero fallimenti di creazione.

Le sessioni successive PID 1972 e 28968 riportano rispettivamente 16.323 e 2.514 valutazioni, creazione FG riuscita e uscita regolare. Il [riepilogo dei log](evidence/cyberpunk-backend-summary.json) conserva contatori e hash, senza indirizzi di memoria o percorsi personali.

Due altre prove del giorno sono escluse dal confronto: quella delle 18:25 usa path tracing e un diverso preset SR; quella delle 18:30 indica FSR FG attivo e DLSS FG disattivato. Quest'ultima non è una prova del backend NVIDIA.

## Valutazione

L'attivazione e l'esecuzione NVIDIA su questa RTX 3060 Ti sono confermate. Il 2× porta la media a circa 77 FPS; il 4× arriva a circa 120 FPS nella prova 2.3, ma registra un minimo inferiore alla base. Non si deducono da questi numeri assenza di stutter, frame tutti unici o una latenza equivalente a rendering nativo a 120 FPS. Servono analisi del frame pacing, osservazione in movimento e sessioni più lunghe per giudicare questi aspetti.

## Verifica CET/ASI — 30 settembre 2026

La sessione PID 6884 ha caricato insieme CET 1.37.1 e il backend rinominato
dlssg_sm86.asi, con INI direttamente in bin/x64/plugins. Il loader originale
version.dll di CET è rimasto nella cartella bin/x64. Sono stati osservati
l'overlay iniziale CET e la sua inizializzazione D3D12 riuscita.

Il log completo della sessione attesta una creazione DLSS-G riuscita, HAGS
effettivamente attivo, SM86/cubin_sm86, 19.296 valutazioni totali e 172 campioni
tutti con status=1 e tre frame generati richiesti. I contatori di errori di lancio
e fallback nei campioni sono zero; l'uscita è regolare.

Durante la sessione l'utente ha eseguito due benchmark: 119,69 e 45,02 FPS medi.
Fra i due cambiano modalità DLSS, ray tracing, path tracing e Ray Reconstruction:
non sono una coppia A/B e non dimostrano un miglioramento o una regressione
causati da CET. Il secondo risultato basso resta documentato; non è stato
eseguito un confronto controllato dopo riavvio per determinarne la causa.
Riavviare il gioco dopo cambi delle impostazioni grafiche e verificare la
sessione corrente evita di scambiare una vecchia esecuzione riuscita per una
conferma della nuova configurazione.

[Dati e hash della verifica CET](evidence/cyberpunk-cet-asi-validation.json).
Questa prova conferma inizializzazione CET ed esecuzione FG nella stessa sessione,
non ogni mod dipendente da CET, ogni preset o ogni RTX 30. Il caso RTX 3070m
segnalato su Nexus resta non verificato.

Al termine, i file aggiunti per la prova CET sono stati conservati nel backup
locale e la precedente installazione locale del backend è stata ripristinata.
I pacchetti cp2077.2 mantengono la DLL upstream invariata e cambiano il metodo
di distribuzione/installazione.
