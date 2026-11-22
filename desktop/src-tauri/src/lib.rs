//! App desktop do Mynik: a web (`../web`, exportação estática) numa janela
//! nativa, com o que um browser não dá — ícone no tray com as vendas de hoje
//! e gasto rápido, atalho global para o ⌘K, notificações do sistema, arranque
//! com o sistema e login por deep link (`mynik://auth/callback`).
//!
//! A web fala com esta camada por `window.__TAURI__` (ver `web/src/lib/desktop.ts`).

use std::sync::Mutex;

use tauri::image::Image;
use tauri::menu::{CheckMenuItem, Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Emitter, Manager, RunEvent, WindowEvent, Wry};
use tauri_plugin_autostart::{MacosLauncher, ManagerExt as _};
use tauri_plugin_deep_link::DeepLinkExt;
use tauri_plugin_notification::NotificationExt;
use tauri_plugin_opener::OpenerExt;

const TRAY_ID: &str = "mynik";
/// Atalho global para procurar (⌘K dentro da app): ⇧⌘K no Mac, Ctrl+Shift+K no Windows.
const SEARCH_SHORTCUT: &str = "CommandOrControl+Shift+K";

/// Estado partilhado: o item das vendas no menu do tray e o deep link que
/// chegou antes de a página estar pronta (arranque a frio pelo link do email).
struct Shared {
    sales_item: MenuItem<Wry>,
    autostart_item: CheckMenuItem<Wry>,
    pending_link: Mutex<Option<String>>,
}

fn show_main(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.unminimize();
        let _ = window.show();
        let _ = window.set_focus();
    }
}

/// Mostra a janela e pede à web uma ação (abrir o ⌘K, ir para uma página).
fn show_and_emit(app: &AppHandle, event: &str, payload: &str) {
    show_main(app);
    let _ = app.emit(event, payload.to_string());
}

fn handle_links(app: &AppHandle, urls: Vec<String>) {
    for url in urls {
        if let Some(shared) = app.try_state::<Shared>() {
            *shared.pending_link.lock().unwrap() = Some(url.clone());
        }
        show_and_emit(app, "mynik://deep-link", &url);
    }
}

// ---------- Comandos chamados pela web ----------

#[tauri::command]
fn notify(app: AppHandle, title: String, body: String) -> Result<(), String> {
    app.notification().builder().title(title).body(body).show().map_err(|e| e.to_string())
}

/// Texto das vendas de hoje no tray (no Mac também ao lado do ícone).
#[tauri::command]
fn set_tray_sales(app: AppHandle, text: String, short: Option<String>) -> Result<(), String> {
    let shared = app.state::<Shared>();
    shared.sales_item.set_text(&text).map_err(|e| e.to_string())?;
    if let Some(tray) = app.tray_by_id(TRAY_ID) {
        let _ = tray.set_tooltip(Some(format!("Mynik · {text}")));
        #[cfg(target_os = "macos")]
        let _ = tray.set_title(short.filter(|s| !s.is_empty()));
        #[cfg(not(target_os = "macos"))]
        let _ = short;
    }
    Ok(())
}

/// Lê um endereço sem as restrições de CORS do browser (calendário iCal).
#[tauri::command]
async fn fetch_text(url: String) -> Result<String, String> {
    if !(url.starts_with("https://") || url.starts_with("http://")) {
        return Err("Só endereços http(s)".into());
    }
    let response = reqwest::get(&url).await.map_err(|e| e.to_string())?;
    if !response.status().is_success() {
        return Err(format!("O servidor respondeu {}", response.status()));
    }
    response.text().await.map_err(|e| e.to_string())
}

#[tauri::command]
fn autostart_enabled(app: AppHandle) -> bool {
    app.autolaunch().is_enabled().unwrap_or(false)
}

#[tauri::command]
fn set_autostart(app: AppHandle, enabled: bool) -> Result<(), String> {
    let launcher = app.autolaunch();
    let result = if enabled { launcher.enable() } else { launcher.disable() };
    result.map_err(|e| e.to_string())?;
    let _ = app.state::<Shared>().autostart_item.set_checked(enabled);
    Ok(())
}

/// O deep link que abriu a app (a página pede-o quando fica pronta).
#[tauri::command]
fn take_pending_link(app: AppHandle) -> Option<String> {
    app.state::<Shared>().pending_link.lock().unwrap().take()
}

#[tauri::command]
fn open_external(app: AppHandle, url: String) -> Result<(), String> {
    if !(url.starts_with("https://") || url.starts_with("http://") || url.starts_with("mailto:")) {
        return Err("Endereço não suportado".into());
    }
    app.opener().open_url(url, None::<&str>).map_err(|e| e.to_string())
}

// ---------- Tray ----------

fn build_tray(app: &AppHandle) -> tauri::Result<Shared> {
    let sales = MenuItem::with_id(app, "sales", "Vendas hoje: —", false, None::<&str>)?;
    let expense = MenuItem::with_id(app, "expense", "Gasto rápido…", true, None::<&str>)?;
    let search = MenuItem::with_id(app, "search", "Procurar…", true, Some(SEARCH_SHORTCUT))?;
    let store = MenuItem::with_id(app, "store", "Abrir a Loja", true, None::<&str>)?;
    let open = MenuItem::with_id(app, "open", "Abrir o Mynik", true, None::<&str>)?;
    let autostart = CheckMenuItem::with_id(app, "autostart", "Iniciar com o sistema", true, app.autolaunch().is_enabled().unwrap_or(false), None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Sair do Mynik", true, Some("CommandOrControl+Q"))?;
    let menu = Menu::with_items(app, &[
        &sales,
        &PredefinedMenuItem::separator(app)?,
        &expense,
        &search,
        &store,
        &open,
        &PredefinedMenuItem::separator(app)?,
        &autostart,
        &quit,
    ])?;

    #[cfg(target_os = "macos")]
    let (icon, template) = (Image::from_bytes(include_bytes!("../icons/tray-template.png"))?, true);
    #[cfg(not(target_os = "macos"))]
    let (icon, template) = (Image::from_bytes(include_bytes!("../icons/32x32.png"))?, false);

    TrayIconBuilder::with_id(TRAY_ID)
        .icon(icon)
        .icon_as_template(template)
        .tooltip("Mynik")
        .menu(&menu)
        .show_menu_on_left_click(cfg!(target_os = "macos"))
        .on_menu_event(|app, event| match event.id().as_ref() {
            "expense" => show_and_emit(app, "mynik://navigate", "/financas/?novo=gasto"),
            "search" => show_and_emit(app, "mynik://command-menu", ""),
            "store" => show_and_emit(app, "mynik://navigate", "/loja/"),
            "open" => show_main(app),
            "autostart" => {
                let launcher = app.autolaunch();
                let enabled = !launcher.is_enabled().unwrap_or(false);
                let _ = if enabled { launcher.enable() } else { launcher.disable() };
                let _ = app.state::<Shared>().autostart_item.set_checked(enabled);
                let _ = app.emit("mynik://autostart", enabled);
            }
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            // No Windows o clique esquerdo abre a janela (o menu fica no direito).
            if let TrayIconEvent::Click { button: MouseButton::Left, button_state: MouseButtonState::Up, .. } = event {
                if !cfg!(target_os = "macos") {
                    show_main(tray.app_handle());
                }
            }
        })
        .build(app)?;

    Ok(Shared { sales_item: sales, autostart_item: autostart, pending_link: Mutex::new(None) })
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let mut builder = tauri::Builder::default();

    #[cfg(desktop)]
    {
        use tauri_plugin_global_shortcut::{Builder as ShortcutBuilder, ShortcutState};
        // Uma só instância: um segundo arranque (ou um deep link no Windows) traz a janela.
        builder = builder
            .plugin(tauri_plugin_single_instance::init(|app, _argv, _cwd| show_main(app)))
            .plugin(
                ShortcutBuilder::new()
                    .with_shortcuts([SEARCH_SHORTCUT])
                    .expect("atalho global inválido")
                    .with_handler(|app, _shortcut, event| {
                        if event.state == ShortcutState::Pressed {
                            show_and_emit(app, "mynik://command-menu", "");
                        }
                    })
                    .build(),
            );
    }

    let app = builder
        .plugin(tauri_plugin_deep_link::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_autostart::init(MacosLauncher::LaunchAgent, Some(vec!["--minimized"])))
        .invoke_handler(tauri::generate_handler![
            notify,
            set_tray_sales,
            fetch_text,
            autostart_enabled,
            set_autostart,
            take_pending_link,
            open_external
        ])
        .setup(|app| {
            let handle = app.handle().clone();
            let shared = build_tray(&handle)?;
            app.manage(shared);

            // Login: o link do email abre mynik://auth/callback#access_token=…
            #[cfg(any(windows, target_os = "linux"))]
            let _ = app.deep_link().register_all();
            if let Ok(Some(urls)) = app.deep_link().get_current() {
                handle_links(&handle, urls.into_iter().map(|u| u.to_string()).collect());
            }
            let links = handle.clone();
            app.deep_link().on_open_url(move |event| {
                handle_links(&links, event.urls().into_iter().map(|u| u.to_string()).collect());
            });

            // Ao iniciar com o sistema, abre só no tray.
            if std::env::args().any(|a| a == "--minimized") {
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window.hide();
                }
            }
            Ok(())
        })
        .on_window_event(|window, event| {
            // Fechar a janela deixa o Mynik no tray (avisos de vendas e contas continuam).
            if let WindowEvent::CloseRequested { api, .. } = event {
                if window.label() == "main" {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .build(tauri::generate_context!())
        .expect("erro ao iniciar o Mynik");

    app.run(|app, event| {
        // macOS: clicar no ícone da Dock com a janela escondida volta a mostrá-la.
        #[cfg(target_os = "macos")]
        if let RunEvent::Reopen { .. } = event {
            show_main(app);
        }
        #[cfg(not(target_os = "macos"))]
        let _ = (app, event);
    });
}
