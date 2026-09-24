# NVIDIA Frame Generation su RTX 3000 — Cyberpunk 2077

Pacchetto di installazione per usare **[dlssg_for_sm86 di sdli1995](https://github.com/sdli1995/dlssg_for_sm86)** con NVIDIA DLSS Frame Generation sulle GPU Ampere SM 8.6. La verifica locale è stata eseguita su **RTX 3060 Ti** in Cyberpunk 2077. La generazione usa il runtime NVIDIA DLSS-G; FSR non è il backend di questo pacchetto.

**La DLL Ampere è già compilata.** La release contiene `version.dll`, configurazione e script di installazione/ripristino. Non servono Visual Studio o CUDA Toolkit. La DLL è distribuita dall'autore del backend, non è una compilazione del vecchio core C++ di questo repository.

> Mod sperimentale della comunità. Le prove confermano l'esecuzione su RTX 3060 Ti; non garantiscono compatibilità con ogni RTX 3000, gioco o driver, né supporto ufficiale NVIDIA.

## Download

Scarica **`NVIDIA-FG-RTX3000-Cyberpunk-0.3.5.zip`** dalla [pagina Releases](https://github.com/Andr995/DLSSFremgenporting3000/releases) ed estrailo in una cartella dedicata. Gli archivi automatici “Source code” richiedono invece il passaggio di preparazione descritto sotto. Se il repository è privato, serve un account autorizzato anche per scaricare le release.

## Installazione della release già compilata

1. **Chiudi completamente Cyberpunk 2077.**
2. Individua `Cyberpunk2077.exe`, normalmente in `Cyberpunk 2077\bin\x64`. La cartella di GOG Galaxy contiene il launcher e può essere diversa.
3. Apri PowerShell nella cartella estratta ed esegui, sostituendo il percorso del gioco:

   ```powershell
   .\scripts\install-ampere.ps1 -Package . -GameExecutable 'D:\Giochi\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe'
   ```

4. Conserva il percorso `restore.json` stampato: serve per annullare questa installazione.
5. Avvia il gioco e seleziona **Impostazioni → Grafica → Generazione fotogrammi → DLSS Frame Generation**. Applica, esci normalmente e **riavvia il gioco** quando richiesto.
6. Inizia con **2×**, mantieni NVIDIA Reflex attivo ed esegui il benchmark. Poi puoi provare **3× o 4×**.

Lo script verifica revisione e hash prima di installare `version.dll` e `dlssg_sm86.ini`. Sposta in `.rtx30fg-backup-<id>` i file concorrenti riconosciuti: un precedente `version.dll`/INI, `nvngx.dll`, `dlssg_to_fsr3_amd_is_better.dll` e i tre componenti `RTX40MFG`. Conserva ReShade e i runtime originali `nvngx_dlss*.dll`. Gestisce soltanto Cyberpunk; altre mod che usano questi proxy richiedono una verifica separata.

Se la cartella del gioco richiede privilegi amministrativi, apri PowerShell come amministratore. Se gli script scaricati sono bloccati, dopo aver verificato origine e hash puoi eseguire il solo comando in una sessione temporanea:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-ampere.ps1 -Package . -GameExecutable 'D:\Giochi\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe'
```

### Installazione manuale

A gioco chiuso, conserva una copia degli originali e sposta fuori da `bin\x64` le mod concorrenti elencate sopra. Copia **`version.dll` e `dlssg_sm86.ini`** dalla release accanto all'eseguibile, poi seleziona DLSS Frame Generation e riavvia. Questa procedura richiede anche un ripristino manuale; lo script è preferibile perché registra e verifica il backup.

## Risultati verificati

RTX 3060 Ti, Ryzen 5 5600X, driver 616.56, Cyberpunk **2.3**, 1920×1080, DLSS Qualità con modello Transformer, Ray Reconstruction e ray tracing attivi, illuminazione Folle, path tracing disattivato. Le impostazioni riportate dai tre rapporti coincidono, salvo FG e misure del benchmark.

| Modalità | FPS medi | Minimo | Massimo |
| --- | ---: | ---: | ---: |
| FG disattivato | 44,96 | 40,19 | 49,24 |
| NVIDIA DLSS FG 2× | 77,33 | 60,63 | 88,02 |
| NVIDIA DLSS FG 4× | 120,01 | 32,58 | 138,84 |

Guadagno medio: circa **+72% a 2×** e **+167% a 4×**. Il minimo della prova 4× mostra un calo: la media non certifica fluidità costante. Sono FPS riportati dal gioco, non misure indipendenti di latenza o unicità dei frame presentati; il minimo non equivale al valore 1% low.

I log della sessione corrispondente registrano creazione riuscita della feature DLSS-G, kernel `cubin_sm86`, valutazioni riuscite e zero errori di lancio nei campioni. Una prova successiva su **2.31** riporta 114,71 FPS medi a 4× ed è documentata separatamente perché cambia la versione del gioco.

Dettagli e dati: [verifica locale](VALIDAZIONE_CYBERPUNK.md), [rapporti benchmark](evidence/cyberpunk-benchmarks.json), [riepilogo dei log](evidence/cyberpunk-backend-summary.json).

## Configurazione e problemi comuni

- `Optimized=0`: percorso numerico stock del backend Ampere, usato nelle prove iniziali.
- `MaxGeneratedFrames=3`: limite richiesto fino a tre frame aggiuntivi, cioè 4×. Seleziona il moltiplicatore nel gioco e verifica quello effettivo nei log.
- Log: `bin\x64\dlssg_sm86\logs\loader_<PID>.jsonl` e `backend_<PID>.jsonl`.
- Il menu sbloccato o una riga `install` non provano l'esecuzione. Cerca anche una creazione riuscita della feature ID 11 e successive righe `evaluate` riuscite sul dispositivo SM86.
- Se il benchmark indica **“Generazione fotogrammi: No”**, seleziona DLSS dal menu, applica ed esci normalmente prima del riavvio. Il valore salvato da questa versione del gioco è `DLSS`, non `DLSSG`.
- Per questa integrazione usa **2×–4×**. Non forzare 6× con il vecchio plugin Streamline del gioco.

Guida estesa: [TUTORIAL_RTX3000.md](TUTORIAL_RTX3000.md).

## Ripristino

Chiudi il gioco, poi dalla cartella della release esegui usando il manifest stampato dalla tua installazione:

```powershell
.\scripts\restore-ampere.ps1 -Manifest 'D:\Giochi\Cyberpunk 2077\bin\x64\.rtx30fg-backup-INSERISCI_ID\restore.json'
```

Il ripristino controlla gli hash e conserva anche i file rimossi. Se hai modificato l'INI o il backup, si ferma per non sovrascrivere i cambiamenti. Le impostazioni grafiche si gestiscono separatamente dal menu del gioco.

## Preparare il pacchetto dal repository

Apri PowerShell nella cartella clonata o estratta dai sorgenti:

```powershell
$pacchetto = .\scripts\prepare-ampere.ps1
.\tests\ampere_deployment_tests.ps1 -Package $pacchetto
.\scripts\install-ampere.ps1 -Package $pacchetto -GameExecutable 'D:\Giochi\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe'
```

`prepare-ampere.ps1` scarica la **DLL già compilata** dalla revisione fissata dell'autore, verifica dimensione e SHA-256 e prepara una nuova directory in `dist`. Richiede Internet al primo download, non un compilatore. I test usano file fittizi e vanno eseguiti a gioco chiuso.

Backend **0.3.5**, commit `9621db573e07ed54f50c15bbb585ed9a7bdfac28`. SHA-256 di `version.dll`:

```text
C3934A09399F022504227C72DF0BF8C0DE55F9A08880DDDDE898C5262CEFA838
```

## Codice C++ e correzioni

Il core C++ Ada storico è separato e non va caricato insieme al backend Ampere. Le tre correzioni di revisione riguardano durata della DLL, percorsi condivisi fra core e interfaccia e rifiuto della telemetria scaduta o di altre sessioni. I sei test locali sono passati; il core completo richiede MSVC/MASM e non è la DLL Ampere della release.

Istruzioni per sviluppatori: [ADA_RESEARCH.md](ADA_RESEARCH.md). Revisione tecnica: [AUDIT.md](AUDIT.md).

## Provenienza e licenze

Il codice originario conserva la [licenza MIT](LICENSE). Il backend esterno è di **sdli1995**, che dichiara GPLv3 per il proprio codice. Runtime NVIDIA, modelli e kernel di terze parti mantengono le rispettive condizioni e non sono rilicenziati dalla MIT di questo repository. Il pacchetto conserva integralmente `THIRD_PARTY_NOTICES.txt` dell'autore e [BACKEND_PROVENANCE.md](BACKEND_PROVENANCE.md).

La revisione upstream consultata pubblica binari e documentazione, ma non tutti i sorgenti necessari a ricostruire la DLL. L'hash identifica il file e non equivale a un audit completo. La firma del backend è autofirmata dall'autore, non è una firma NVIDIA.
