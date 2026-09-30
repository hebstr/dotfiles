# rJava / libjvm.so introuvable

```
Error: package or namespace load failed for 'edstr':
 .onLoad failed in loadNamespace() for 'rJava', details:
  call: dyn.load(file, DLLpath = DLLpath, ...)
  error: unable to load shared object '.../rJava/libs/rJava.so':
  libjvm.so: cannot open shared object file: No such file or directory
```

Java est bien installé (`java -version` fonctionne), `libjvm.so` existe sur le système, mais le linker dynamique ne le voit pas : il n'est pas dans le cache `ldconfig`.

Cela arrive parce que R (notamment via Positron) ne passe pas par le wrapper shell qui sourcerait les `ldpaths` de R.

## Diagnostic

```bash
ldconfig -p | grep libjvm        # → vide = problème confirmé
find /usr /opt -name "libjvm.so" # → trouve le fichier, ex. /usr/lib/jvm/java-21-openjdk-amd64/lib/server/libjvm.so
```

## Solution

Enregistrer le répertoire de `libjvm.so` dans `ldconfig` une fois pour toutes :

```bash
# Adapter le chemin selon la version JDK installée (java-21, java-17, etc.)
echo "/usr/lib/jvm/java-21-openjdk-amd64/lib/server" | sudo tee /etc/ld.so.conf.d/java-jvm.conf
sudo ldconfig
```

Vérification :

```bash
ldconfig -p | grep libjvm
# doit retourner : libjvm.so (libc6,x86-64) => /usr/lib/jvm/java-21-openjdk-amd64/lib/server/libjvm.so
```

Redémarrer R.

## État du JDK sur cette machine (2026-09-13)

Le JDK Oracle 21.0.2 installé sous `/usr/lib/jvm/default-java` a été purgé ce jour-là (`.claude/PLAN-ORPHANS.md`, étape 9) : `default-java` est redevenu un lien vers `java-1.21.0-openjdk-amd64`, `java` tourne (OpenJDK 21.0.12) et **aucun `javac` n'est installé**. Une compilation depuis les sources qui en a besoin, `rJava` par exemple, demande `sudo apt install openjdk-21-jdk-headless` d'abord.
