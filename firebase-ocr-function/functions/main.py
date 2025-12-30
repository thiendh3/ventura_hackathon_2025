"""
Firebase Functions - Smart OCR RAG
Sử dụng Google Vision OCR + OpenAI + Semantic Search để trích xuất thành phần sản phẩm
"""
import os
import json
import base64
import logging
from io import BytesIO

from firebase_functions import https_fn, options
from firebase_admin import initialize_app

# --- KHỞI TẠO FIREBASE ---
initialize_app()

# --- LAZY LOADING CHO CÁC THƯ VIỆN NẶNG ---
# Sử dụng lazy loading để tối ưu cold start
_embedder = None
_vision_client = None
_openai_client = None

def get_embedder():
    """Lazy load SentenceTransformer model"""
    global _embedder
    if _embedder is None:
        from sentence_transformers import SentenceTransformer
        logging.info("⏳ Đang tải model Semantic...")
        _embedder = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')
        logging.info("✅ Đã tải model xong!")
    return _embedder

def get_vision_client():
    """Lazy load Google Vision client"""
    global _vision_client
    if _vision_client is None:
        from google.cloud import vision
        _vision_client = vision.ImageAnnotatorClient()
    return _vision_client

def get_openai_client():
    """Lazy load OpenAI client"""
    global _openai_client
    if _openai_client is None:
        from openai import OpenAI
        # Lấy API key từ environment variable
        api_key = os.environ.get('OPENAI_API_KEY')
        if not api_key:
            raise ValueError("OPENAI_API_KEY chưa được cấu hình!")
        _openai_client = OpenAI(api_key=api_key)
    return _openai_client


# ---------------------------------------------------------
# BƯỚC 1: GOOGLE VISION OCR (Lấy dữ liệu thô)
# ---------------------------------------------------------
def get_ocr_data(image_content: bytes) -> list:
    """
    Sử dụng Google Vision để OCR ảnh
    Args:
        image_content: bytes của ảnh
    Returns:
        List các từ với vị trí bounding box
    """
    from google.cloud import vision
    
    client = get_vision_client()
    image = vision.Image(content=image_content)
    
    response = client.document_text_detection(image=image)
    
    if not response.text_annotations:
        return []

    word_list = []
    ignore_chars = [",", ".", ":", ";", "|", "(", ")", "[", "]", "{", "}", "-", "*", "%"]
    
    for page in response.full_text_annotation.pages:
        for block in page.blocks:
            for paragraph in block.paragraphs:
                for word in paragraph.words:
                    word_text = ''.join([symbol.text for symbol in word.symbols])
                    box = [(v.x, v.y) for v in word.bounding_box.vertices]
                    is_noise = word_text in ignore_chars
                    
                    word_list.append({
                        "text": word_text, 
                        "box": box,
                        "is_noise": is_noise
                    })
    
    return word_list


# ---------------------------------------------------------
# BƯỚC 2: OPENAI ANALYSIS (Strict Prompt)
# ---------------------------------------------------------
def analyze_with_openai_strict(ocr_word_list: list) -> list:
    """
    Sử dụng OpenAI để phân tích và trích xuất nguyên liệu
    """
    full_text = " ".join([w['text'] for w in ocr_word_list])
    
    client = get_openai_client()
    
    prompt = f"""
    Bạn là một hệ thống trích xuất dữ liệu OCR chính xác (OCR Post-processor).
    
    INPUT: Một đoạn văn bản thô từ bao bì sản phẩm.
    TASK: Trích xuất danh sách các "Thành phần nguyên liệu" (Ingredients).
    
    YÊU CẦU CỰC KỲ QUAN TRỌNG (STRICT RULES):
    1. Tách riêng từng nguyên liệu. Dấu phẩy (,) là dấu hiệu ngắt quan trọng nhất.
    2. LOẠI BỎ hoàn toàn các con số phần trăm và định lượng (Ví dụ: "Bơ (1,9%)" -> Chỉ lấy "Bơ").
    3. LOẠI BỎ các mã phụ gia trong ngoặc nếu có thể tách rời.
    4. GIỮ NGUYÊN chính tả của văn bản gốc (kể cả lỗi sai).
    5. Output trả về JSON format: {{ "ingredients": ["item1", "item2", ...] }}
    
    Văn bản Input:
    '''
    {full_text}
    '''
    """

    try:
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0
        )
        data = json.loads(response.choices[0].message.content)
        return data.get("ingredients", [])
    except Exception as e:
        logging.error(f"Lỗi OpenAI: {e}")
        return []


# ---------------------------------------------------------
# BƯỚC 3: SEMANTIC MAPPING RAG (Core Logic)
# ---------------------------------------------------------
def find_coordinates_semantic(target_phrases: list, ocr_word_list: list, threshold: float = 0.55) -> list:
    """
    Sử dụng Vector Search để tìm vị trí của từng nguyên liệu trong ảnh
    """
    from sentence_transformers import util
    import torch
    
    embedder = get_embedder()
    results = []

    # Tạo Corpus từ OCR data
    corpus_texts = []
    corpus_indices = []
    
    clean_indices = [i for i, w in enumerate(ocr_word_list) if not w['is_noise']]
    max_window_size = 5
    
    for window in range(1, max_window_size + 1):
        for i in range(len(clean_indices) - window + 1):
            current_indices = clean_indices[i : i + window]
            text_segment = " ".join([ocr_word_list[idx]['text'] for idx in current_indices])
            corpus_texts.append(text_segment)
            corpus_indices.append(current_indices)

    if not corpus_texts:
        return []

    # Encode corpus
    corpus_embeddings = embedder.encode(corpus_texts, convert_to_tensor=True)

    # Tìm từng nguyên liệu
    for phrase in target_phrases:
        query_embedding = embedder.encode(phrase, convert_to_tensor=True)
        cos_scores = util.cos_sim(query_embedding, corpus_embeddings)[0]
        
        best_score_idx = torch.argmax(cos_scores).item()
        best_score = cos_scores[best_score_idx].item()

        if best_score >= threshold:
            matched_text = corpus_texts[best_score_idx]
            matched_raw_indices = corpus_indices[best_score_idx]
            
            # Lấy bounding box
            matched_boxes = [ocr_word_list[idx]['box'] for idx in matched_raw_indices]
            
            all_x = [pt[0] for box in matched_boxes for pt in box]
            all_y = [pt[1] for box in matched_boxes for pt in box]
            
            final_box = [
                [min(all_x), min(all_y)], 
                [max(all_x), min(all_y)], 
                [max(all_x), max(all_y)], 
                [min(all_x), max(all_y)]
            ]
            
            results.append({
                "label": phrase,
                "matched_text": matched_text,
                "confidence": round(best_score, 3),
                "bounding_box": final_box
            })

    return results


# ---------------------------------------------------------
# FIREBASE FUNCTION ENDPOINT
# ---------------------------------------------------------
@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],  # Cho phép tất cả origins, có thể restrict lại
        cors_methods=["GET", "POST"]
    ),
    memory=options.MemoryOption.GB_2,  # 2GB RAM cho model ML
    timeout_sec=300,  # 5 phút timeout
    region="asia-southeast1"  # Region Singapore
)
def smart_ocr_rag(req: https_fn.Request) -> https_fn.Response:
    """
    Firebase HTTP Function để xử lý OCR + RAG
    
    Request Body (JSON):
    {
        "image_base64": "base64_encoded_image_string",
        "threshold": 0.6  (optional, default 0.6)
    }
    
    Hoặc gửi ảnh trực tiếp qua multipart/form-data với field name là "image"
    """
    
    # Chỉ chấp nhận POST
    if req.method != 'POST':
        return https_fn.Response(
            json.dumps({"error": "Method not allowed. Use POST."}),
            status=405,
            headers={"Content-Type": "application/json"}
        )
    
    try:
        image_content = None
        threshold = 0.6
        
        # Xử lý multipart/form-data (upload file trực tiếp)
        if req.files and 'image' in req.files:
            file = req.files['image']
            image_content = file.read()
            threshold = float(req.form.get('threshold', 0.6))
        
        # Xử lý JSON body (base64 image)
        elif req.is_json:
            data = req.get_json()
            
            if 'image_base64' not in data:
                return https_fn.Response(
                    json.dumps({"error": "Missing 'image_base64' field"}),
                    status=400,
                    headers={"Content-Type": "application/json"}
                )
            
            # Decode base64
            image_base64 = data['image_base64']
            # Xóa prefix nếu có (data:image/png;base64,...)
            if ',' in image_base64:
                image_base64 = image_base64.split(',')[1]
            
            image_content = base64.b64decode(image_base64)
            threshold = float(data.get('threshold', 0.6))
        
        else:
            return https_fn.Response(
                json.dumps({"error": "Invalid request format. Use JSON or multipart/form-data"}),
                status=400,
                headers={"Content-Type": "application/json"}
            )
        
        # ===== XỬ LÝ CHÍNH =====
        
        # 1. OCR
        logging.info("🔍 Bắt đầu OCR...")
        ocr_data = get_ocr_data(image_content)
        
        if not ocr_data:
            return https_fn.Response(
                json.dumps({
                    "success": False,
                    "error": "Không tìm thấy text trong ảnh"
                }),
                status=200,
                headers={"Content-Type": "application/json"}
            )
        
        # 2. Phân tích với OpenAI
        logging.info("🤖 Đang phân tích với AI...")
        ingredients = analyze_with_openai_strict(ocr_data)
        
        if not ingredients:
            # Trả về raw OCR nếu không phân tích được
            raw_text = " ".join([w['text'] for w in ocr_data if not w['is_noise']])
            return https_fn.Response(
                json.dumps({
                    "success": True,
                    "ingredients": [],
                    "mappings": [],
                    "raw_text": raw_text,
                    "message": "Không tìm thấy nguyên liệu. Trả về raw OCR text."
                }),
                status=200,
                headers={"Content-Type": "application/json"}
            )
        
        # 3. Semantic Mapping
        logging.info("🔗 Đang mapping vị trí...")
        mappings = find_coordinates_semantic(ingredients, ocr_data, threshold)
        
        # 4. Tạo response
        response_data = {
            "success": True,
            "ingredients": ingredients,
            "mappings": mappings,
            "total_ocr_words": len(ocr_data),
            "matched_count": len(mappings),
            "threshold_used": threshold
        }
        
        logging.info(f"✅ Hoàn thành! Tìm thấy {len(ingredients)} nguyên liệu, mapped {len(mappings)}")
        
        return https_fn.Response(
            json.dumps(response_data, ensure_ascii=False),
            status=200,
            headers={"Content-Type": "application/json; charset=utf-8"}
        )
        
    except Exception as e:
        logging.error(f"❌ Error: {str(e)}")
        return https_fn.Response(
            json.dumps({"success": False, "error": str(e)}),
            status=500,
            headers={"Content-Type": "application/json"}
        )


# ---------------------------------------------------------
# HEALTH CHECK ENDPOINT
# ---------------------------------------------------------
@https_fn.on_request(
    cors=options.CorsOptions(cors_origins=["*"], cors_methods=["GET"]),
    region="asia-southeast1"
)
def health_check(req: https_fn.Request) -> https_fn.Response:
    """Simple health check endpoint"""
    return https_fn.Response(
        json.dumps({
            "status": "healthy",
            "service": "smart-ocr-rag",
            "version": "1.0.0"
        }),
        status=200,
        headers={"Content-Type": "application/json"}
    )

