use axum::{response::IntoResponse, routing, Json};
use clap::StructOpt;
use hyperlocal::UnixServerExt;
use serde::{Deserialize, Serialize};
use std::path::Path;
use std::process::exit;
use std::sync::Arc;
use tokio::{fs, io};
use tracing::{error, info};

#[derive(clap::Parser)]
#[clap(about, version, author)]
struct Parser {
    #[clap(
        short,
        long,
        conflicts_with("example"),
        required_unless_present("example")
    )]
    serve: Option<String>,
    #[clap(short, long)]
    example: bool,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Config {
    pub satysfi: String,
    pub pdftoppm: String,
    pub satyh: String,
    pub workdir: String,
    pub capacity: usize,
    pub sock_path: String,
    pub healthcheck_sock_path: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            satysfi: "/usr/local/bin/satysfi".to_owned(),
            pdftoppm: "/usr/bin/pdftoppm".to_owned(),
            satyh: "/usr/share/satymathbot/empty.satyh".to_owned(),
            workdir: "/tmp/satymathbot".to_owned(),
            capacity: 4096,
            sock_path: "/var/run/saytmathbot/app.sock".to_owned(),
            healthcheck_sock_path: "/var/run/satymathbot/app_health.sock".to_owned(),
        }
    }
}

impl From<Config> for satymathbot::Config {
    fn from(cfg: Config) -> Self {
        Self {
            capacity: cfg.capacity,
            workdir: cfg.workdir,
            satysfi: cfg.satysfi,
            pdftoppm: cfg.pdftoppm,
        }
    }
}

pub async fn shutdown_signal() {
    use std::io;
    use tokio::signal::unix::SignalKind;

    async fn terminate() -> io::Result<()> {
        tokio::signal::unix::signal(SignalKind::terminate())?
            .recv()
            .await;
        Ok(())
    }

    tokio::select! {
        _ = terminate() => {},
        _ = tokio::signal::ctrl_c() => {},
    }
    info!("signal received, starting graceful shutdown")
}

#[derive(Serialize)]
enum HealthStatus {
    Ok,
}

#[derive(Serialize)]
struct HealthResponse {
    status: HealthStatus,
}

async fn health() -> impl IntoResponse {
    Json(HealthResponse {
        status: HealthStatus::Ok,
    })
}

async fn prepare_env(cfg: &Config) {
    if let Err(e) = satymathbot::prepare(&cfg.satyh, &cfg.workdir).await {
        error!("Cannot prepare environment due to {:?}", e);
        exit(-1);
    } else {
        info!("Prepared environment")
    }
}

async fn clear_socket<P>(app: P, health: P) -> io::Result<()>
where
    P: AsRef<Path>,
{
    if app.as_ref().exists() {
        fs::remove_file(app).await?;
    }
    if health.as_ref().exists() {
        fs::remove_file(health).await?;
    }
    Ok(())
}

async fn run_server(cfg: Config) {
    let state = Arc::new(satymathbot::State::new(cfg.clone().into()));
    clear_socket(&cfg.sock_path, &cfg.healthcheck_sock_path)
        .await
        .unwrap_or_else(|e| {
            error!("Cannot clean up sockets due to {}", e);
            exit(-1);
        });
    let app = axum::Router::new()
        .route("/:file", routing::get(satymathbot::endpoint))
        .route("/health", routing::get(health))
        .layer(axum::AddExtensionLayer::new(state));
    let health = axum::Router::new().route("/", routing::get(health));
    info!("Listen on {}", cfg.sock_path);
    let healthcheck_sock_path = cfg.healthcheck_sock_path.to_owned();
    tokio::spawn(async move {
        if let Err(e) = axum::Server::bind_unix(healthcheck_sock_path.clone())
            .unwrap_or_else(|e| {
                error!(
                    "Cannot bind unix socket {} due to {}",
                    healthcheck_sock_path, e
                );
                exit(-1);
            })
            .serve(health.into_make_service())
            .with_graceful_shutdown(shutdown_signal())
            .await
        {
            error!("Health server exited accidently: {:?}", e);
            exit(-1);
        }
    });
    if let Err(e) = axum::Server::bind_unix(&cfg.sock_path)
        .unwrap_or_else(|e| {
            error!("Cannot bind unix socket {} due to {}", cfg.sock_path, e);
            exit(-1);
        })
        .serve(app.into_make_service())
        .with_graceful_shutdown(shutdown_signal())
        .await
    {
        error!("Server exited accidently: {:?}", e);
        exit(-1);
    }
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    let opts = Parser::parse();
    match opts.serve {
        Some(cfg) => {
            let cfg = fs::read_to_string(&cfg).await.unwrap_or_else(|e| {
                error!("Cannot read config file {} due to {:?}", cfg, e);
                exit(-1);
            });
            let cfg: Config = ron::from_str(&cfg).unwrap_or_else(|e| {
                error!("Invalid config file ({:?})", e);
                exit(-1);
            });
            prepare_env(&cfg).await;
            run_server(cfg).await;
        }
        None => {
            let pretty_cfg = ron::ser::PrettyConfig::new();
            println!(
                "{}",
                ron::ser::to_string_pretty(&Config::default(), pretty_cfg).unwrap()
            );
        }
    }
}
