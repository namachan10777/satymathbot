use askama::Template;
use axum::extract::{Extension, Query};
use axum::http::{HeaderMap, HeaderValue, StatusCode};
use axum::response::IntoResponse;
use std::collections::HashMap;
use std::process::ExitStatus;
use std::string;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::RwLock;
use tokio::{fs, io, process};
use tracing::warn;

#[derive(Debug, PartialEq, Clone)]
enum MathState {
    #[allow(dead_code)]
    Error(String),
    #[allow(dead_code)]
    Ready(Vec<u8>),
}

#[derive(askama::Template)]
#[template(path = "saty.jinja")]
struct SatyTemplate {
    satyh: String,
    math: String,
}

pub struct State {
    math: RwLock<HashMap<String, MathState>>,
    workdir: String,
    satysfi: String,
    #[allow(dead_code)]
    pdftoppm: String,
    satyh: String,
}

impl State {
    pub fn new(workdir: String, satysfi: String, satyh: String, pdftoppm: String) -> Self {
        Self {
            math: RwLock::new(HashMap::new()),
            workdir,
            satysfi,
            satyh,
            pdftoppm,
        }
    }
}

#[derive(Debug)]
enum InternalError {
    CreateFile(io::Error),
    Template(askama::Error),
    WriteFile(io::Error),
    SpawnSatysfi(io::Error),
    SpawnPdftoppm(io::Error),
    ExecutePdftoppm(ExitStatus, String),
    OpenPng(io::Error),
    ReadPng(io::Error),
}

#[derive(Debug)]
enum BadRequest {
    Base64(base64::DecodeError),
    NoUnicode(string::FromUtf8Error),
}

#[derive(Debug)]
enum Error {
    BadRequest(BadRequest),
    Internal(InternalError),
}

async fn handle(state: Arc<State>, base64_math: String) -> Result<MathState, Error> {
    let math = base64::decode_config(&base64_math, base64::URL_SAFE)
        .map_err(|e| Error::BadRequest(BadRequest::Base64(e)))?;
    let math = String::from_utf8(math).map_err(|e| Error::BadRequest(BadRequest::NoUnicode(e)))?;
    if let Some(result) = { state.math.read().await.get(&math).cloned() } {
        Ok(result)
    } else {
        let saty_path = format!("{}/{}.saty", state.workdir, base64_math);
        let pdf_path = format!("{}/{}.pdf", state.workdir, base64_math);
        let png_path = format!("{}/{}.png", state.workdir, base64_math);
        let mut file = fs::File::create(&saty_path)
            .await
            .map_err(|e| Error::Internal(InternalError::CreateFile(e)))?;
        let template = SatyTemplate {
            math,
            satyh: state.satyh.clone(),
        };
        let rendered = template
            .render()
            .map_err(|e| Error::Internal(InternalError::Template(e)))?;
        file.write_all(rendered.as_bytes())
            .await
            .map_err(|e| Error::Internal(InternalError::WriteFile(e)))?;
        let satysfi_result = process::Command::new(&state.satysfi)
            .arg(&saty_path)
            .arg("-o")
            .arg(&pdf_path)
            .output()
            .await
            .map_err(|e| Error::Internal(InternalError::SpawnSatysfi(e)))?;

        if !satysfi_result.status.success() {
            let result =
                MathState::Error(String::from_utf8_lossy(&satysfi_result.stderr).to_string());
            state
                .math
                .write()
                .await
                .insert(base64_math.clone(), result.clone());
            return Ok(result);
        }
        let pdftoppm_result = process::Command::new(&state.pdftoppm)
            .arg("-png")
            .arg(&png_path)
            .arg(&pdf_path)
            .output()
            .await
            .map_err(|e| Error::Internal(InternalError::SpawnPdftoppm(e)))?;
        if !pdftoppm_result.status.success() {
            return Err(Error::Internal(InternalError::ExecutePdftoppm(
                pdftoppm_result.status,
                String::from_utf8_lossy(&pdftoppm_result.stderr).to_string(),
            )));
        }
        let mut orig_png = fs::File::open(&png_path)
            .await
            .map_err(|e| Error::Internal(InternalError::OpenPng(e)))?;
        let mut buf = Vec::new();
        orig_png
            .read_to_end(&mut buf)
            .await
            .map_err(|e| Error::Internal(InternalError::ReadPng(e)))?;
        let result = MathState::Ready(buf);
        state.math.write().await.insert(base64_math, result.clone());
        Ok(result)
    }
}

#[derive(serde::Deserialize)]
pub struct Params {
    math: String,
}

pub async fn endpoint(
    Extension(state): Extension<Arc<State>>,
    Query(params): Query<Params>,
) -> impl IntoResponse {
    match handle(state, params.math).await {
        Ok(MathState::Ready(img)) => {
            let mut headers = HeaderMap::new();
            headers.append("Content-Type", HeaderValue::from_static("image/png"));
            (StatusCode::ACCEPTED, headers, img)
        }
        Ok(MathState::Error(errmsg)) => {
            let mut headers = HeaderMap::new();
            headers.append("Content-Type", HeaderValue::from_static("text/plain"));
            (StatusCode::BAD_REQUEST, headers, errmsg.as_bytes().to_vec())
        }
        Err(Error::BadRequest(e)) => {
            let mut headers = HeaderMap::new();
            headers.append("Content-Type", HeaderValue::from_static("text/plain"));
            (
                StatusCode::BAD_REQUEST,
                headers,
                format!("Error: {:?}", e).as_bytes().to_vec(),
            )
        }
        Err(Error::Internal(e)) => {
            warn!("{:?}", e);
            let mut headers = HeaderMap::new();
            headers.append("Content-Type", HeaderValue::from_static("text/plain"));
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                headers,
                format!("Error: {:?}", e).as_bytes().to_vec(),
            )
        }
    }
}
