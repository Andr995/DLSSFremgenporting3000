# Guida RTX 3000 / Cyberpunk 2077
Aggiornata il 30 settembre 2026, integrazione 0.3.5-cp2077.2.

## Prerequisiti e scelta
Windows x64, Cyberpunk 2077 con NVIDIA DLSS Frame Generation, driver NVIDIA compatibile e GPU Ampere SM86. La prova locale riguarda RTX 3060 Ti; la segnalazione RTX 3070m non è stata riprodotta. Non è supporto ufficiale NVIDIA.

Con CET usa il pacchetto CET-ASI, dopo aver installato una versione di [CET](https://github.com/maximegmd/CyberEngineTweaks/releases) compatibile con il gioco. Il pacchetto non include CET. Senza CET/loader e senza altri version.dll usa Standalone. Non installare entrambi.

## Cartella corretta
Individua Cyberpunk2077.exe in bin/x64 all'interno del gioco, non nella cartella del launcher GOG Galaxy. Estrai l'archivio Nexus nella cartella del gioco contenente bin.

CET-ASI deve produrre:
- bin/x64/version.dll: loader originale di CET.
- bin/x64/plugins/cyber_engine_tweaks.asi: componente CET.
- bin/x64/plugins/dlssg_sm86.asi: backend FG.
- bin/x64/plugins/dlssg_sm86.ini: configurazione FG.

I due file FG vanno direttamente in plugins, **non** dentro plugins/cyber_engine_tweaks. Standalone colloca invece version.dll e dlssg_sm86.ini in bin/x64 ed è incompatibile con un secondo proxy che usa quel nome.

## Migrare da cp2077.1
Chiudi il gioco e conserva una copia dei file attuali fuori dalla cartella attiva. Se FG ha sovrascritto il version.dll di CET, ripristina solo il loader originale di CET o reinstalla CET da fonte ufficiale. Sposta il precedente INI FG fuori da bin/x64 e installa CET-ASI.

Identifica il backend FG dal suo SHA-256, senza cancellare DLL in base al solo nome:
C3934A09399F022504227C72DF0BF8C0DE55F9A08880DDDDE898C5262CEFA838

Non ripristinare insieme un vecchio bridge FSR: nvngx.dll, dlssg_to_fsr3_amd_is_better.dll e i componenti RTX40MFG possono competere per lo stesso percorso NGX. Conserva i runtime originali nvngx_dlss*.dll e il loader di CET. La verifica dei file tramite launcher può lasciare presenti le DLL aggiunte dalle mod.

## Installazione assistita e ripristino
Dal pacchetto Tools, estratto fuori dal gioco:

~~~powershell
.\scripts\install-ampere.ps1 -Package . -GameExecutable 'D:\Giochi\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe'
~~~

Auto sceglie ASI se riconosce un loader o la struttura CET; altrimenti Standalone. I conflitti non identificabili bloccano l'installazione. Il backup è registrato nel restore.json stampato. Gli INI precedenti vengono conservati, ma l'installazione applica la configurazione distribuita. Se la cartella è protetta può servire PowerShell amministratore. Controlla provenienza e hash prima di sbloccare script scaricati.

~~~powershell
.\scripts\restore-ampere.ps1 -Manifest 'D:\Giochi\Cyberpunk 2077\bin\x64\.rtx30fg-backup-ID\restore.json'
~~~

Chiudi il gioco prima di installare o ripristinare. Se hai modificato file dopo l'installazione, il ripristino si ferma: conserva quelle modifiche prima di intervenire. Non cancellare l'intera cartella plugins o i file CET. Nell'installazione manuale, elimina solo i due file FG della variante scelta e ripristina gli eventuali originali dal tuo backup.

## HAGS, menu e prova
1. In Windows apri Impostazioni → Sistema → Schermo → Grafica e le impostazioni grafiche predefinite/avanzate della tua versione di Windows.
2. Verifica Pianificazione GPU con accelerazione hardware (HAGS). Se la abiliti, riavvia Windows.
3. Nel gioco seleziona Generazione fotogrammi → DLSS Frame Generation, applica ed esci normalmente; riavvia il gioco se richiesto.
4. Inizia da 2× e mantieni NVIDIA Reflex attivo. Disattiva FSR/XeSS Frame Generation e altri bridge concorrenti.
5. Esegui il benchmark, annotando versione gioco/driver, GPU, risoluzione, DLSS, ray tracing, moltiplicatore, media e minimi. Confronta FG off/on con identiche impostazioni e sessioni separate se necessario.

La prima configurazione usa Optimized=0 e MaxGeneratedFrames=3, cioè fino a 4×; il moltiplicatore effettivo si seleziona nel gioco. Non forzare 6×. FrameGeneration=DLSS è il valore salvato dal menu; non impostare DLSSG a mano.

## Diagnosi
Nel pacchetto Tools esegui scripts/diagnose-ampere.ps1; nei pacchetti Nexus usa:

~~~powershell
.\NVIDIA-FG-RTX3000-Docs\tools\diagnose-ampere.ps1 -GameExecutable 'D:\Giochi\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe' -OutputPath '.\fg-diagnostic.json'
~~~

Il rapporto è in sola lettura rispetto al gioco/registro. ConfiguredOn descrive la configurazione HAGS, non conferma il riavvio; Unknown significa che non è stato possibile determinarla. Per assistenza includi il rapporto dopo averlo letto, versione del gioco/driver, GPU esatta e passaggi per riprodurre il problema.

Log ASI: bin/x64/plugins/dlssg_sm86/logs. Log Standalone: bin/x64/dlssg_sm86/logs. Il percorso relativo Logging.Directory si riferisce alla cartella del backend/INI. Controlla PID e orario della sessione appena provata.

Una voce di menu sbloccata non dimostra esecuzione. Nei log servono creazione riuscita della feature DLSS-G e valutazioni successive riuscite su SM86. I campioni non misurano direttamente latenza, frame unici o stabilità di tutte le scene. Il caso RTX 3070m richiede ancora dati dell'utente; HAGS è un controllo suggerito, non una soluzione confermata per quella scheda.

## Dati e attribuzioni
Le prove del 24 settembre sono conservate in VALIDAZIONE_CYBERPUNK.md ed evidence; non sono nuove misure dell'aggiornamento CET. [README](../README_NVIDIA_FG_RTX3000.txt) e [CHANGELOG](CHANGELOG.md) distinguono le correzioni dai limiti ancora aperti.

Integrazione: nikecatania95/Andr995. Backend: sdli1995/dlssg_for_sm86 0.3.5. Runtime, modelli e kernel NVIDIA conservano le rispettive condizioni. Vedi BACKEND_PROVENANCE.md e THIRD_PARTY_NOTICES.txt.


### Verifica CET e cambio impostazioni
CET 1.37.1 e NVIDIA FG sono stati eseguiti insieme sulla RTX 3060 Ti: 19.296
valutazioni, 172 campioni riusciti e uscita regolare. I due benchmark della
sessione usano impostazioni diverse (119,69 e 45,02 FPS medi) e non costituiscono
un confronto A/B. Riavvia il gioco dopo aver cambiato impostazioni grafiche e
controlla i log della nuova sessione. Non è stata determinata la causa del secondo
risultato basso; il dettaglio è conservato nel rapporto di verifica CET.
