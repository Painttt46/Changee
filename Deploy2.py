from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from PIL import Image
import io
import numpy as np
import os
import requests
import validators
from tensorflow.keras.models import load_model
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Rice Disease Prediction API", version="1.0.0")

# Add CORS middleware for mobile app compatibility
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load model
model_path = "SSRModel.keras"
if not os.path.exists(model_path):
    raise FileNotFoundError(f"Model file not found at {model_path}")

try:
    model = load_model(model_path)
    logger.info("Model loaded successfully")
except Exception as e:
    logger.error(f"Error loading model: {e}")
    raise

class ImageURL(BaseModel):
    image_url: str

class PredictionResponse(BaseModel):
    predicted_class: str
    confidence_score: str
    confidence_value: float
    top_3_predictions: list
    message: str
    status: str

def resize_and_pad(image, target_size=(256, 256)):
    """Resize and pad image to target size while maintaining aspect ratio"""
    old_size = image.size
    ratio = min(target_size[0] / old_size[0], target_size[1] / old_size[1])
    new_size = tuple([int(x * ratio) for x in old_size])
    
    try:
        resample_method = Image.Resampling.LANCZOS
    except AttributeError:
        resample_method = Image.LANCZOS

    image = image.resize(new_size, resample_method)

    # Create new image with white background instead of black
    new_img = Image.new("RGB", target_size, (255, 255, 255))
    new_img.paste(image, ((target_size[0] - new_size[0]) // 2,
                          (target_size[1] - new_size[1]) // 2))
    return new_img

def preprocess_image(image: Image.Image) -> np.ndarray:
    """Preprocess image for model prediction"""
    image = image.convert("RGB")
    image = resize_and_pad(image, (256, 256))
    image = np.array(image).astype(np.float32) / 255.0
    image = np.expand_dims(image, axis=0)
    return image

@app.get("/")
async def root():
    return {"message": "Rice Disease Prediction API", "status": "running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": model is not None}

@app.post("/predict/", response_model=dict)
async def predict(image_data: ImageURL):
    """Predict rice disease from image URL"""
    image_url = image_data.image_url
    logger.info(f"Received prediction request for URL: {image_url}")

    # Validate URL
    if not validators.url(image_url):
        logger.error(f"Invalid URL provided: {image_url}")
        raise HTTPException(status_code=400, detail="Invalid URL provided")

    try:
        # Download image
        response = requests.get(image_url, timeout=30)
        response.raise_for_status()
        image = Image.open(io.BytesIO(response.content))
        logger.info(f"Image downloaded successfully, size: {image.size}")
    except Exception as e:
        logger.error(f"Error downloading image: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Error downloading image: {str(e)}")

    try:
        # Preprocess and predict
        processed_image = preprocess_image(image)
        prediction = model.predict(processed_image)
        logger.info("Model prediction completed")
    except Exception as e:
        logger.error(f"Error during model prediction: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error during model prediction: {str(e)}")

    # Process results
    predicted_class = int(np.argmax(prediction, axis=1)[0])
    confidence_score = float(np.max(prediction)) * 100

    # Thai class names for better user experience
    class_names = {
        0: "โรคใบจุดสีน้ำตาล (Brown Spot)",
        1: "โรคใบวงสีน้ำตาล (Leaf Scald)", 
        2: "โรคไหม้ (Rice Blast)",
        3: "โรคใบสีส้ม (Rice Tungro)",
        4: "โรคกาบใบแห้ง (Sheath Blight)"
    }

    class_name = class_names.get(predicted_class, "ไม่ทราบโรค")
    threshold = 75.0  # Lowered threshold for better usability

    # Get top 3 predictions
    top_n = 3
    top_n_indices = prediction[0].argsort()[-top_n:][::-1]
    top_n_confidences = prediction[0][top_n_indices] * 100
    top_n_predictions = [
        {
            "class": class_names.get(int(index), "ไม่ทราบโรค"), 
            "confidence": f"{conf:.1f}%",
            "confidence_value": float(conf)
        }
        for index, conf in zip(top_n_indices, top_n_confidences)
    ]

    if confidence_score >= threshold:
        result = {
            "predicted_class": class_name,
            "confidence_score": f"{confidence_score:.1f}%",
            "confidence_value": confidence_score,
            "top_3_predictions": top_n_predictions,
            "message": "การวิเคราะห์สำเร็จ",
            "status": "success"
        }
        logger.info(f"Prediction successful: {class_name} with {confidence_score:.1f}% confidence")
    else:
        result = {
            "predicted_class": "ไม่สามารถระบุได้",
            "confidence_score": f"{confidence_score:.1f}%",
            "confidence_value": confidence_score,
            "top_3_predictions": top_n_predictions,
            "message": f"ความมั่นใจในการทำนายต่ำกว่า {threshold}% กรุณาถ่ายรูปใหม่ที่ชัดเจนกว่า",
            "status": "low_confidence"
        }
        logger.info(f"Low confidence prediction: {confidence_score:.1f}%")

    return result

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
