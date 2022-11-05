# KStor

KStor stores and shares secrets among teams of users.

It doesn't work yet. No error checks. Glaring holes everywhere. Will empty your
fridge and scare your cat. Obviously, don't store anything valuable and not
public in KStor!

It has a server and an ugly command-line client. The plan is to have a web user
interface someday; the command-line client is mostly here to help me do basic
debugging.

Basic principle means that (when it will be ready), data at rest will always be
encrypted. To read secret values and metadata, you need user passwords.

User passwords are derived to make secret keys. Secret keys are used to decrypt
user key pairs (public and private). User private keys are used to decrypt
group key pairs. Group private keys are used to decrypt secrets. Pfew!

## Basic usage

1. create config file in YAML with the following keys:
  * database: path to SQLite database file
  * socket: path to UNIX socket that the server will listen to
  * nworkers: number of worker threads
2. copy systemd/kstor.* to ~/.config/systemd/user/ and adjust paths
3. systemctl --user daemon-reload
4. systemctl --user start kstor.socket
5. bundle exec kstor --help

### Available request types

So far I've implemented:
* group-create
* secret-create
* secret-search
* secret-unlock
* secret-update-metadata
* secret-update-value
* secret-delete

### Notes

On first access, it will create your user in database (login defaults to your
login). Passwords are asked interactively.

It will store session ID in XDG_RUNTIME_DIR/kstor/session-id .

Each request can be authentified either with login/password or with session ID.
