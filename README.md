# jSwitch

CLI per gestire versioni Java (JDK) da terminale, in stile `nvm`.

## Requisiti

- Node.js installato
- Windows (per la gestione di `JAVA_HOME` con `setx`)

## Installazione locale

Nel progetto:

```powershell
npm link
```

Dopo il link, il comando `jswitch` sara disponibile nel terminale.

## Utilizzo

1. Configura la cartella radice delle JDK:

```powershell
jswitch start
```

2. Elenca le JDK trovate:

```powershell
jswitch list
```

3. Imposta `JAVA_HOME` su una JDK specifica:

```powershell
jswitch use <nome_jdk>
```

Esempio:

```powershell
jswitch use corretto-1.8.0_482
```

4. Mostra JDK corrente:

```powershell
jswitch current
```

## Note

- `jswitch use` imposta `JAVA_HOME` a livello utente (persistente) con `setx`.
- Dopo `jswitch use`, apri un nuovo terminale per vedere il nuovo valore in tutte le shell.
