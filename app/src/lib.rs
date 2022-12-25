use askama::Template;
use axum::extract::{Path, State};
use axum::http::{HeaderMap, HeaderValue, StatusCode};
use axum::response::IntoResponse;
use image::{DynamicImage, GenericImageView, ImageOutputFormat, Pixel, Rgba, RgbaImage};
use moka::future::Cache;
use std::process::ExitStatus;
use std::string;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::{fs, io, process};
use tracing::{info, warn};

#[derive(Debug, PartialEq, Clone)]
enum MathState {
    Error(String),
    Ready { img: RgbaImage },
}

#[derive(askama::Template)]
#[template(path = "saty.jinja", escape = "none")]
struct SatyTemplate {
    math: String,
}

#[derive(Clone)]
pub struct Config {
    pub capacity: u64,
    pub workdir: String,
    pub satysfi: String,
    pub pdftoppm: String,
}

#[derive(Clone)]
pub struct AppState {
    math: Arc<Cache<String, MathState>>,
    cfg: Config,
}

impl AppState {
    pub fn new(cfg: Config) -> Self {
        Self {
            math: Arc::new(Cache::new(cfg.capacity)),
            cfg,
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
    MathUndetected,
    DeleteFile(String, io::Error),
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

#[derive(Clone, Copy, Debug, Default)]
struct TextColor {
    r: u8,
    g: u8,
    b: u8,
}

use nom::bytes::complete::take_while_m_n;
use nom::combinator::map_res;
use nom::sequence::tuple;
use nom::IResult;

fn from_hex(input: &str) -> Result<u8, std::num::ParseIntError> {
    u8::from_str_radix(input, 16)
}

fn is_hex_digit(c: char) -> bool {
    c.is_digit(16)
}

fn hex_primary(input: &str) -> IResult<&str, u8> {
    map_res(take_while_m_n(2, 2, is_hex_digit), from_hex)(input)
}

fn hex_short(input: &str) -> IResult<&str, u8> {
    let (input, x) = map_res(take_while_m_n(1, 1, is_hex_digit), from_hex)(input)?;
    Ok((input, x << 4))
}

impl TextColor {
    fn parse_from_str(src: &str) -> Option<Self> {
        if let Ok((_, (r, g, b))) = tuple((hex_primary, hex_primary, hex_primary))(src) {
            Some(Self { r, g, b })
        } else if let Ok((_, (r, g, b))) = tuple((hex_short, hex_short, hex_short))(src) {
            Some(Self { r, g, b })
        } else {
            None
        }
    }

    fn invert(self) -> Self {
        Self {
            r: 255 - self.r,
            g: 255 - self.g,
            b: 255 - self.b,
        }
    }
}

fn convert(img: &mut RgbaImage, to: TextColor) {
    let (w, h) = img.dimensions();
    for x in 0..w {
        for y in 0..h {
            let to_inv = to.invert();
            let Rgba([_, _, _, a]) = img.get_pixel(x, y);
            let r = 255 - (to_inv.r as f64 * (*a as f64 / 255.0)) as u8;
            let g = 255 - (to_inv.g as f64 * (*a as f64 / 255.0)) as u8;
            let b = 255 - (to_inv.b as f64 * (*a as f64 / 255.0)) as u8;
            let pixel = Rgba([r, g, b, *a]);
            img.put_pixel(x, y, pixel);
        }
    }
}

fn alpha(img: &mut RgbaImage) {
    let (w, h) = img.dimensions();
    for x in 0..w {
        for y in 0..h {
            let Rgba([r, g, b, _]) = img.get_pixel(x, y);
            let (r, g, b) = (*r as f64, *g as f64, *b as f64);
            let darkness = 1.0 - (r * r + g * g + b * b).sqrt() / (255.0 * 255.0 * 3.0_f64).sqrt();
            let a = (255.0 * darkness) as u8;
            let pixel = Rgba([r as u8, g as u8, b as u8, a]);
            img.put_pixel(x, y, pixel);
        }
    }
}

async fn handle(state: AppState, query: Query) -> Result<MathState, Arc<Error>> {
    let base64_math = query.base64();
    let math = base64::decode_config(&base64_math, base64::URL_SAFE)
        .map_err(|e| Error::BadRequest(BadRequest::Base64(e)))?;
    let math = String::from_utf8(math).map_err(|e| Error::BadRequest(BadRequest::NoUnicode(e)))?;
    let proc = async {
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
            return Ok(MathState::Error(
                String::from_utf8_lossy(&satysfi_result.stdout).to_string(),
            ));
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
        fs::remove_file(&saty_path)
            .await
            .map_err(|e| Error::Internal(InternalError::DeleteFile(saty_path, e)))?;
        fs::remove_file(&pdf_path)
            .await
            .map_err(|e| Error::Internal(InternalError::DeleteFile(pdf_path, e)))?;
        fs::remove_file(&png_path)
            .await
            .map_err(|e| Error::Internal(InternalError::DeleteFile(png_path, e)))?;
        let img = image.crop_imm(area.x, area.y, area.w, area.h);
        let mut img = img.to_rgba8();
        alpha(&mut img);
        Ok(MathState::Ready { img })
    };
    state
        .math
        .get_or_try_insert_with(base64_math.to_owned(), proc)
        .await
}

pub enum PrepareError {
    CreateDir(String, io::Error),
    CopySatyh(String, String, io::Error),
}

#[derive(serde::Deserialize)]
pub struct URLQuery {
    #[serde(default)]
    color: Option<String>,
}

pub async fn prepare(style_file: &str, workdir: &str) -> Result<(), PrepareError> {
    let path = std::path::Path::new(workdir);
    if !path.exists() {
        fs::create_dir_all(path)
            .await
            .map_err(|e| PrepareError::CreateDir(workdir.to_owned(), e))?;
    }
    let to = format!("{}/empty.satyh", workdir);
    fs::copy(style_file, to.clone())
        .await
        .map(|_| ())
        .map_err(|e| PrepareError::CopySatyh(style_file.to_owned(), to, e))
}

#[derive(Clone)]
enum Query {
    Png(String),
    Jpeg(String),
}

impl Query {
    fn base64(&self) -> &str {
        match self {
            Query::Png(inner) => inner.as_str(),
            Query::Jpeg(inner) => inner.as_str(),
        }
    }
}

fn text_response(src: &str, status: StatusCode) -> (StatusCode, HeaderMap, Vec<u8>) {
    let mut headers = HeaderMap::new();
    headers.append("Content-Type", HeaderValue::from_static("text/plain"));
    (status, headers, src.as_bytes().to_vec())
}

fn image_response(
    mut img: RgbaImage,
    color: TextColor,
    mime: &'static str,
    format: ImageOutputFormat,
) -> (StatusCode, HeaderMap, Vec<u8>) {
    let mut png = Vec::new();
    convert(&mut img, color);
    if let Err(e) = DynamicImage::ImageRgba8(img).write_to(&mut png, format) {
        return text_response(
            &format!("failed to encode png: {:?}", e),
            StatusCode::INTERNAL_SERVER_ERROR,
        );
    }
    let mut headers = HeaderMap::new();
    headers.append("Content-Type", HeaderValue::from_static(mime));
    (StatusCode::OK, headers, png)
}

pub async fn endpoint(
    State(state): State<AppState>,
    axum::extract::Query(params): axum::extract::Query<URLQuery>,
    Path(file_name): Path<String>,
) -> impl IntoResponse {
    let query = match file_name.rsplit_once('.') {
        Some((base64, "png")) => Query::Png(base64.to_owned()),
        Some((base64, "jpg" | "jpeg")) => Query::Jpeg(base64.to_owned()),
        _ => {
            return text_response(
                "filename with unsupported extension",
                StatusCode::BAD_REQUEST,
            )
        }
    };
    let color = params
        .color
        .map(|color| TextColor::parse_from_str(&color))
        .unwrap_or_else(|| Some(TextColor::default()));
    let color = if let Some(color) = color {
        color
    } else {
        return text_response("invalid color specification", StatusCode::BAD_REQUEST);
    };
    match handle(state, query.clone()).await {
        Ok(result) => match (result, query) {
            (MathState::Ready { img }, Query::Png(_)) => {
                image_response(img, color, "image/png", ImageOutputFormat::Png)
            }
            (MathState::Ready { img }, Query::Jpeg(_)) => {
                image_response(img, color, "image/jpeg", ImageOutputFormat::Jpeg(200))
            }
            (MathState::Error(errmsg), _) => text_response(&errmsg, StatusCode::BAD_REQUEST),
        },
        Err(e) => match e.as_ref() {
            Error::BadRequest(e) => {
                info!("bad request: {:?}", e);
                text_response(&format!("Error: {:?}", e), StatusCode::BAD_REQUEST)
            }
            Error::Internal(e) => {
                warn!("internal error: {:?}", e);
                text_response(
                    &format!("Error: {:?}", e),
                    StatusCode::INTERNAL_SERVER_ERROR,
                )
            }
        },
    }
}
