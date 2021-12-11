use clap::StructOpt;
use tracing::info;

#[derive(clap::Parser)]
#[clap(about, version, author)]
struct Parser {
    #[clap(short, long)]
    workdir: String,
    #[clap(short = 's', long)]
    style_file: Option<String>,
    #[clap(short = 'b', long)]
    satysfi_bin: String,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    let opts = Parser::parse();
    let style_file = opts
        .style_file
        .unwrap_or_else(|| format!("{}/satymathbot.satyh", opts.workdir));
    info!(
        "Start {}, {}, {}",
        opts.satysfi_bin, style_file, opts.workdir
    );
}
