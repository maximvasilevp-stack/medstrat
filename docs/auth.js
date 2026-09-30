// Medstrat site: sign-in with a nickname and password.
//
// Two modes, chosen by API_BASE:
//   ""            - browser-only profiles: accounts are stored in this browser's localStorage,
//                   passwords are hashed with PBKDF2 and never leave the device.
//   "https://..." - a Medstrat account server (server/ in the repo): POST /api/register,
//                   POST /api/login, GET /api/me with a bearer token.
const API_BASE = "";

const $ = (id) => document.getElementById(id);
const SESSION_KEY = "medstrat_session";
const USERS_KEY = "medstrat_users";
let mode = "login";

function session() {
  try { return JSON.parse(localStorage.getItem(SESSION_KEY) || "null"); } catch (e) { return null; }
}
function setSession(s) {
  try { s ? localStorage.setItem(SESSION_KEY, JSON.stringify(s)) : localStorage.removeItem(SESSION_KEY); } catch (e) {}
}

async function pbkdf2(password, saltHex) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", enc.encode(password), "PBKDF2", false, ["deriveBits"]);
  const salt = Uint8Array.from(saltHex.match(/.{2}/g).map((h) => parseInt(h, 16)));
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", salt, iterations: 120000, hash: "SHA-256" }, key, 256);
  return Array.from(new Uint8Array(bits)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
function randomHex(n) {
  return Array.from(crypto.getRandomValues(new Uint8Array(n))).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// ---- browser-only mode
async function localRegister(nick, password) {
  const users = JSON.parse(localStorage.getItem(USERS_KEY) || "{}");
  if (users[nick.toLowerCase()]) throw new Error("Такой ник уже занят в этом браузере");
  const salt = randomHex(16);
  users[nick.toLowerCase()] = { nick, salt, hash: await pbkdf2(password, salt), created: Date.now() };
  localStorage.setItem(USERS_KEY, JSON.stringify(users));
  return { nick, token: "local" };
}
async function localLogin(nick, password) {
  const users = JSON.parse(localStorage.getItem(USERS_KEY) || "{}");
  const u = users[nick.toLowerCase()];
  if (!u) throw new Error("Ник не найден: зарегистрируйтесь");
  if ((await pbkdf2(password, u.salt)) !== u.hash) throw new Error("Неверный пароль");
  return { nick: u.nick, token: "local" };
}

// ---- server mode
async function api(path, body, token) {
  const r = await fetch(API_BASE + path, {
    method: body ? "POST" : "GET",
    headers: Object.assign({ "Content-Type": "application/json" }, token ? { Authorization: "Bearer " + token } : {}),
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(data.error || "Сервер недоступен");
  return data;
}

async function submit() {
  const nick = $("nick").value.trim();
  const password = $("password").value;
  const msg = $("auth-msg");
  msg.className = "msg";
  if (!/^[\p{L}\p{N}_ -]{2,16}$/u.test(nick)) { msg.className = "msg err"; msg.textContent = "Ник: 2–16 букв, цифр, пробелов или _"; return; }
  if (password.length < 4) { msg.className = "msg err"; msg.textContent = "Пароль не короче 4 символов"; return; }
  $("auth-submit").disabled = true;
  try {
    let s;
    if (API_BASE) {
      s = await api(mode === "login" ? "/api/login" : "/api/register", { nick, password });
    } else {
      s = mode === "login" ? await localLogin(nick, password) : await localRegister(nick, password);
    }
    setSession(s);
    msg.className = "msg ok";
    msg.textContent = mode === "login" ? "Добро пожаловать, " + s.nick + "!" : "Аккаунт создан. Удачи, " + s.nick + "!";
    setTimeout(() => { closeModal(); render(); }, 600);
  } catch (e) {
    msg.className = "msg err";
    msg.textContent = e.message;
  } finally {
    $("auth-submit").disabled = false;
  }
}

function setMode(m) {
  mode = m;
  $("auth-title").textContent = m === "login" ? "С возвращением" : "Новый игрок";
  $("tab-login").classList.toggle("active", m === "login");
  $("tab-register").classList.toggle("active", m === "register");
  $("auth-submit").textContent = m === "login" ? "Войти" : "Создать аккаунт";
  $("password").autocomplete = m === "login" ? "current-password" : "new-password";
  $("auth-msg").textContent = "";
}
function openModal(m) { setMode(m); $("auth-modal").classList.add("open"); $("nick").focus(); }
function closeModal() { $("auth-modal").classList.remove("open"); }

function render() {
  const s = session();
  const box = $("userbox");
  const plays = [$("play-btn"), $("play-btn-2")].filter(Boolean);
  if (s) {
    box.innerHTML = '<span class="nick"></span> <button class="btn small ghost" id="logout">Выйти</button>';
    box.querySelector(".nick").textContent = s.nick;
    $("logout").onclick = () => { setSession(null); render(); };
    for (const play of plays) {
      play.href = "play.html?nick=" + encodeURIComponent(s.nick);
      play.textContent = "▶ Играть за " + s.nick;
    }
  } else {
    box.innerHTML = '<button class="btn small ghost" id="login-btn">Войти</button> <button class="btn small primary" id="register-btn">Регистрация</button>';
    $("login-btn").onclick = () => openModal("login");
    $("register-btn").onclick = () => openModal("register");
    for (const play of plays) {
      play.href = "play.html";
      play.textContent = "▶ Играть";
    }
  }
  $("auth-hint").textContent = API_BASE
    ? "Аккаунт хранится на сервере игры."
    : "Аккаунт хранится только в этом браузере: пароль никуда не отправляется.";
}

$("tab-login").onclick = () => setMode("login");
$("tab-register").onclick = () => setMode("register");
$("auth-submit").onclick = submit;
$("auth-cancel").onclick = closeModal;
$("password").addEventListener("keydown", (e) => { if (e.key === "Enter" || e.keyCode === 13) { e.preventDefault(); submit(); } });
$("nick").addEventListener("keydown", (e) => { if (e.key === "Enter" || e.keyCode === 13) { e.preventDefault(); $("password").focus(); } });
$("auth-modal").addEventListener("click", (e) => { if (e.target === $("auth-modal")) closeModal(); });
render();
