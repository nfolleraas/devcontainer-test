# devcontainer-test

A small bun-workspaces monorepo used to try out a VS Code dev container that
runs a React frontend, a NestJS backend and a Postgres database together.

| App | Stack | Path | Port (in container) |
|---|---|---|---|
| `web` | React 19 + TypeScript, Vite 8 | `apps/web` | 5173 |
| `api` | NestJS 12 + TypeScript | `apps/api` | 3000, all routes under `/api` |
| `db` | Postgres 17 | compose service | 5432, reachable as hostname `db` |

For a line-by-line explanation of the container setup, why each setting
exists and how to change it, see [DEVCONTAINER.md](DEVCONTAINER.md).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Docker Compose v2
- [VS Code](https://code.visualstudio.com/) with the
  [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  extension

Nothing else is needed on the host. Node, bun and Postgres all live inside
the containers.

## Using the dev container

A dev container is a Docker container that VS Code opens the repo inside of.
Your editor, terminal, extensions and the tools you run all live in the
container, so every contributor gets the same Node version, the same bun and
the same database without installing anything on their machine.

Everything the container needs is described in `.devcontainer/`:

| File | Purpose |
|---|---|
| `devcontainer.json` | What VS Code attaches to, which ports to forward, which extensions to install, what to run after creation |
| `compose.yaml` | The two containers: `app` (Node 22 + bun, holds the repo) and `db` (Postgres 17) |
| `devcontainer-lock.json` | Pinned versions of the installed features. Commit it, like `bun.lock` |

### Open the project in the container

1. Clone the repo and open the folder in VS Code.
2. When prompted, choose **Reopen in Container**. If there is no prompt, open
   the command palette and run **Dev Containers: Reopen in Container**.
3. Wait for the build. On first run VS Code pulls the images, installs bun,
   starts Postgres and runs `bun install` automatically.

The repo is mounted at `/workspaces/devcontainer-test` inside the container.
Edits made in VS Code land directly in your local checkout, so git works as
usual from either side.

### Everyday commands

| Action | Command palette entry |
|---|---|
| Rebuild after editing `devcontainer.json` or `compose.yaml` | **Dev Containers: Rebuild Container** |
| Rebuild from scratch, discarding image cache | **Dev Containers: Rebuild Container Without Cache** |
| Leave the container and work on the host | **Dev Containers: Reopen Folder Locally** |
| See forwarded ports and their real host port | **Ports** panel in the bottom bar |

A running container does not pick up config changes. Any edit under
`.devcontainer/` needs a rebuild.

### Things to know

- `bun install` only runs automatically when the container is first created.
  After pulling changes that touch a `package.json`, run it again by hand from
  the repo root.
- Forwarded ports are "make reachable", not "guarantee this number". If 5173
  is busy on your host, VS Code picks another port and shows it in the Ports
  panel.
- The database is only on the compose network. The `api` app reaches it as
  `db:5432` via the `DATABASE_URL` environment variable, which is already set
  in the `app` container. To connect a GUI from the host, forward `db:5432`
  from the Ports panel.
- Database data lives in a named volume (`pgdata`), so it survives container
  rebuilds. Delete the volume if you want a clean database.
- Extensions listed in `devcontainer.json` (oxc, Prettier) install inside the
  container. Host extensions do not carry over.

## Running the project

All commands are run from the repo root, inside the container.

```
bun install        # once, or after dependency changes
bun run dev        # starts web and api in parallel
```

`bun run dev` runs the `dev` script of every workspace package and prefixes
the output with the package name. Then open the **web** port from the Ports
panel. Vite proxies every `/api/...` request to Nest, so the browser only ever
talks to a single origin. The API currently exposes a single `GET /api` route
that returns a hello message.

To run one app on its own:

```
bun run --filter web dev
bun run --filter api dev
```

### Per-app scripts

Run these with `bun run --filter <app> <script>` from the root, or `bun run
<script>` from inside the app's directory.

| Script | `web` | `api` |
|---|---|---|
| `dev` | Vite dev server with HMR | `nest start --watch` |
| `build` | `tsc -b && vite build` | `nest build` to `dist/` |
| `lint` | oxlint | oxlint, type-aware |
| `test` | – | vitest unit tests |
| `test:e2e` | – | vitest e2e tests |
| `format` | – | Prettier over `src/` and `test/` |
| `preview` | serve the production build | – |
| `start:prod` | – | `node dist/main` |

### Database

Credentials are fixed for local development and set in `compose.yaml`:

```
postgres://app:app@db:5432/app
```

No app uses the database yet. When one does, pick a driver or ORM that reads
`DATABASE_URL` and nothing in the container setup needs to change.

## Repository layout

```
.
├── .devcontainer/          # container definition, see DEVCONTAINER.md
├── apps/
│   ├── web/                # Vite + React frontend
│   └── api/                # NestJS backend
├── DEVCONTAINER.md         # detailed reference for the container setup
├── package.json            # bun workspaces root, holds the "dev" script
├── bun.lock                # single lockfile for all workspaces
└── .gitignore              # single ignore file for the whole repo
```

Bun uses its isolated linker for workspaces. Real packages live in
`node_modules/.bun` at the root and each app's `node_modules` only contains
symlinks to what that app declares. Always run `bun install` from the root.

## Related documentation

- [DEVCONTAINER.md](DEVCONTAINER.md): every file in `.devcontainer/` explained,
  how to add tools, services or extensions, and gotchas met while building it.
- [apps/web/README.md](apps/web/README.md): the Vite React template notes,
  including how to enable type-aware oxlint rules and the React Compiler.
- [apps/api/README.md](apps/api/README.md): the NestJS starter notes.
- [Dev Containers specification](https://containers.dev/) and
  [feature catalog](https://containers.dev/features) for adding tools to the
  container.
- [VS Code Dev Containers docs](https://code.visualstudio.com/docs/devcontainers/containers).
- [Bun workspaces](https://bun.com/docs/install/workspaces) for how
  `--filter` and the shared lockfile behave.

## Versions

| Tool | Version |
|---|---|
| Node (container) | 22 |
| bun | 1.4 |
| Vite | 8.3 |
| React | 19.2 |
| NestJS | 12.0 |
| Postgres | 17 |
