How to use the downloader

chmod +x download_systems.sh
./download_systems.sh systems.txt

If not using the main branch, one can use it three ways:

# Default — pulls from main
./downloader.sh systems.txt

# Branch as second argument
./downloader.sh systems.txt dev

# Branch as environment variable (useful in CI or scripts)
BRANCH=dev ./downloader.sh systems.txt


---

Two scripts created alongside downloader.sh:

start_systems.sh [systems.txt]

Reads the same systems.txt with the same blank/comment filtering as downloader.sh
Kills any pre-existing systems tmux session so re-running is safe
Creates one tmux window per system, named after the system, and runs <system>/<system>_rpi64 in each
Attaches the terminal to the session so you see it immediately
stop_systems.sh

Finds the systems tmux session
Iterates over every window and sends Ctrl+C, printing each window name as it goes
Waits 3 seconds for the processes to shut down gracefully
Kills the tmux session
Typical workflow:


./start_systems.sh systems.txt   # launch everything
# ... work ...
./stop_systems.sh                # shut everything down cleanly

---

Starting the cloud at boot: mbaigo-cloud.service

start_systems.sh has to be run by somebody. On an edge deployment that is a
problem with a physical consequence: after a power cut the Raspberry Pi comes
back, Docker brings back GraphDB and InfluxDB because they are
--restart unless-stopped, and the Arrowhead cloud does not come back at all.
At a cottage heated through ZigBee plugs — which return to *off* when power is
restored — that means the heating stays off until a person notices.

Install the unit on the host:

    sudo install -m 0644 mbaigo-cloud.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable --now mbaigo-cloud.service

Then use systemctl rather than the scripts directly, so systemd's idea of the
state stays true:

    sudo systemctl stop mbaigo-cloud     # runs stop_systems.sh
    sudo systemctl start mbaigo-cloud    # runs start_systems.sh

The session is the same tmux session, owned by the same user, so

    tmux attach -t systems

still reaches it.

Two details in the unit carry the weight. Type=forking with KillMode=process
stops systemd killing the tmux server the moment start_systems.sh returns,
which the default would do — leaving the unit "active" with no cloud running.
And it orders After=docker.service without depending on it, so a broken
database can never keep the heating offline.

start_systems.sh attaches to the session only when stdout is a terminal. Under
systemd there is none, and `tmux attach` would fail; as the last command in the
script its status becomes the script's, so a perfectly good cloud would be
reported as failed — and with Restart=on-failure, torn down.

Verified on a real reboot: 14 systems serving 89 seconds after power-on.
