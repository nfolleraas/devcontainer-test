# Dev container setup

Reference for how this repo's development environment is put together, why each
piece exists, and how to change it. Written after building it step by step on
2026-10-09.

## What you get

One VS Code dev container running two apps from the same repo at the same time,
plus a Postgres database in a sidecar container.

| Piece                       | Where                | Runs on                                        |
| --------------------------- | -------------------- | ---------------------------------------------- |
| React + TypeScript (Vite 8) | `apps/web`           | container port 5173                            |
| NestJS 12 + TypeScript      | `apps/api`           | container port 3000, routes under `/api`       |
| Postgres 17                 | `db` compose service | hostname `db`, port 5432, compose network only |

Start everything from the repo root inside the container:

```
bun run dev
```

Then open the `web` port from the VS Code Ports panel. Requests to `/api/...` are
proxied by Vite to Nest, so the browser only ever talks to one origin.

## Repo layout

```
.
├── .devcontainer/
│   ├── devcontainer.json       # what VS Code attaches to and installs
│   ├── compose.yaml            # the containers: app + db
│   └── devcontainer-lock.json  # pinned feature versions, commit it
├── apps/
│   ├── web/                    # Vite + React, package name "web"
│   └── api/                    # NestJS, package name "api"
├── package.json                # bun workspaces root, holds the "dev" script
├── bun.lock                    # single lockfile for all workspaces
└── .gitignore                  # single ignore file for the whole repo
```

Bun uses its isolated linker for workspaces: real packages live in the hidden
`node_modules/.bun` at the root and each app's `node_modules` holds symlinks to
only what it declares. Always run `bun install` from the root.

## The files, line by line

### `.devcontainer/devcontainer.json`

```json
{
  "name": "devcontainer-test",
  "dockerComposeFile": "compose.yaml",
  "service": "app",
  "workspaceFolder": "/workspaces/devcontainer-test",
  "features": {
    "ghcr.io/shyim/devcontainers-features/bun:0": {}
  },

  "forwardPorts": [5173, 3000, 5432],
  "portsAttributes": {
    "5173": { "label": "web (vite)" },
    "3000": { "label": "api (nest)" },
    "5432": { "label": "db (postgres)" }
  },

  "postCreateCommand": "bun install",

  "customizations": {
    "vscode": {
      "extensions": [
        "biomejs.biome",
        "mikestead.dotenv",
        "bradlc.vscode-tailwindcss",
        "redhat.vscode-yaml",
        "SalomonKylian.html-quick-wrapper",
        "formulahendry.auto-rename-tag",
        "aaron-bond.better-comments",
        "usernamehw.errorlens",
        "PKief.material-icon-theme",
        "YoavBls.pretty-ts-errors"
      ],
      "settings": {
        "workbench.startupEditor": "none",
        "workbench.iconTheme": "material-icon-theme",
        "editor.defaultFormatter": "biomejs.biome",
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
          "source.fixAll.biome": "explicit",
          "source.organizeImports.biome": "explicit",
          "source.action.useSortedAttributes.biome": "explicit"
        }
      }
    }
  },

  "remoteUser": "node"
}
```

- **`dockerComposeFile` / `service` / `workspaceFolder`** replace a plain `image`.
  VS Code brings up every service in the compose file and attaches to `app`.
  `workspaceFolder` must match the bind-mount target in `compose.yaml`.
- **`features`** are install scripts layered onto the service image at build
  time. The base image has no bun, so this adds it. `:0` is the feature's major
  version, not bun's; the exact resolved version is recorded in
  `devcontainer-lock.json`.
- **`forwardPorts`** makes container ports reachable from the host browser.
  It means "make reachable", not "guarantee this number": if the host port is
  busy, VS Code picks the next free one and the Ports panel shows the real one.
- **`portsAttributes`** only sets labels for the Ports panel.
- **`postCreateCommand`** runs once, after the container is first created, not
  on every start. After pulling changes to any `package.json`, run `bun install`
  by hand.
- **`customizations.vscode.extensions`** install inside the container. Host
  extensions do not carry over.
- **`customizations.vscode.settings`** are editor settings applied only inside
  the container. `workbench.iconTheme` selects Material Icon Theme for
  everyone, since installing the extension alone does not activate it. The
  rest make the Biome extension the formatter and linter:
  format on every save, and on an explicit save also apply safe lint fixes,
  organise imports and sort JSX props. Biome reads the single `biome.json`
  at the repo root and finds its binary in `node_modules`, which is why
  `@biomejs/biome` is a root dev dependency pinned to an exact version, as
  Biome's own docs recommend. The config excludes `public/`, `*.svg` and
  `*.html`, so `index.html` and the icon assets are never rewritten. The `apps/api` override turns off `useImportType` because NestJS
  dependency injection needs runtime class imports under
  `emitDecoratorMetadata`.
- **`remoteUser`** avoids working as root. The base image ships a `node` user.

### `.devcontainer/compose.yaml`

```yaml
services:
  app:
    image: mcr.microsoft.com/devcontainers/typescript-node:22-bookworm
    volumes:
      - ..:/workspaces/devcontainer-test:cached
    command: sleep infinity
    environment:
      - DATABASE_URL=postgres://app:app@db:5432/app
    depends_on:
      - db
  db:
    image: postgres:17
    environment:
      - POSTGRES_USER=app
      - POSTGRES_PASSWORD=app
      - POSTGRES_DB=app
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

- **`app.image`** is Microsoft's prebuilt Node 22 image on Debian bookworm with
  git, zsh and the `node` user. Node 22 because Vite 8 needs at least 20.19.
- **`app.volumes`** bind-mounts the repo. The compose file lives in
  `.devcontainer/`, so `..` is the repo root.
- **`app.command: sleep infinity`** keeps the container alive. The image has no
  long-running process, so without this it exits immediately and VS Code has
  nothing to attach to.
- **`DATABASE_URL`** uses hostname `db`, the name of the other service. Inside
  the compose network, service names resolve as DNS. `localhost` inside `app`
  is only `app` itself. Verify with `getent hosts db`.
- **`db`** has no `ports` block on purpose. The app reaches it over the compose
  network. Host access, if ever wanted, goes through VS Code port forwarding.
- **`pgdata`** is a named volume, so data survives container rebuilds. Note the
  two different `volumes:` shapes: a _list_ inside a service, a _mapping_ at
  the top level. Getting this wrong gives `volumes must be a mapping`.

Validate after editing, from inside `.devcontainer/`:

```
docker compose config
```

### `package.json` (root)

```json
{
  "name": "devcontainer-test",
  "private": true,
  "workspaces": ["apps/*"],
  "scripts": {
    "dev": "bun run --filter '*' dev",
    "check": "biome check",
    "check:fix": "biome check --write",
    "lint": "biome lint",
    "format": "biome format --write",
    "format:check": "biome format"
  },
  "devDependencies": {
    "@biomejs/biome": "2.5.15"
  }
}
```

`--filter '*'` runs the `dev` script of every workspace package in parallel,
prefixing output with the package name. Both apps must therefore have a script
named `dev`. The Biome scripts are not filtered: Biome walks the whole repo
from the root, honouring `.gitignore` through its `vcs` setting, and the
per-app `lint` scripts just call `biome lint .` for convenience. `check` is
the one to run in CI, since it covers lint, format and import order in a
single pass. The Nest app's `dev` was added by hand as an alias:

```json
"dev": "nest start --watch"
```

### `apps/api/src/main.ts`

```ts
app.setGlobalPrefix('api');
```

Every Nest route lives under `/api`. This is what lets the Vite proxy forward
`/api` without a path rewrite.

### `apps/web/vite.config.ts`

```ts
server: {
  host: true,
  proxy: {
    '/api': 'http://localhost:3000',
  },
},
```

- **`host: true`** makes Vite listen on all interfaces, not just loopback.
  Required for the port to be reachable from outside the container.
- **`proxy`** forwards `/api/...` to Nest. `localhost:3000` is correct here
  because Vite and Nest run in the same container.

### `.gitignore` (root)

One ignore file for the whole repo. Ignore files only apply to their own
directory and below, so per-app ones were removed. Includes `node_modules`,
`dist`, `*.local`, `*.tsbuildinfo` and the usual editor noise.

## How to change things

**Any edit to `devcontainer.json` or `compose.yaml`** requires
_Dev Containers: Rebuild Container_ from the command palette. A running
container does not pick up config changes.

**Add a tool to the container** (e.g. a CLI): look for a feature at
https://containers.dev/features and add it under `features`. If none exists,
switch `app.image` to `build: { dockerfile: Dockerfile }` in `compose.yaml`
and install it there.

**Add another service** (Redis, Mailpit, ...): add it under `services:` in
`compose.yaml`, give it a named volume if it holds data, and reference it from
`app` by its service name. No `ports` block needed for app-to-service traffic.

**Swap the database**: change `db.image` and the three `POSTGRES_*` variables
to the new engine's equivalents, update `DATABASE_URL` to match, and delete the
old volume (`docker volume rm devcontainer-test_devcontainer_pgdata`) since
engines can't share a data directory.

**Connect Nest to Postgres**: pick a driver or ORM (Prisma, Drizzle, TypeORM).
All of them read `DATABASE_URL`, which is already set inside `app`. Nothing in
the devcontainer needs to change.

**Reach the database from a host GUI**: in the Ports panel, forward
`db:5432` rather than relying on the `5432` entry in `forwardPorts`, which
only looks at the `app` container and will show as unused.

**Add a VS Code extension**: add its ID to `customizations.vscode.extensions`
and rebuild, or install it from the Extensions view while in the container
and choose _Add to devcontainer.json_.

**Change a port**: update it in three places: the app's own config, `forwardPorts`,
and `portsAttributes`.

## Gotchas met along the way

- **Vite shows up on a different host port.** Another project on the host
  already publishes 5173, so VS Code forwarded to 5174. Read the real port from
  the Ports panel, or stop the other project, or move Vite to an unused port.
- **`git rm --cached` says pathspec did not match.** Paths are relative to the
  directory you run git from, not the repo root.
- **Nest CLI asks about `@nestjs/observe`.** It's a hosted observability SaaS,
  not a linter. Answer no, or pass `--no-observe`.
- **`tsconfig.build.tsbuildinfo` was committed.** It's a build cache. Ignore
  rules never affect already-tracked files, so after adding `*.tsbuildinfo` to
  `.gitignore` it also had to be removed with `git rm --cached`.
- **`devcontainer-lock.json` appeared after the first build.** Commit it. It
  pins the exact feature version, same reasoning as `bun.lock`.

## Versions at time of writing

| Tool             | Version |
| ---------------- | ------- |
| Node (container) | 22      |
| bun              | 1.4.2   |
| Vite             | 8.3     |
| React            | 19.2    |
| NestJS           | 12.0    |
| Postgres         | 17      |
| Docker Compose   | v5.5    |
| Biome            | 2.5.15  |
