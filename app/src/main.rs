use axum::{response::IntoResponse, routing, Json, Router};
use clap::StructOpt;
use futures::future::{select, Either};
use futures::pin_mut;
use hyperlocal::UnixServerExt;
use serde::{Deserialize, Serialize};
use std::fmt::Display;
use std::os::unix::fs::MetadataExt;
use std::path::Path;
use std::process::exit;
use std::sync::Arc;
use std::{net::SocketAddr, path::PathBuf};
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
enum SockInfo {
    Unix(String),
    Tcp(u16),
}

impl Display for SockInfo {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Unix(path) => write!(f, "unix:/{}", path),
            Self::Tcp(port) => write!(f, "0.0.0.0:{}", port),
        }
    }
}

#[derive(Serialize, Deserialize, Clone)]
struct Config {
    pub satysfi: String,
    pub pdftoppm: String,
    pub satyh: String,
    pub workdir: String,
    pub capacity: usize,
    pub sock: SockInfo,
    pub healthcheck_sock: SockInfo,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            satysfi: "/usr/local/bin/satysfi".to_owned(),
            pdftoppm: "/usr/bin/pdftoppm".to_owned(),
            satyh: "/usr/share/satymathbot/empty.satyh".to_owned(),
            workdir: "/tmp/satymathbot".to_owned(),
            capacity: 4096,
            sock: SockInfo::Tcp(3000),
            healthcheck_sock: SockInfo::Tcp(3001),
        }
    }
}

enum Error {
    CreateSockDir(String, io::Error),
    RemoveSock(String, io::Error),
    TcpServer(u16, hyper::Error),
    UnixDomainSocketServer(String, hyper::Error),
    BindUnixDomainSocket(String, io::Error),
    ReadConfig(PathBuf, io::Error),
    LoadConfig(ron::Error),
    CreateWorkdir(String, io::Error),
    CopySatyh(String, String, io::Error),
}

impl From<satymathbot::PrepareError> for Error {
    fn from(e: satymathbot::PrepareError) -> Self {
        use satymathbot::PrepareError;
        match e {
            PrepareError::CopySatyh(from, to, e) => Error::CopySatyh(from, to, e),
            PrepareError::CreateDir(dir, e) => Error::CreateWorkdir(dir, e),
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

async fn prepare_sock(sock: &SockInfo) -> Result<(), Error> {
    if let SockInfo::Unix(path_str) = sock {
        let path = Path::new(path_str);
        if path.exists() {
            fs::remove_file(path)
                .await
                .map_err(|e| Error::RemoveSock(path_str.to_owned(), e))?;
        }
        if let Some(parent) = path.parent() {
            if !parent.exists() {
                fs::create_dir_all(path)
                    .await
                    .map_err(|e| Error::CreateSockDir(path_str.to_owned(), e))?;
            } else if let Ok(metadata) = fs::metadata(parent).await {
                info!(
                    "sockdir {:?}: perm: {:?}, uid: {}, gid: {}",
                    parent,
                    metadata.permissions(),
                    metadata.uid(),
                    metadata.gid()
                );
            }
        }
    }
    Ok(())
}

async fn run_hyper_server(sock: &SockInfo, router: Router) -> Result<(), Error> {
    match sock {
        SockInfo::Tcp(port) => {
            let addr = SocketAddr::from(([0, 0, 0, 0], *port));
            axum::Server::bind(&addr)
                .serve(router.into_make_service())
                .with_graceful_shutdown(shutdown_signal())
                .await
                .map_err(|e| Error::TcpServer(*port, e))
        }
        SockInfo::Unix(path) => axum::Server::bind_unix(path)
            .map_err(|e| Error::BindUnixDomainSocket(path.to_owned(), e))?
            .serve(router.into_make_service())
            .with_graceful_shutdown(shutdown_signal())
            .await
            .map_err(|e| Error::UnixDomainSocketServer(path.to_owned(), e)),
    }
}

async fn run_app_server(sock: &SockInfo, cfg: satymathbot::Config) -> Result<(), Error> {
    prepare_sock(sock).await?;
    let state = Arc::new(satymathbot::State::new(cfg));
    let app = axum::Router::new()
        .route("/:file", routing::get(satymathbot::endpoint))
        .layer(axum::AddExtensionLayer::new(state));
    run_hyper_server(sock, app).await
}

async fn run_healthcheck_server(sock: &SockInfo) -> Result<(), Error> {
    prepare_sock(sock).await?;
    let health = axum::Router::new().route("/", routing::get(health));
    run_hyper_server(sock, health).await
}

async fn run_server(cfg: Config) -> Result<(), Error> {
    let health = run_healthcheck_server(&cfg.healthcheck_sock);
    let app = run_app_server(&cfg.sock, cfg.clone().into());
    pin_mut!(health);
    pin_mut!(app);
    info!("app starts listening on {}", cfg.sock);
    info!("healthcheck starts listening on {}", cfg.healthcheck_sock);
    match select(health, app).await {
        Either::Left((r, _)) => r,
        Either::Right((r, _)) => r,
    }
}

async fn serve<P>(cfg_path: P) -> Result<(), Error>
where
    P: AsRef<Path>,
{
    let cfg_path = cfg_path.as_ref();
    let cfg = fs::read_to_string(cfg_path)
        .await
        .map_err(|e| Error::ReadConfig(cfg_path.to_owned(), e))?;
    let cfg: Config = ron::from_str(&cfg).map_err(Error::LoadConfig)?;
    satymathbot::prepare(&cfg.satyh, &cfg.workdir).await?;
    info!(
        "prepared env satyh: {}, workdir: {}",
        cfg.satyh, cfg.workdir
    );
    run_server(cfg).await
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    let opts = Parser::parse();
    match opts.serve {
        Some(cfg) => {
            if let Err(e) = serve(cfg).await {
                match e {
                    Error::BindUnixDomainSocket(path, e) => {
                        error!("bind unix socket {} due to {}", path, e)
                    }
                    Error::CreateSockDir(dir, e) => {
                        error!("create socket dir {} due to {}", dir, e)
                    }
                    Error::ReadConfig(path, e) => error!("read config {:?} due to {}", path, e),
                    Error::RemoveSock(path, e) => error!("remove sock {} due to {}", path, e),
                    Error::TcpServer(port, e) => {
                        error!("launch tcp server with port {} due to {}", port, e)
                    }
                    Error::UnixDomainSocketServer(sock, e) => {
                        error!("launch unix domain socket server on {} due to {}", sock, e)
                    }
                    Error::LoadConfig(e) => error!("load config due to {}", e),
                    Error::CreateWorkdir(dir, e) => {
                        error!("create working directory {} due to {}", dir, e)
                    }
                    Error::CopySatyh(from, to, e) => {
                        error!("copy satyh file {} to {} due to {}", from, to, e)
                    }
                }
                info!("exiting accidently");
                exit(-1);
            }
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
