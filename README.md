# NVIDIA Frame Generation su RTX 3000 — Cyberpunk 2077

Integrazione sperimentale di **[dlssg_for_sm86 di sdli1995](https://github.com/sdli1995/dlssg_for_sm86)** per GPU Ampere SM86. Usa il runtime NVIDIA DLSS-G, non FSR. Integrazione, documentazione e prove locali: **nikecatania95/Andr995**.

**Aggiornamento 0.3.5-cp2077.2 — 30 settembre 2026:** risolto nell'installer e nel pacchetto CET il conflitto sul file version.dll. Aggiunti archivi separati, migrazione documentata e diagnosi HAGS/loader/configurazione. Il backend upstream resta 0.3.5: la DLL è già compilata e non è stata modificata o ricompilata qui.

## Scegliere il download

[Releases](https://github.com/Andr995/DLSSFremgenporting3000/releases) · [Nexus](https://www.nexusmods.com/cyberpunk2077/mods/34477)

| Pacchetto | Quando usarlo | File attivi |
| --- | --- | --- |
| CET-ASI (principale) | CET funzionante o un ASI loader compatibile già installato | bin/x64/plugins/dlssg_sm86.asi e dlssg_sm86.ini |
| Standalone (alternativa) | Senza CET e senza un altro version.dll | bin/x64/version.dll e dlssg_sm86.ini |
| Tools | Installazione assistita, backup/ripristino e diagnosi | L'installer sceglie ASI oppure Standalone |

**Installa una sola variante.** Il pacchetto CET-ASI non include CET: installalo dalla [release ufficiale](https://github.com/maximegmd/CyberEngineTweaks/releases) compatibile con la tua versione del gioco. Non mettere i file FG nella sottocartella plugins/cyber_engine_tweaks. Non rinominare la DLL in altri proxy a caso.

## Aggiornamento dalla prima versione, con CET

1. Chiudi Cyberpunk. Conserva fuori dal gioco una copia dei file FG attuali e della configurazione.
2. Se il vecchio pacchetto FG ha sostituito bin/x64/version.dll, ripristina il **version.dll originale di CET**, dal tuo backup oppure reinstallando CET da fonte ufficiale. Non cancellare alla cieca questo file: può appartenere a un'altra mod.
3. Rimuovi dal percorso attivo soltanto il precedente backend FG e il relativo INI; conserva i backup. Il suo SHA-256 è riportato sotto.
4. Estrai **CET-ASI** nella cartella del gioco che contiene bin. I due file FG devono risultare direttamente in **bin/x64/plugins**. Il version.dll di CET deve rimanere in bin/x64.
5. In Windows, verifica **Pianificazione GPU con accelerazione hardware (HAGS)** nelle impostazioni grafiche. Se la abiliti, riavvia Windows.
6. Avvia il gioco, scegli **DLSS Frame Generation**, applica e riavvia il gioco quando richiesto. Inizia da **2×**; mantieni Reflex attivo. Prova 3×/4× solo successivamente.

La verifica dei file del gioco può ripristinare file originali, ma non è una procedura affidabile per rimuovere DLL aggiunte dalle mod. Non ripristinare indiscriminatamente un intero vecchio backup se contiene bridge FSR concorrenti.

## Installazione assistita

Dallo ZIP Tools estratto in una cartella separata:

~~~powershell
.\scripts\install-ampere.ps1 -Package . -GameExecutable 'D:\Giochi\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe'
~~~

Auto preferisce ASI quando trova un loader riconosciuto o la struttura standard di CET. Puoi specificare -Mode ASI o -Mode Standalone. Se CET è danneggiato, riparalo prima: lo script si ferma invece di sovrascrivere un loader sconosciuto.

L'installer verifica hash e revisione, conserva gli originali in .rtx30fg-backup-ID e stampa restore.json. In modalità ASI può spostare il precedente backend root riconosciuto, evitando il doppio caricamento. Conserva il loader CET, ReShade e i runtime originali nvngx_dlss*.dll. Mette in backup i concorrenti nvngx.dll, dlssg_to_fsr3_amd_is_better.dll e i tre componenti RTX40MFG storici. La configurazione distribuita sostituisce quella precedente, conservata nel backup.

~~~powershell
.\scripts\restore-ampere.ps1 -Manifest 'D:\Giochi\Cyberpunk 2077\bin\x64\.rtx30fg-backup-ID\restore.json'
~~~

Il ripristino supporta anche i manifest della prima versione. Verifica tutti gli hash prima di agire, rifiuta percorsi collegati tramite junction/symlink e si ferma se qualcuno ha modificato file da preservare. Le impostazioni del menu grafico si gestiscono separatamente. Per un'installazione manuale, rimuovi solo i file della variante installata e ripristina il tuo backup; non eliminare il loader o le cartelle CET.

## Diagnosi se FG non compare o CET non parte

Nel pacchetto Tools:

~~~powershell
.\scripts\diagnose-ampere.ps1 -GameExecutable 'D:\Giochi\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe' -OutputPath '.\fg-diagnostic.json'
~~~

Negli archivi Nexus lo stesso script è in NVIDIA-FG-RTX3000-Docs/tools. Il rapporto controlla loader, hash, doppio backend, posizione dell'INI, bridge concorrenti, GPU/driver, configurazione HAGS e campioni degli ultimi log. Non cambia registro, driver o impostazioni del gioco. HAGS non rilevabile è riportato come Unknown, non come disattivato; ConfiguredOn non dimostra che un riavvio pendente sia già avvenuto. Il rapporto evita percorsi assoluti personali, salvataggi e log grezzi; rileggilo prima di condividerlo.

Il caso **RTX 3070m con voce FG assente non è ancora risolto con evidenza**. Servono versione del gioco/driver, percorso di caricamento, HAGS dopo riavvio e rapporto della sessione interessata. Questi controlli correggono errori di installazione comuni, non promettono compatibilità universale.

Log con ASI: bin/x64/plugins/dlssg_sm86/logs. Log Standalone: bin/x64/dlssg_sm86/logs. La posizione cambia se modifichi Logging.Directory. Confronta PID e orario della tua sessione: una vecchia valutazione riuscita non certifica una nuova installazione.

## Configurazione e risultati

La configurazione resta Optimized=0, MaxGeneratedFrames=3, massimo 4×, log di livello 3. Il limite INI non imposta il moltiplicatore del menu. Non forzare 6× con questa integrazione Streamline. Il valore del menu salvato dal gioco è DLSS, non DLSSG.

Dati del **24 settembre 2026**, RTX 3060 Ti, Ryzen 5 5600X, driver 616.56, Cyberpunk **2.3**, 1920×1080, DLSS Qualità Transformer, Ray Reconstruction e ray tracing attivi, illuminazione Folle, path tracing disattivato:

| Modalità | FPS medi | Minimo | Massimo |
| --- | ---: | ---: | ---: |
| FG disattivato | 44,96 | 40,19 | 49,24 |
| NVIDIA FG 2× | 77,33 | 60,63 | 88,02 |
| NVIDIA FG 4× | 120,01 | 32,58 | 138,84 |

Una prova separata su 2.31 riporta 114,71 FPS medi a 4×. Sono valori del benchmark del gioco, non misure di latenza, unicità dei frame o 1% low. Non sono nuovi risultati dell'aggiornamento CET. I log corrispondenti attestano valutazioni sul dispositivo SM86 con kernel cubin_sm86. Menu sbloccato e contatore FPS, da soli, non sono una verifica sufficiente.

[Verifica locale](VALIDAZIONE_CYBERPUNK.md) · [Dati benchmark](evidence/cyberpunk-benchmarks.json) · [Guida estesa](TUTORIAL_RTX3000.md) · [Changelog](CHANGELOG.md)

## Preparazione e test

~~~powershell
$pacchetto = .\scripts\prepare-ampere.ps1
.\tests\ampere_deployment_tests.ps1 -Package $pacchetto
.\scripts\package-nexus.ps1 -Package $pacchetto -Variant CET-ASI
.\scripts\package-nexus.ps1 -Package $pacchetto -Variant Standalone
~~~

La preparazione scarica il backend precompilato dalla revisione fissata e verifica SHA-256/dimensione. I test usano file fittizi, da eseguire a gioco chiuso. Per creare localmente ZIP e RAR servono 7-Zip e WinRAR (percorsi configurabili); non servono per installare o usare il backend.

Backend 0.3.5, commit 9621db573e07ed54f50c15bbb585ed9a7bdfac28. SHA-256 identico per version.dll e dlssg_sm86.asi:

~~~text
C3934A09399F022504227C72DF0BF8C0DE55F9A08880DDDDE898C5262CEFA838
~~~

## Provenienza e licenze

Il backend è di **sdli1995**, che dichiara GPLv3 per il proprio codice. I binari e la documentazione consultati non includono tutti i sorgenti necessari a ricostruirlo. Il backend incorpora asset NVIDIA soggetti alle rispettive condizioni; la licenza MIT dell'integrazione non li rilicenzia. Conserviamo integralmente THIRD_PARTY_NOTICES.txt. L'hash identifica il file, non certifica sicurezza o diritti di redistribuzione. La firma è autofirmata dall'autore, non NVIDIA. [Provenienza completa](BACKEND_PROVENANCE.md).

Il codice C++ storico deriva dal progetto RTX40MFG di **Michael Robles / dashdogy**, con [licenza MIT](LICENSE); è separato dalla DLL Ampere e non va caricato insieme. I precedenti sei test C++ e la compilazione MSVC sono documentati in [ADA_RESEARCH.md](ADA_RESEARCH.md) e [AUDIT.md](AUDIT.md). Non presentiamo quel core come implementazione della generazione Ampere.

Grazie a nicklasz e dak002 per il percorso ASI e la verifica riportata su Nexus, e a R92CP, abdyys, protossvoid, VexelleValeux, MRklava0000, Ganzlinger e bigairboi1 per segnalazioni e discussione. Le segnalazioni della comunità sono distinte dalle nostre prove locali.

### Verifica CET e cambio impostazioni
CET 1.37.1 e NVIDIA FG sono stati eseguiti insieme sulla RTX 3060 Ti: 19.296
valutazioni, 172 campioni riusciti e uscita regolare. I due benchmark della
sessione usano impostazioni diverse (119,69 e 45,02 FPS medi) e non costituiscono
un confronto A/B. Riavvia il gioco dopo aver cambiato impostazioni grafiche e
controlla i log della nuova sessione. Non è stata determinata la causa del secondo
risultato basso; il dettaglio è conservato nel rapporto di verifica CET.
