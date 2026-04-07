# QuickPizza Development

Running QuickPizza locally.

**Prerequisites**: Go 1.21+ and Node.js 18+

## Development Mode (with Live-Reload)

For the best development experience with automatic frontend reloading:

1. Install frontend dependencies (first time only):
   ```bash
   make install-web
   ```

2. Start dev server with live-reload:
   ```bash
   make dev
   ```

3. Access at `http://localhost:3333`

This starts both:
- Vite dev server on port 5173 (with hot module replacement)
- Go backend on port 3333 (proxies to Vite for frontend assets)

Frontend changes will reload instantly without rebuilding or restarting the server.

## Production Build

To build and run as in production:

1. Build frontend:
   ```bash
   make build-web
   ```

2. Run backend:
   ```bash
   go run ./cmd
   ```

3. Access at `http://localhost:3333`



