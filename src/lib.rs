use askama::Template;
use axum::extract::{Extension, Query};
use axum::http::{HeaderMap, HeaderValue, StatusCode};
use axum::response::IntoResponse;
use image::{DynamicImage, GenericImageView, Pixel};
use std::process::ExitStatus;
use std::string;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::Mutex;
use tokio::{fs, io, process};
use tracing::warn;

#[derive(Debug, PartialEq, Clone)]
enum MathState {
    Error(String),
    Ready(Vec<u8>),
}

#[derive(askama::Template)]
#[template(path = "saty.jinja", escape = "none")]
struct SatyTemplate {
    math: String,
}

pub struct Config {
    workdir: String,
    satysfi: String,
    pdftoppm: String,
}

pub struct State {
    math: Mutex<lru::LruCache<String, MathState>>,
    cfg: Config,
}

impl State {
    pub fn new(workdir: String, satysfi: String, pdftoppm: String, cache_capacity: usize) -> Self {
        Self {
            math: Mutex::new(lru::LruCache::new(cache_capacity)),
            cfg: Config {
                workdir,
                satysfi,
                pdftoppm,
            },
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
    DecodePng(image::ImageError),
    EncodePng(image::ImageError),
    MathUndetected,
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

struct Area {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
}

fn detect_rendered_area(image: &DynamicImage) -> Option<Area> {
    let mut min_x = std::u32::MAX;
    let mut max_x = std::u32::MIN;
    let mut min_y = std::u32::MAX;
    let mut max_y = std::u32::MIN;
    let (w, h) = image.dimensions();
    for x in 0..w {
        for y in 0..h {
            let r = image.get_pixel(x, y).to_rgb().channels4().0;
            if r < 240 {
                min_x = min_x.min(x);
                max_x = max_x.max(x);
                min_y = min_y.min(y);
                max_y = max_y.max(y);
            }
        }
    }
    if max_x > min_x && max_y > min_y {
        Some(Area {
            x: min_x,
            y: min_y,
            w: max_x - min_x,
            h: max_y - min_y,
        })
    } else {
        None
    }
}

async fn handle(state: Arc<State>, base64_math: String) -> Result<MathState, Error> {
    let math = base64::decode_config(&base64_math, base64::URL_SAFE)
        .map_err(|e| Error::BadRequest(BadRequest::Base64(e)))?;
    let math = String::from_utf8(math).map_err(|e| Error::BadRequest(BadRequest::NoUnicode(e)))?;
    if let Some(result) = {
        let mut lock = state.math.lock().await;
        let inner = lock.get(&base64_math).cloned();
        drop(lock);
        inner
    } {
        Ok(result)
    } else {
        let saty_path = format!("{}/{}.saty", state.cfg.workdir, base64_math);
        let pdf_path = format!("{}/{}.pdf", state.cfg.workdir, base64_math);
        let pdtfoppm_target = format!("{}/{}", state.cfg.workdir, base64_math);
        let png_path = format!("{}/{}-1.png", state.cfg.workdir, base64_math);
        let mut file = fs::File::create(&saty_path)
            .await
            .map_err(|e| Error::Internal(InternalError::CreateFile(e)))?;
        let template = SatyTemplate { math };
        let rendered = template
            .render()
            .map_err(|e| Error::Internal(InternalError::Template(e)))?;
        file.write_all(rendered.as_bytes())
            .await
            .map_err(|e| Error::Internal(InternalError::WriteFile(e)))?;
        let satysfi_result = process::Command::new(&state.cfg.satysfi)
            .arg(&saty_path)
            .arg("-o")
            .arg(&pdf_path)
            .output()
            .await
            .map_err(|e| Error::Internal(InternalError::SpawnSatysfi(e)))?;

        if !satysfi_result.status.success() {
            let result =
                MathState::Error(String::from_utf8_lossy(&satysfi_result.stdout).to_string());
            state
                .math
                .lock()
                .await
                .put(base64_math.clone(), result.clone());
            return Ok(result);
        }
        let pdftoppm_result = process::Command::new(&state.cfg.pdftoppm)
            .arg("-png")
            .arg(&pdf_path)
            .arg(&pdtfoppm_target)
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
        let image = image::io::Reader::new(std::io::Cursor::new(buf))
            .with_guessed_format()
            .unwrap()
            .decode()
            .map_err(|e| Error::Internal(InternalError::DecodePng(e)))?;
        let area =
            detect_rendered_area(&image).ok_or(Error::Internal(InternalError::MathUndetected))?;
        let image = image.crop_imm(area.x, area.y, area.w, area.h);
        let mut image_buf = Vec::new();
        image
            .write_to(&mut image_buf, image::ImageOutputFormat::Png)
            .map_err(|e| Error::Internal(InternalError::EncodePng(e)))?;
        let result = MathState::Ready(image_buf);
        state.math.lock().await.put(base64_math, result.clone());
        Ok(result)
    }
}

pub async fn prepare(style_file: &str, workdir: &str) -> io::Result<()> {
    let to = format!("{}/empty.satyh", workdir);
    fs::copy(style_file, to).await.map(|_| ())
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
