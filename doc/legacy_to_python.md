# Documento operativo per AI — Migrazione dei comandi legacy in operation Python native

## 1. Scopo di questo documento

Questo documento serve come handoff completo per una nuova chat in cui verrà fornito **solo il codice dell'applicazione**.

L'obiettivo della prossima fase è modificare l'applicazione in modo che i comandi oggi considerati **legacy** vengano eseguiti come le altre operation non legacy, cioè:

- come **operation normali del sistema**
- con **handler Python nativi**
- senza dipendere da `atm_ser`
- senza dipendere da Octave per l'esecuzione dei comandi legacy

Questo documento deve permettere a una AI di:
- capire cos'è l'app
- capire l'architettura attuale
- capire come il ramo legacy è integrato oggi
- sapere qual è il target finale
- sapere quali parti mantenere e quali rimuovere
- sapere in che ordine procedere

---

## 2. Cos'è l'applicazione

L'applicazione è un server HTTP asincrono basato su Flask + RQ + Redis.

Espone un'API a job (`/jobs`) che:
- riceve richieste JSON
- valida operation e parametri
- crea job asincroni
- esegue handler lato worker
- salva metadata, result e plot
- restituisce output JSON coerenti

L'app oggi supporta due famiglie di operation:

1. **operation non legacy**
   - già implementate in Python
   - integrate nell'architettura moderna

2. **operation legacy**
   - introdotte per compatibilità funzionale con il vecchio sistema
   - oggi eseguite tramite `atm_ser` / Octave
   - esposte comunque dentro l'architettura moderna come normali job HTTP

---

## 3. Architettura target da rispettare

L'architettura corretta da preservare è quella moderna dell'app:

- endpoint HTTP moderni
- job system moderno
- validazione moderna
- operation registry
- handler isolati
- storage e worker separati
- result JSON strutturati
- errori strutturati

Vincolo importante:
**non bisogna reintrodurre il vecchio protocollo socket/websocket né il vecchio contratto raw di `wrfserver.py`**.

I comandi legacy devono diventare semplicemente operation normali del sistema.

---

## 4. Stato attuale del ramo legacy

## 4.1 Stato concettuale

Il ramo legacy è già stato integrato nell'architettura moderna.

Oggi:
- i comandi legacy sono operation interne (`legacy_*`)
- l'input passa dal normale endpoint `/jobs`
- i parametri sono JSON strutturati
- il job system moderno resta invariato
- gli errori sono strutturati nel metadata del job
- i risultati legacy vengono restituiti come JSON

Questa parte è stata considerata **conclusa e congelabile**.

## 4.2 Stato tecnico

Attualmente il ramo legacy funziona così:

`POST /jobs`
→ `operation = legacy_*`
→ validazione parametri
→ handler legacy
→ adapter `atm_ser`
→ esecuzione `octave-cli`
→ parsing output
→ result JSON nel job

Quindi il legacy oggi è confinato dietro:
- operation legacy
- handler legacy
- adapter `atm_ser`

---

## 5. Operation legacy attualmente presenti

Le operation legacy attualmente supportate sono:

- `legacy_iwv`
- `legacy_opacity`
- `legacy_meteo`
- `legacy_rain`
- `legacy_tsys`

Tutte sono già integrate come operation del sistema.

---

## 6. Obiettivo della prossima fase

L'obiettivo NON è cambiare il contratto esterno.

L'obiettivo è sostituire **l'implementazione interna** delle operation legacy.

In altre parole:

### Prima
`legacy_*` → adapter → `atm_ser` → Octave

### Dopo
`legacy_*` → handler Python diretto

Quindi:

- i nomi delle operation legacy restano
- i payload JSON restano
- il job system resta
- il result JSON deve restare coerente
- l'implementazione Octave deve essere sostituita da codice Python

---

## 7. Risposta alla domanda su `atm_ser`

Sì: **a regime `atm_ser` non deve più servire**.

`atm_ser` oggi esiste solo come backend transitorio per eseguire i comandi legacy tramite Octave.

Quando le operation legacy saranno state reimplementate in Python in modo completo e verificato, il percorso corretto è:

1. smettere di usare `atm_ser`
2. rimuovere l'adapter legacy
3. rimuovere la dipendenza da Octave per quei comandi
4. lasciare le operation `legacy_*` o rinominarle solo se esplicitamente richiesto

Quindi:
- nel breve periodo `atm_ser` serve ancora come riferimento e baseline
- nel target finale **non deve più essere usato**

---

## 8. Cosa NON deve cambiare

Durante la migrazione, queste cose devono restare stabili:

- endpoint `/jobs`
- modello job
- meccanismo di queue/worker
- validazione operation/parameters
- struttura generale del result JSON
- errori strutturati
- isolamento tra API, servizi, handler e worker

In particolare:
**non bisogna far trapelare dettagli di Octave o del backend interno ai client**.

---

## 9. Cosa può e deve cambiare

Queste parti devono cambiare:

- handler legacy: da passthrough/adapter a logica Python vera
- integrazione `atm_ser`: da dipendenza attiva a componente da eliminare
- implementazione scientifica: da Octave a Python

Queste parti potranno probabilmente essere rimosse alla fine:
- adapter `atm_ser`
- parsing output di `atm_ser`
- eventuali utility strettamente legate a Octave per i comandi legacy
- dipendenza di runtime da Octave, almeno per quel ramo

---

## 10. Strategia corretta di migrazione

La migrazione va fatta **per operation**, non tutta insieme in modo cieco.

Ordine consigliato:

1. scegliere una operation legacy
2. capire con precisione cosa calcola oggi
3. confrontare input/output attuali
4. scrivere implementazione Python equivalente
5. sostituire internamente il backend per quella operation
6. verificare che il contratto esterno resti invariato
7. ripetere per la operation successiva

Questo riduce il rischio e permette confronti puntuali con il backend legacy.

---

## 11. Strategia consigliata per ciascuna operation

Per ogni `legacy_*`, seguire questo schema:

### Step A — mappatura funzionale
Capire:
- quali parametri prende
- quali unità usa
- quale significato scientifico ha
- che shape ha l'output
- che differenza c'è tra `hour > 0` e `hour == 0`

### Step B — definizione del contratto da preservare
Fissare:
- nome operation
- payload JSON in input
- result JSON in output
- codici errore attesi

### Step C — reimplementazione Python
Scrivere codice Python che produca lo stesso comportamento funzionale.

### Step D — confronto con la baseline legacy
Confrontare il risultato Python con:
- il comportamento attuale dell'app legacy-integrata
- e/o direttamente con `atm_ser`, se ancora presente

### Step E — switch backend
Una volta verificata l'equivalenza:
- il handler legacy deve usare Python
- non deve più usare `atm_ser`

---

## 12. Punto fondamentale: non cambiare il contratto esterno

La nuova implementazione Python deve essere una **sostituzione interna**, non una riscrittura del contratto.

Quindi, salvo decisione esplicita diversa:

- `legacy_iwv` deve continuare a restituire lo stesso tipo di result
- `legacy_opacity` idem
- `legacy_meteo` idem
- `legacy_rain` idem
- `legacy_tsys` idem

Se in futuro si vorrà rinominare o fondere queste operation, farlo solo dopo, in un'altra fase.

---

## 13. Differenza tra stato attuale e stato desiderato

## Stato attuale
- operation legacy integrate nell'architettura moderna
- esecuzione scientifica delegata a `atm_ser` / Octave
- parsing output legacy già fatto
- test automatici presenti e funzionanti

## Stato desiderato
- operation legacy ancora presenti e stabili
- esecuzione scientifica in Python
- nessuna dipendenza da `atm_ser`
- nessuna dipendenza da Octave per i comandi legacy
- stessi test che continuano a passare

---

## 14. Cosa usare come baseline di verifica

La baseline di comportamento è questa:

1. l'applicazione legacy-integrata attuale, che è stata verificata e congelata
2. `atm_ser`, finché è ancora disponibile, come riferimento tecnico
3. `wrfserver.py` solo come riferimento storico del comportamento legacy originario

La baseline principale per la migrazione deve essere:
**l'attuale app funzionante**, non il vecchio socket server.

---

## 15. Test e verifica

Esiste uno smoke test runner aggiornato che copre:
- core API
- operation legacy principali
- validation errors
- failure attesi

Questo runner va usato come regressione dopo ogni modifica.

Obiettivo minimo:
- tutti i test esistenti devono continuare a passare

Obiettivo ideale:
- aggiungere test più specifici per confrontare output Python vs output legacy originale, se necessario

---

## 16. Criteri di completamento della migrazione

La migrazione delle operation legacy può essere considerata conclusa quando:

1. tutte le operation legacy sono implementate in Python
2. tutti i test automatici passano
3. il contratto esterno è invariato
4. `atm_ser` non è più invocato
5. il codice Octave legacy non è più necessario per l'esecuzione normale
6. l'app continua a funzionare interamente dentro l'architettura moderna

---

## 17. Ordine consigliato dei lavori

Ordine consigliato molto concreto:

1. leggere il codice reale del progetto
2. individuare i moduli legacy attuali
3. mappare una operation alla volta
4. reimplementare in Python partendo da quella più semplice
5. mantenere invariati test e contratto esterno
6. usare il runner di smoke test dopo ogni sostituzione
7. completare tutte le operation
8. rimuovere `atm_ser`
9. rimuovere il codice legacy superfluo
10. fare pulizia finale e documentare il nuovo stato

---

## 18. Cosa deve capire subito una AI nella nuova chat

La AI che riceve solo il codice deve capire immediatamente queste cose:

- l'app è un sistema a job asincroni
- il legacy è già integrato architetturalmente
- il problema non è più integrare il legacy
- il problema adesso è **sostituire l'implementazione interna legacy con Python**
- il contratto esterno non va rotto
- `atm_ser` è transitorio
- Octave deve uscire dal percorso dei comandi legacy

---

## 19. Indicazioni operative per la nuova chat

Quando parte la nuova chat:
- leggere il codice reale, non fare assunzioni teoriche
- identificare dove oggi si trova il ramo legacy
- non riscrivere l'architettura
- non cambiare `/jobs`
- non cambiare il job model
- non cambiare il contratto pubblico se non richiesto
- lavorare per sostituzione interna e progressiva

---

## 20. Sintesi finale

La parte legacy è stata già integrata e congelata.

La prossima fase non è più una fase di integrazione, ma di **reimplementazione interna**.

Obiettivo finale:

- i comandi legacy devono restare utilizzabili come operation normali
- la loro implementazione deve diventare Python nativa
- `atm_ser` deve sparire
- Octave deve sparire da quel ramo
- l'architettura moderna dell'app deve restare intatta

Questo è il vincolo principale da rispettare.
