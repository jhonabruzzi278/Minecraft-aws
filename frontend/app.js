// ============================================
// CONFIGURACIÓN GLOBAL
// ============================================
// IP Pública de AWS NAT Instance / Minecraft Server
const API_BASE_URL = "http://3.231.202.80:8081";



let authToken = sessionStorage.getItem("admin_token") || null;
let currentAdminUser = sessionStorage.getItem("admin_user") || null;

// Elementos del DOM
const btnConsultar = document.getElementById("btn-consultar");
const listaUsuarios = document.getElementById("lista-usuarios");
const formCrear = document.getElementById("form-crear");
const mensaje = document.getElementById("mensaje");
const btnRefrescarMc = document.getElementById("btn-refrescar-mc");
const mcPlayersBox = document.getElementById("mc-players-box");
const backendStatusText = document.getElementById("backend-status-text");
const storageBadge = document.getElementById("storage-badge");
const mcIpText = document.getElementById("mc-ip");


// Elementos de la Consola RCON
const terminalScreen = document.getElementById("terminal-screen");
const formCommand = document.getElementById("form-command");
const inputCommand = document.getElementById("input-command");
const adminBadge = document.getElementById("admin-badge");
const btnTriggerBackup = document.getElementById("btn-trigger-backup");

// Elementos de Autenticación
const btnAuthToggle = document.getElementById("btn-auth-toggle");
const authIcon = document.getElementById("auth-icon");
const authText = document.getElementById("auth-text");
const modalLogin = document.getElementById("modal-login");
const btnCloseModal = document.getElementById("btn-close-modal");
const formLogin = document.getElementById("form-login");
const loginError = document.getElementById("login-error");

// ============================================
// 1. GESTIÓN DE AUTENTICACIÓN JWT
// ============================================
function actualizarEstadoAuth() {
    if (authToken) {
        authIcon.textContent = "🔓";
        authText.textContent = `Salir (${currentAdminUser})`;
        adminBadge.textContent = `✓ Admin: ${currentAdminUser}`;
        adminBadge.className = "admin-badge logged-in";
    } else {
        authIcon.textContent = "🔒";
        authText.textContent = "Login Admin";
        adminBadge.textContent = "Modo Administrador Requerido";
        adminBadge.className = "admin-badge";
    }
}

btnAuthToggle.addEventListener("click", () => {
    if (authToken) {
        // Cerrar sesión
        authToken = null;
        currentAdminUser = null;
        sessionStorage.removeItem("admin_token");
        sessionStorage.removeItem("admin_user");
        actualizarEstadoAuth();
        imprimirTerminal("[SISTEMA] Sesión de administrador cerrada.", "system-line");
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
        if (!res.ok) throw new Error(data.error || "Error al autenticar");

        authToken = data.token;
        currentAdminUser = data.user;
        sessionStorage.setItem("admin_token", authToken);
        sessionStorage.setItem("admin_user", currentAdminUser);

        actualizarEstadoAuth();
        modalLogin.classList.add("hidden");
        imprimirTerminal(`[SISTEMA] ¡Bienvenido ${currentAdminUser}! Permisos RCON habilitados.`, "response-line");
    } catch (err) {
        loginError.textContent = `⚠️ ${err.message}`;
    }
});

// ============================================
// 2. CONSOLA RCON Y TERMINAL
// ============================================
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

        imprimirTerminal(`[${data.timestamp}] ${data.salida || "Comando ejecutado sin respuesta."}`, "response-line");
    } catch (err) {
        imprimirTerminal(`[ERROR] ${err.message}`, "error-line");
    }
}

formCommand.addEventListener("submit", (e) => {
    e.preventDefault();
    const cmd = inputCommand.value.trim();
    if (!cmd) return;
    enviarComandoRcon(cmd);
    inputCommand.value = "";
});

// Botones de acciones rápidas
document.querySelectorAll(".btn-quick").forEach(btn => {
    if (btn.id === "btn-trigger-backup") return;
    btn.addEventListener("click", async () => {
        const accion = btn.getAttribute("data-action");
        if (!authToken) {
            imprimirTerminal("⚠️ Debes iniciar sesión para ejecutar acciones rápidas.", "error-line");
            modalLogin.classList.remove("hidden");
            return;
        }

        try {
            imprimirTerminal(`> Ejecutando acción rápida: ${accion}...`, "cmd-line");
            const res = await fetch(`${API_BASE_URL}/api/minecraft/quick-command/${accion}`, {
                method: "POST",
                headers: { "Authorization": `Bearer ${authToken}` }
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.error || "Error");
            imprimirTerminal(`[${data.timestamp}] (${data.comando}) ${data.salida}`, "response-line");
        } catch (err) {
            imprimirTerminal(`[ERROR] ${err.message}`, "error-line");
        }
    });
});

// Respaldo de mundo
btnTriggerBackup.addEventListener("click", async () => {
    if (!authToken) {
        modalLogin.classList.remove("hidden");
        return;
    }
    imprimirTerminal("> Iniciando respaldo y sincronización a Amazon S3...", "cmd-line");
    try {
        const res = await fetch(`${API_BASE_URL}/api/minecraft/backup`, {
            method: "POST",
            headers: { "Authorization": `Bearer ${authToken}` }
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Error");
        imprimirTerminal(`✓ ${data.mensaje} | RCON: ${data.rcon_output}`, "response-line");
    } catch (err) {
        imprimirTerminal(`[ERROR] ${err.message}`, "error-line");
    }
});

// ============================================
// 3. CONSULTA DE USUARIOS Y ESTADO
// ============================================
async function verificarEstadoBackend() {
    try {
        const res = await fetch(`${API_BASE_URL}/api/saludo`);
        if (!res.ok) throw new Error();
        const data = await res.json();
        backendStatusText.textContent = "Backend: En Línea";
        storageBadge.textContent = `Storage: ${data.persistencia || "DynamoDB"}`;
    } catch {
        backendStatusText.textContent = "Backend: Desconectado";
        storageBadge.textContent = "Storage: Offline";
    }
}

async function obtenerUsuarios() {
    try {
        const res = await fetch(`${API_BASE_URL}/api/usuarios`);
        if (!res.ok) throw new Error("Error al consultar jugadores");
        const usuarios = await res.json();
        mostrarUsuarios(usuarios);
    } catch (error) {
        listaUsuarios.innerHTML = `<li class="user-item" style="color: #f87171;">Error al cargar jugadores (${error.message})</li>`;
    }
}

function mostrarUsuarios(usuarios) {
    listaUsuarios.innerHTML = "";
    if (usuarios.length === 0) {
        listaUsuarios.innerHTML = '<li class="user-item">No hay jugadores registrados</li>';
        return;
    }

    usuarios.forEach((u) => {
        const item = document.createElement("li");
        item.className = "user-item";
        item.innerHTML = `
            <div class="user-info">
                <span class="user-name">${u.nombre}</span>
                <span class="user-meta">${u.email}</span>
            </div>
            <div style="display: flex; align-items: center; gap: 0.75rem;">
                <span class="user-badge">🎮 ${u.gamertag || u.nombre}</span>
                <button class="btn-delete-player" title="Eliminar de DynamoDB y Whitelist" onclick="eliminarJugador('${u.email}', '${u.gamertag || u.nombre}')" style="background: rgba(239, 68, 68, 0.15); border: 1px solid rgba(239, 68, 68, 0.35); color: #f87171; border-radius: 6px; padding: 0.35rem 0.65rem; cursor: pointer; font-size: 0.85rem; transition: all 0.2s;">🗑️</button>
            </div>
        `;
        listaUsuarios.appendChild(item);
    });
}

async function eliminarJugador(email, gamertag) {
    if (!confirm(`¿Deseas eliminar a "${gamertag}" (${email}) de la Base de Datos y de la Whitelist de Minecraft?`)) {
        return;
    }

    try {
        mensaje.className = "alert-message";
        mensaje.textContent = `Eliminando a ${gamertag}...`;

        const res = await fetch(`${API_BASE_URL}/api/usuarios/${encodeURIComponent(email)}`, {
            method: "DELETE"
        });

        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Error al eliminar");

        mensaje.className = "alert-message alert-success";
        mensaje.textContent = `✓ ${data.mensaje}. Whitelist: ${data.minecraft_whitelist || "Removido"}`;
        
        imprimirTerminal(`[SISTEMA] Jugador ${gamertag} eliminado. RCON: ${data.minecraft_whitelist || "OK"}`, "response-line");
        obtenerUsuarios();
    } catch (err) {
        mensaje.className = "alert-message alert-error";
        mensaje.textContent = `❌ Error: ${err.message}`;
    }
}


async function crearUsuario(nombre, email, gamertag) {
    try {
        mensaje.className = "alert-message";
        mensaje.textContent = "Registrando en Base de Datos & Auto-Whitelist...";

        const res = await fetch(`${API_BASE_URL}/api/usuarios`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ nombre, email, gamertag }),
        });

        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Error al registrar");

        mensaje.className = "alert-message alert-success";
        mensaje.textContent = `✓ Registrado en ${data.storage || "Base de Datos"}. Whitelist: ${data.minecraft_whitelist || "OK"}`;
        
        formCrear.reset();
        obtenerUsuarios();
        consultarEstadoMinecraft();
    } catch (error) {
        mensaje.className = "alert-message alert-error";
        mensaje.textContent = `⚠️ Error: ${error.message}`;
    }
}

async function consultarEstadoMinecraft() {
    try {
        mcPlayersBox.textContent = "Consultando métricas en vivo...";
        const res = await fetch(`${API_BASE_URL}/api/minecraft/status`);
        if (!res.ok) throw new Error("No se pudo obtener el estado");
        const data = await res.json();
        if (data.minecraft_ip && mcIpText) {
            mcIpText.textContent = data.minecraft_ip;
        }
        mcPlayersBox.textContent = `[RCON State]\nJugadores: ${data.jugadores || "Sin jugadores"}\nTPS: ${data.tps || "20.0 (Estable)"}`;
    } catch (error) {
        mcPlayersBox.textContent = `⚠️ Error de conexión RCON (${error.message})`;
    }
}


// Event Listeners
btnConsultar.addEventListener("click", obtenerUsuarios);
btnRefrescarMc.addEventListener("click", consultarEstadoMinecraft);

formCrear.addEventListener("submit", (e) => {
    e.preventDefault();
    const nombre = document.getElementById("input-nombre").value.trim();
    const email = document.getElementById("input-email").value.trim();
    const gamertag = document.getElementById("input-gamertag").value.trim();
    crearUsuario(nombre, email, gamertag);
});

// Inicialización
document.addEventListener("DOMContentLoaded", () => {
    actualizarEstadoAuth();
    verificarEstadoBackend();
    obtenerUsuarios();
    consultarEstadoMinecraft();
});
