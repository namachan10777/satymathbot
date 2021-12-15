use std::net::SocketAddr;
use std::sync::Arc;

use axum::routing;
use clap::StructOpt;
use tracing::{error, info};

#[derive(clap::Parser)]
#[clap(about, version, author)]
struct Parser {
    #[clap(short, long)]
    workdir: String,
    #[clap(short = 's', long)]
    style_file: String,
    #[clap(short = 'b', long)]
    satysfi_bin: String,
    #[clap(short = 'p', long)]
    pdftoppn_bin: String,
    #[clap(short, long, default_value = "10000")]
    capacity: usize,
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

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    let opts = Parser::parse();
    info!(
        "Start {}, {}, {}",
        opts.satysfi_bin, opts.style_file, opts.workdir
    );
    let state = Arc::new(satymathbot::State::new(
        opts.workdir.clone(),
        opts.satysfi_bin,
        opts.pdftoppn_bin,
        10000,
    ));
    if let Err(e) = satymathbot::prepare(&opts.style_file, &opts.workdir).await {
        error!("Cannot prepare environment due to {:?}", e);
    } else {
        info!("Prepared environment")
    }

    let app = axum::Router::new()
        .route("/", routing::get(satymathbot::endpoint))
        .layer(axum::AddExtensionLayer::new(state));
    let addr = SocketAddr::from(([127, 0, 0, 1], 8080));
    info!("Listen on {}", addr);
    if let Err(e) = axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .with_graceful_shutdown(shutdown_signal())
        .await
    {
        error!("Server exited accidently: {:?}", e);
    }
}
