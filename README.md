# shells — getting an mbaigo cloud onto a machine

These are the scripts that **put an Arrowhead (mbaigo) local cloud on a host
and keep it running**. They do not contain the cloud itself — the systems are
built elsewhere and published as binaries. This repository is the plumbing
around them: fetch the binaries, launch them, stop them, and bring them back
after a reboot.

If you have never done this before, read top to bottom once. Every term is
explained the first time it appears.

---

## The idea in one picture

A **local cloud** is just a set of small programs — called **systems** —
running on a machine and talking to each other. You choose which ones run by
listing them in a file called `systems.txt`, one per line. Then:

```
systems.txt   →   start_systems.sh   →   a running cloud
                  stop_systems.sh    →   stopped cleanly
                  mbaigo-cloud.service (systemd) → started again at every boot
```

That is the whole model. The rest of this document is detail.

A few words you will meet:

| word | what it means here |
|---|---|
| **system** | one program, e.g. the `thermostat` or the `esr` registry. |
| **tmux** | a tool that runs many terminal programs side by side in one window. The scripts use it so you can watch every system at once. |
| **CA** | the *Certificate Authority* system. It hands out the certificates that let systems trust each other. |
| **maitreD** | the system that vouches for the other programs on its host, so the CA will issue them a certificate. |
| **whitelist** | the list of approved program fingerprints. A program not on it is refused a certificate and will not run. This trips up newcomers — see *[The whitelist](#the-whitelist-the-one-thing-that-catches-everyone)*. |
| **systemd** | Linux's service manager. It is what starts things at boot. |

---

## Before you start

You need two things on the host:

1. **`tmux`** — install it once:
   ```bash
   sudo apt install tmux      # Debian / Raspberry Pi OS / Ubuntu
   ```
2. **The system binaries**, in a folder (by convention `~/rpiExec`), one
   sub-folder per system. You either copy them there yourself, or download
   them — see the next section.

The scripts in this repository go in that same `~/rpiExec` folder, beside the
binaries.

---

## Step by step, the first time

```bash
cd ~/rpiExec

# 1. Say which systems to run. Start from the annotated example:
cp systems.txt.example systems.txt
nano systems.txt              # edit the list — see "systems.txt" below

# 2. Launch them all:
./start_systems.sh

# 3. Watch them (this is a tmux session; one pane per system):
tmux attach -t systems
#    press  Ctrl-b  then  d   to detach again without stopping anything

# 4. Stop everything cleanly when you are done:
./stop_systems.sh
```

That is a complete run. Everything below explains each piece and what can go
wrong.

---

## `systems.txt` — the list of what runs

One system per line, launched **in the order written**. Blank lines and lines
beginning with `#` are ignored, so you can comment freely.

**Order matters at the top.** The CA must be running before anything asks it
for a certificate, and the maitreD must be there to vouch for the programs that
ask — so those come first, then the authorizer if the cloud enforces
permissions. Everything after that retries until what it needs appears, so the
order among them does not matter.

A minimal list:

```
ca
maitreD
authorizer
esr
orchestrator
```

**A line may carry arguments after the system's name.** Almost none need any —
a system reads its own configuration file and runs — but a few do. The clearest
example is `envoy`, one program with two modes, chosen on the command line:

```
envoy -serve view cloudpicture
```

Started with no arguments it just prints its usage and exits, so if a system
seems to vanish the instant it starts, check whether it needed arguments.

`systems.txt` itself is **not tracked in git** — what a given site runs is that
site's business. `systems.txt.example` is the template you copy.

---

## The scripts, one by one

### Getting the binaries: `downloader.sh` and `download_systems.sh`

Two ways to fetch the binaries, depending on where they are published.

- **`downloader.sh`** pulls from the LTU distribution server. You can choose the
  release channel:
  ```bash
  ./downloader.sh systems.txt          # default channel
  ./downloader.sh systems.txt dev      # a named branch
  BRANCH=dev ./downloader.sh systems.txt   # same, via an environment variable
  ```
  Errors are written to `download_errors.log`.

- **`download_systems.sh`** pulls the same idea from GitHub raw instead.

Whichever you use, remember the catch that has its own section below: **the
whitelist is not one of the files these fetch, and nothing runs without it.**

### Starting: `start_systems.sh`

```bash
./start_systems.sh [systems.txt]
```

It reads `systems.txt`, then:

- kills any earlier `systems` tmux session, so re-running is always safe;
- opens one tmux **pane per system**, named after the system, and runs its
  binary there;
- attaches your terminal to the session **only if you are at a terminal** — so
  it behaves under systemd (which has no terminal) as well as by hand.

### Stopping: `stop_systems.sh`

```bash
./stop_systems.sh
```

It finds the `systems` session, sends each pane a `Ctrl-C` (the polite "please
shut down"), waits a few seconds for them to exit cleanly, then closes the
session.

### On Windows: `start_systems.ps1` and `stop_systems.ps1`

The same two jobs in PowerShell, for a Windows host. There is no tmux; each
system gets its own console window. A `systems.txt` line may carry arguments
exactly as on Linux.

```powershell
.\start_systems.ps1
.\stop_systems.ps1
```

`stop_systems.ps1` stops the programs without sending a signal, so a system
stopped that way does not get to announce its departure; its registration
simply lapses a short while later. Closing a window with `Ctrl-C` is the
graceful way.

---

## Starting the cloud at boot: `mbaigo-cloud.service`

`start_systems.sh` has to be run by *somebody*. On a machine you leave alone —
an edge deployment — that "somebody" is a problem with a physical consequence.
After a power cut the machine comes back, its databases come back (Docker
restarts them automatically), **and the cloud does not come back at all**,
because no one is there to run the script.

At a cottage heated through smart plugs that return to *off* when power is
restored, that means the heating stays off until a person notices. This is not
hypothetical; it is why this file exists.

The fix is a **systemd service** that runs the start script at boot. Install it
once:

```bash
sudo install -m 0644 mbaigo-cloud.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mbaigo-cloud.service
```

After that, drive the cloud through systemd rather than the scripts directly,
so systemd's picture of the state stays honest:

```bash
sudo systemctl start mbaigo-cloud     # runs start_systems.sh
sudo systemctl stop  mbaigo-cloud     # runs stop_systems.sh
```

It is the same tmux session, owned by the same user, so you can still watch it:

```bash
tmux attach -t systems
```

**Why the unit is written the way it is** (you do not need to change it, but it
is worth knowing it is deliberate):

- `Type=forking` with `KillMode=process` stops systemd from killing the tmux
  server the moment the start script returns — the default would leave the unit
  looking "active" with nothing actually running.
- It is ordered `After=docker.service` but does **not** depend on it, so a
  broken database can never keep the heating offline.

Verified on a real reboot: 14 systems serving 89 seconds after power-on.

---

## The whitelist — the one thing that catches everyone

This is the single most common way a first deployment goes wrong, so it gets
its own section.

Every system must prove it is a program the cloud approves of before the CA
will give it a certificate. The proof is a **SHA-256 fingerprint** of the
binary, checked against `ca/whitelist.json`. The maitreD reads the running
program's fingerprint and, if it is on the list, the CA certifies it.

The consequence: **change a binary and its fingerprint changes.** Download a
newer version of one system on its own, and it is refused:

```
certification attempt failed (the CA refused to certify (403 Forbidden):
Attestation failed: maitreD rejected attestation: Executable not in whitelist)
```

The rest of the cloud keeps looking healthy, which is exactly what makes this
expensive to diagnose — the one system you just updated is the only one that
will not run.

**So: whenever binaries are published, the matching `ca/whitelist.json` is
published with them. Fetch both.** After fetching and before starting, check
that every binary on the host is covered:

```bash
cd ~/rpiExec
python3 - <<'PY'
import json, hashlib, glob, os
approved = set(json.load(open("ca/whitelist.json")))
bad = [os.path.dirname(b) for b in sorted(glob.glob("*/*_rpi64"))
       if hashlib.sha256(open(b, "rb").read()).hexdigest() not in approved]
print("unauthorized:", bad or "none")
PY
```

Anything it lists will not obtain a certificate. An old system left behind after
a rename shows up here forever and is harmless — as long as it is not in
`systems.txt`.

One more thing to expect: the maitreD keeps a cached copy of the last whitelist
it fetched and only refreshes it every few minutes. So right after the CA's
whitelist changes, there is a window of **up to five minutes** where attestation
is refused and systems cannot enroll. It clears on its own. Do not go hunting
for a second problem during it.

---

## When something goes wrong

| you see | it usually means |
|---|---|
| a system exits the instant it starts | it needed **arguments** in `systems.txt` (e.g. `envoy -serve …`), or it just wrote a fresh config file on its first run and needs starting again. |
| `Executable not in whitelist` | the binary's fingerprint is not in `ca/whitelist.json` — you fetched a binary without its whitelist, or you are inside the five-minute cache window. See above. |
| the unit says "active" but nothing runs | the systemd unit was edited to a plain `Type=simple`; it must be `Type=forking` with `KillMode=process`. |
| you cannot re-attach after closing the terminal | that is fine — the cloud is still running. `tmux attach -t systems` brings it back. |

---

## More than one host

This document covers a single machine. Running a cloud across several hosts —
two Raspberry Pis, or a Pi and a Windows PC — is covered in **`DEPLOYMENT.md`**
in the [`systems`](https://github.com/sdoque/systems) repository, which walks
through the network setup, the certificate authority on its own host, and what
each machine's configuration must say.
