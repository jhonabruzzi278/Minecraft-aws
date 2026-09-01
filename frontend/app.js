// ============================================================
// PANEL DE CONTROL MINECRAFT ENTERPRISE - DUOC UC • JAVASCRIPT
// ============================================================

// Dirección IP del Servidor en AWS EC2 NAT / Minecraft
const API_BASE_URL = "http://3.231.202.80:8081";

// Estado de la aplicación
let authToken = sessionStorage.getItem("admin_token") || null;
let currentAdminUser = sessionStorage.getItem("admin_user") || null;
let listaJugadoresGlobal = [];
let autoRefreshInterval = null;

// Elementos del DOM - Encabezado y Métricas
const backendStatusText = document.getElementById("backend-status-text");
const storageBadge = document.getElementById("storage-badge");
const mcIpText = document.getElementById("mc-ip");
const btnCopyIp = document.getElementById("btn-copy-ip");
const mcPlayersCount = document.getElementById("mc-players-count");
const mcTpsValue = document.getElementById("mc-tps-value");
const mcRconState = document.getElementById("mc-rcon-state");
const btnRefrescarMc = document.getElementById("btn-refrescar-mc");
const checkAutoRefresh = document.getElementById("check-auto-refresh");

// Elementos del DOM - Jugadores
const gridJugadores = document.getElementById("grid-jugadores");
const inputBuscar = document.getElementById("input-buscar-jugador");
const btnConsultar = document.getElementById("btn-consultar");
const formCrear = document.getElementById("form-crear");
const mensaje = document.getElementById("mensaje");

// Elementos del DOM - Consola RCON
const terminalScreen = document.getElementById("terminal-screen");
const formCommand = document.getElementById("form-command");
const inputCommand = document.getElementById("input-command");
const formBroadcast = document.getElementById("form-broadcast");
const inputBroadcast = document.getElementById("input-broadcast");
const adminBadge = document.getElementById("admin-badge");
const btnTriggerBackup = document.getElementById("btn-trigger-backup");
const btnGiveDiamonds = document.getElementById("btn-give-diamonds");
const btnClearTerm = document.getElementById("btn-clear-term");

// Elementos de Autenticación Modal
const btnAuthToggle = document.getElementById("btn-auth-toggle");
const authIcon = document.getElementById("auth-icon");
const authText = document.getElementById("auth-text");
const modalLogin = document.getElementById("modal-login");
const btnCloseModal = document.getElementById("btn-close-modal");
const formLogin = document.getElementById("form-login");
const loginError = document.getElementById("login-error");
const toastContainer = document.getElementById("toast-container");


// ============================================================
// 1. SISTEMA DE NOTIFICACIONES TOAST
// ============================================================
function showToast(mensaje, tipo = "info") {
    const toast = document.createElement("div");
    toast.className = `toast ${tipo}`;
    const iconos = {
        success: "✓",
        error: "⚠️",
        info: "ℹ️"
    };
    toast.innerHTML = `<span>${iconos[tipo] || "•"}</span> <span>${mensaje}</span>`;
    toastContainer.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = "0";
        toast.style.transform = "translateX(50px)";
        toast.style.transition = "all 0.3s ease";
        setTimeout(() => toast.remove(), 300);
    }, 3500);
}


// ============================================================
// 2. GESTIÓN DE AUTENTICACIÓN ADMIN
// ============================================================
function actualizarEstadoAuth() {
    if (authToken) {
        authIcon.textContent = "🔓";
        authText.textContent = `Cerrar Sesión (${currentAdminUser})`;
        adminBadge.textContent = `✓ Administrador Conectado: ${currentAdminUser}`;
        adminBadge.className = "admin-status-pill logged-in";
    } else {
        authIcon.textContent = "🔒";
        authText.textContent = "Iniciar Sesión Admin";
        adminBadge.textContent = "Modo Administrador Requerido";
        adminBadge.className = "admin-status-pill";
    }
}

btnAuthToggle.addEventListener("click", () => {
    if (authToken) {
        authToken = null;
        currentAdminUser = null;
        sessionStorage.removeItem("admin_token");
        sessionStorage.removeItem("admin_user");
        actualizarEstadoAuth();
        imprimirTerminal("[SISTEMA] Sesión de administrador finalizada.", "system-line");
        showToast("Sesión de administrador cerrada", "info");
    } else {
        modalLogin.classList.remove("hidden");
    }
});

btnCloseModal.addEventListener("click", () => {
    modalLogin.classList.add("hidden");
});

formLogin.addEventListener("submit", async (e) => {
    e.preventDefault();
    loginError.textContent = "";

    const username = document.getElementById("admin-user").value.trim();
    const password = document.getElementById("admin-pass").value.trim();

    try {
        const res = await fetch(`${API_BASE_URL}/api/auth/login`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ username, password })
        });

        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Credenciales incorrectas");

        authToken = data.token;
        currentAdminUser = data.user;
        sessionStorage.setItem("admin_token", authToken);
        sessionStorage.setItem("admin_user", currentAdminUser);

        actualizarEstadoAuth();
        modalLogin.classList.add("hidden");
        imprimirTerminal(`[SISTEMA] ¡Bienvenido ${currentAdminUser}! Permisos RCON habilitados.`, "response-line");
        showToast(`Bienvenido administrador ${currentAdminUser}`, "success");
    } catch (err) {
        loginError.textContent = `⚠️ ${err.message}`;
    }
});


// ============================================================
// 3. TELEMETRÍA Y ESTADO DEL SERVIDOR EN TIEMPO REAL
// ============================================================
async function verificarEstadoBackend() {
    try {
        const res = await fetch(`${API_BASE_URL}/api/saludo`);
        if (!res.ok) throw new Error();
        const data = await res.json();
        backendStatusText.textContent = "Backend en Línea";
        storageBadge.textContent = data.persistencia || "Amazon DynamoDB";
    } catch {
        backendStatusText.textContent = "Backend Desconectado";
        storageBadge.textContent = "Offline";
    }
}

async function consultarEstadoMinecraft() {
    try {
        const res = await fetch(`${API_BASE_URL}/api/minecraft/status`);
        if (!res.ok) throw new Error("Servidor no responde");
        const data = await res.json();

        if (data.minecraft_ip && mcIpText) {
            mcIpText.textContent = data.minecraft_ip;
        }

        // Extraer conteo de jugadores
        const match = (data.jugadores || "").match(/(\d+)\s+of\s+a\s+max\s+of\s+(\d+)/i);
        if (match) {
            mcPlayersCount.textContent = `${match[1]} / ${match[2]} Jugadores`;
        } else {
            mcPlayersCount.textContent = data.jugadores || "En Línea";
        }

        mcTpsValue.textContent = "20.0 TPS";
        mcRconState.textContent = "Conectado (Puerto 25575)";
        mcRconState.className = "stat-data text-cyan";
    } catch (error) {
        mcRconState.textContent = "Desconectado";
        mcRconState.className = "stat-data text-red";
        mcPlayersCount.textContent = "0 / 10 Jugadores";
    }
}

btnRefrescarMc.addEventListener("click", () => {
    consultarEstadoMinecraft();
    showToast("Métricas actualizadas", "info");
});

// Copiar IP
btnCopyIp.addEventListener("click", () => {
    const ip = mcIpText.textContent;
    navigator.clipboard.writeText(ip);
    showToast(`IP copiada al portapapeles: ${ip}`, "success");
});

// Auto Refresh
checkAutoRefresh.addEventListener("change", (e) => {
    if (e.target.checked) {
        iniciarAutoRefresh();
        showToast("Monitoreo en vivo activado (cada 5s)", "info");
    } else {
        clearInterval(autoRefreshInterval);
        showToast("Monitoreo en vivo pausado", "info");
    }
});

function iniciarAutoRefresh() {
    clearInterval(autoRefreshInterval);
    autoRefreshInterval = setInterval(() => {
        consultarEstadoMinecraft();
    }, 5000);
}


// ============================================================
// 4. CONSULTA Y RENDERIZADO DE JUGADORES CON SKINS 3D
// ============================================================
async function obtenerUsuarios() {
    try {
        gridJugadores.innerHTML = `
            <div class="loading-state">
                <div class="spinner"></div>
                <p>Consultando base de datos de jugadores...</p>
            </div>
        `;
        const res = await fetch(`${API_BASE_URL}/api/usuarios`);
        if (!res.ok) throw new Error("Error al consultar jugadores");
        listaJugadoresGlobal = await res.json();
        renderizarJugadores(listaJugadoresGlobal);
    } catch (error) {
        gridJugadores.innerHTML = `
            <div class="empty-state">
                <p style="color: #f87171;">❌ Error al cargar jugadores (${error.message})</p>
            </div>
        `;
    }
}

function renderizarJugadores(jugadores) {
    gridJugadores.innerHTML = "";

    if (!jugadores || jugadores.length === 0) {
        gridJugadores.innerHTML = `
            <div class="empty-state">
                <p>🎮 No hay jugadores registrados en la base de datos.</p>
                <span style="font-size: 0.8rem; color: #64748b;">Utiliza el formulario de arriba para añadir un nuevo jugador.</span>
            </div>
        `;
        return;
    }

    jugadores.forEach((u) => {
        const gamertag = u.gamertag || u.nombre || "Steve";
        const skinUrl = `https://mc-heads.net/avatar/${encodeURIComponent(gamertag)}/56`;
        
        let fechaFormateada = "Reciente";
        if (u.fecha_registro) {
            try {
                const d = new Date(u.fecha_registro);
                fechaFormateada = d.toLocaleDateString("es-CL", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
            } catch {
                fechaFormateada = u.fecha_registro;
            }
        }

        const card = document.createElement("div");
        card.className = "player-card";
        card.innerHTML = `
            <div class="player-skin-wrap">
                <img class="player-skin-img" src="${skinUrl}" alt="${gamertag}" onerror="this.src='https://mc-heads.net/avatar/Steve/56'">
            </div>
            <div class="player-details">
                <div class="player-name">${u.nombre}</div>
                <div class="player-email">${u.email}</div>
                <div style="display: flex; align-items: center; gap: 0.4rem; flex-wrap: wrap; margin-top: 0.25rem;">
                    <span class="player-gamertag-pill">🎮 ${gamertag}</span>
                    <span style="font-size: 0.72rem; color: #38bdf8; background: rgba(56, 189, 248, 0.1); border: 1px solid rgba(56, 189, 248, 0.25); padding: 0.1rem 0.45rem; border-radius: 4px;">📅 ${fechaFormateada}</span>
                </div>
            </div>
            <div class="player-actions">
                <button class="btn-icon" title="Copiar Gamertag" onclick="copiarGamertag('${gamertag}')">📋</button>
                <button class="btn-icon btn-icon-delete" title="Eliminar de DynamoDB y Whitelist" onclick="eliminarJugador('${u.email}', '${gamertag}')">🗑️</button>
            </div>
        `;
        gridJugadores.appendChild(card);
    });
}


function copiarGamertag(gamertag) {
    navigator.clipboard.writeText(gamertag);
    showToast(`Gamertag "${gamertag}" copiado`, "success");
}

// Búsqueda en vivo
inputBuscar.addEventListener("input", (e) => {
    const q = e.target.value.toLowerCase().trim();
    if (!q) {
        renderizarJugadores(listaJugadoresGlobal);
        return;
    }
    const filtrados = listaJugadoresGlobal.filter((u) => 
        (u.nombre || "").toLowerCase().includes(q) ||
        (u.email || "").toLowerCase().includes(q) ||
        (u.gamertag || "").toLowerCase().includes(q)
    );
    renderizarJugadores(filtrados);
});

btnConsultar.addEventListener("click", () => {
    obtenerUsuarios();
    showToast("Lista de jugadores actualizada", "info");
});


// ============================================================
// 5. REGISTRO Y ELIMINACIÓN DE JUGADORES
// ============================================================
formCrear.addEventListener("submit", async (e) => {
    e.preventDefault();
    const nombre = document.getElementById("input-nombre").value.trim();
    const email = document.getElementById("input-email").value.trim();
    const gamertag = document.getElementById("input-gamertag").value.trim();

    try {
        mensaje.className = "alert-message alert-success";
        mensaje.textContent = "Registrando jugador y dando acceso en Whitelist...";
        mensaje.classList.remove("hidden");

        const res = await fetch(`${API_BASE_URL}/api/usuarios`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ nombre, email, gamertag }),
        });

        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Error al registrar jugador");

        mensaje.className = "alert-message alert-success";
        mensaje.textContent = `✓ Guardado en ${data.storage || "DynamoDB"}. RCON: ${data.minecraft_whitelist || "Añadido a lista blanca"}`;

        showToast(`Jugador ${gamertag} registrado con éxito`, "success");
        imprimirTerminal(`[SISTEMA] Jugador ${gamertag} registrado en DynamoDB y añadido a Whitelist.`, "response-line");
        
        formCrear.reset();
        obtenerUsuarios();
        consultarEstadoMinecraft();
    } catch (error) {
        mensaje.className = "alert-message alert-error";
        mensaje.textContent = `⚠️ Error: ${error.message}`;
        showToast(error.message, "error");
    }
});

async function eliminarJugador(email, gamertag) {
    if (!confirm(`¿Estás seguro de que deseas eliminar a "${gamertag}" (${email}) de DynamoDB y revocar su acceso en la Whitelist?`)) {
        return;
    }

    try {
        const res = await fetch(`${API_BASE_URL}/api/usuarios/${encodeURIComponent(email)}`, {
            method: "DELETE"
        });

        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Error al eliminar");

        showToast(`Jugador ${gamertag} eliminado`, "info");
        imprimirTerminal(`[SISTEMA] Jugador ${gamertag} eliminado de DynamoDB. RCON: ${data.minecraft_whitelist || "Removido"}`, "response-line");
        obtenerUsuarios();
    } catch (err) {
        showToast(`Error al eliminar: ${err.message}`, "error");
    }
}


// ============================================================
// 6. CONSOLA RCON, COMANDOS Y TRANSMISIÓN GLOBAL
// ============================================================
function imprimirTerminal(texto, tipo = "system-line") {
    const linea = document.createElement("div");
    linea.className = `terminal-line ${tipo}`;
    linea.textContent = texto;
    terminalScreen.appendChild(linea);
    terminalScreen.scrollTop = terminalScreen.scrollHeight;
}

async function enviarComandoRcon(comando) {
    if (!authToken) {
        imprimirTerminal("⚠️ Error: Debes iniciar sesión como Administrador para usar RCON.", "error-line");
        showToast("Inicia sesión como administrador para usar RCON", "error");
        modalLogin.classList.remove("hidden");
        return;
    }

    imprimirTerminal(`> ${comando}`, "cmd-line");

    try {
        const res = await fetch(`${API_BASE_URL}/api/minecraft/command`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${authToken}`
            },
            body: JSON.stringify({ comando })
        });

        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Error ejecutando comando");

        imprimirTerminal(`[${data.timestamp}] ${data.salida || "Comando ejecutado con éxito."}`, "response-line");
    } catch (err) {
        imprimirTerminal(`[ERROR] ${err.message}`, "error-line");
        showToast(err.message, "error");
    }
}

// Envío de comando libre
formCommand.addEventListener("submit", (e) => {
    e.preventDefault();
    const cmd = inputCommand.value.trim();
    if (!cmd) return;
    enviarComandoRcon(cmd);
    inputCommand.value = "";
});

// Botones de acciones rápidas
document.querySelectorAll(".btn-quick").forEach((btn) => {
    btn.addEventListener("click", async () => {
        const accion = btn.getAttribute("data-action");
        if (!accion) return;

        if (!authToken) {
            modalLogin.classList.remove("hidden");
            return;
        }

        imprimirTerminal(`> Ejecutando acción: ${btn.textContent.trim()}...`, "cmd-line");

        try {
            const res = await fetch(`${API_BASE_URL}/api/minecraft/quick-command/${accion}`, {
                method: "POST",
                headers: { "Authorization": `Bearer ${authToken}` }
            });

            const data = await res.json();
            if (!res.ok) throw new Error(data.error || "Error");

            imprimirTerminal(`[${data.timestamp}] (${data.comando}) ${data.salida}`, "response-line");
            showToast(`Acción "${btn.textContent.trim()}" ejecutada`, "success");
        } catch (err) {
            imprimirTerminal(`[ERROR] ${err.message}`, "error-line");
        }
    });
});

// Regalar Diamantes
btnGiveDiamonds.addEventListener("click", () => {
    enviarComandoRcon("give @a diamond 5");
    showToast("¡5 diamantes entregados a todos los jugadores!", "success");
});

// Respaldo de mundo a S3
btnTriggerBackup.addEventListener("click", async () => {
    if (!authToken) {
        modalLogin.classList.remove("hidden");
        return;
    }
    imprimirTerminal("> Iniciando sincronización y respaldo a Amazon S3...", "cmd-line");
    try {
        const res = await fetch(`${API_BASE_URL}/api/minecraft/backup`, {
            method: "POST",
            headers: { "Authorization": `Bearer ${authToken}` }
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Error");
        imprimirTerminal(`✓ ${data.mensaje} | RCON: ${data.rcon_output}`, "response-line");
        showToast("Mundo respaldado en Amazon S3 con éxito", "success");
    } catch (err) {
        imprimirTerminal(`[ERROR] ${err.message}`, "error-line");
    }
});

// Transmisión de Anuncio Global en el juego
formBroadcast.addEventListener("submit", (e) => {
    e.preventDefault();
    const msg = inputBroadcast.value.trim();
    if (!msg) return;
    enviarComandoRcon(`say [Anuncio Admin]: ${msg}`);
    showToast("Anuncio transmitido en el juego", "info");
    inputBroadcast.value = "";
});

// Limpiar terminal
btnClearTerm.addEventListener("click", () => {
    terminalScreen.innerHTML = '<div class="terminal-line system-line">[SISTEMA] Pantalla limpiada.</div>';
    showToast("Terminal limpiada", "info");
});


// ============================================================
// 7. INICIALIZACIÓN DE LA APLICACIÓN
// ============================================================
document.addEventListener("DOMContentLoaded", () => {
    actualizarEstadoAuth();
    verificarEstadoBackend();
    consultarEstadoMinecraft();
    obtenerUsuarios();
    iniciarAutoRefresh();
});
