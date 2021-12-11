use axum::extract::Extension;
use axum::http::{HeaderMap, HeaderValue, StatusCode};
use axum::response::IntoResponse;
use image::io::Reader as ImageReader;
use image::DynamicImage;
use std::sync::Arc;
use tokio::io::AsyncReadExt;
use tokio::sync::RwLock;
use tokio::{fs, io};
use tracing::{debug, warn};

pub struct State {
    image: RwLock<Option<DynamicImage>>,
}

impl Default for State {
    fn default() -> Self {
        Self {
            image: RwLock::new(None),
        }
    }
}

#[derive(Debug)]
enum Error {
    Read(io::Error),
    Decode(image::error::ImageError),
    Encode(image::error::ImageError),
}

async fn handle(state: Arc<State>) -> Result<Vec<u8>, Error> {
    let image_readable = { state.image.read().await.is_some() };
    if !image_readable {
        let file = fs::File::open("./test.png").await.map_err(Error::Read)?;
        let mut buf = Vec::new();
        let mut reader = io::BufReader::new(file);
        reader.read_to_end(&mut buf).await.map_err(Error::Read)?;
        let img = ImageReader::new(std::io::Cursor::new(buf))
            .decode()
            .map_err(Error::Decode)?;
        *state.image.write().await = Some(img);
    }
    let mut buf = Vec::new();
    state
        .image
        .read()
        .await
        .as_ref()
        .unwrap()
        .write_to(&mut buf, image::ImageFormat::Png)
        .map_err(Error::Encode)?;
    Ok(buf)
}

pub async fn endpoint(Extension(state): Extension<Arc<State>>) -> impl IntoResponse {
    match handle(state).await {
        Ok(bytes) => {
            debug!("return");
            let mut headers = HeaderMap::new();
            headers.append("Content-Type", HeaderValue::from_static("image/png"));
            (StatusCode::ACCEPTED, headers, bytes)
        }
        Err(e) => {
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
