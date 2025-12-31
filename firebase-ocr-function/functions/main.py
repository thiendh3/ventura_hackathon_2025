"""
Firebase Functions - Smart OCR RAG
Sử dụng Google Vision OCR + OpenAI + Semantic Search để trích xuất thành phần sản phẩm
"""
import os
import json
import base64
import logging
import uuid
from io import BytesIO
from datetime import datetime

from firebase_functions import https_fn, options
from firebase_admin import initialize_app, db, storage

# --- KHỞI TẠO FIREBASE ---
# Cấu hình cho Realtime Database và Storage
firebase_app = initialize_app(options={
    'databaseURL': 'https://hackathon-2026-482104-default-rtdb.firebaseio.com/',
    'storageBucket': 'hackathon-2026-482104.firebasestorage.app'
})

# --- LAZY LOADING CHO CÁC THƯ VIỆN NẶNG ---
# Sử dụng lazy loading để tối ưu cold start
_vision_client = None
_openai_client = None

def get_openai_embeddings(texts: list[str]) -> list[list[float]]:
    """
    Get embeddings from OpenAI API instead of local model
    Args:
        texts: List of text strings to embed
    Returns:
        List of embedding vectors
    """
    client = get_openai_client()
    
    try:
        response = client.embeddings.create(
            model="text-embedding-3-small",
            input=texts
        )
        return [item.embedding for item in response.data]
    except Exception as e:
        logging.error(f"Error getting OpenAI embeddings: {e}")
        raise

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
# BƯỚC 2.5: PHÂN TÍCH RỦI RO SỨC KHỎE (Health Risk Analysis)
# ---------------------------------------------------------
def analyze_health_risks(ingredients: list, health_profile: dict) -> dict:
    """
    Sử dụng OpenAI để phân tích rủi ro sức khỏe dựa trên ingredients và health profile
    
    Args:
        ingredients: Danh sách nguyên liệu đã trích xuất
        health_profile: Hồ sơ sức khỏe của người dùng
            {
                "medical_history": ["bệnh 1", "bệnh 2"],
                "allergy": ["dị ứng 1", "dị ứng 2"]
            }
    
    Returns:
        Dictionary chứa warnings, safe_ingredients, overall_recommendation
    """
    client = get_openai_client()
    
    # Format health profile for prompt
    medical_history = health_profile.get('medical_history', [])
    allergies = health_profile.get('allergy', [])
    
    medical_history_str = ", ".join(medical_history) if medical_history else "Không có"
    allergies_str = ", ".join(allergies) if allergies else "Không có"
    ingredients_str = ", ".join(ingredients)
    
    prompt = f"""
Bạn là một BÁC SĨ DINH DƯỠNG và CHUYÊN GIA DỊ ỨNG THỰC PHẨM với kiến thức y khoa sâu rộng.

## NHIỆM VỤ
Phân tích danh sách THÀNH PHẦN thực phẩm và xác định thành phần nào có thể GÂY HẠI cho người dùng dựa trên HỒ SƠ SỨC KHỎE của họ.

## HỒ SƠ SỨC KHỎE
- Tiền sử bệnh lý: {medical_history_str}
- Dị ứng đã biết: {allergies_str}

## DANH SÁCH THÀNH PHẦN CẦN PHÂN TÍCH
{ingredients_str}

## YÊU CẦU PHÂN TÍCH (QUAN TRỌNG)

1. **Nhận diện trực tiếp**: Thành phần CÓ TRONG danh sách dị ứng
   - Ví dụ: "hải sản" bao gồm: tôm, cua, mực, sò, ốc, cá...
   - Ví dụ: "các loại đậu" bao gồm: đậu phộng, đậu nành, đậu xanh, đậu đỏ...
   - Ví dụ: "gluten" bao gồm: bột mì, lúa mạch, yến mạch...

2. **Nhận diện gián tiếp (Cross-reactivity)**: Thành phần có thể GÂY PHẢN ỨNG CHÉO
   - Ví dụ: Dị ứng latex → có thể phản ứng với chuối, bơ, kiwi
   - Ví dụ: Dị ứng đậu phộng → có thể phản ứng với đậu tương, đậu xanh
   - Ví dụ: Dị ứng sữa bò → có thể phản ứng với sữa dê, sữa cừu

3. **Ảnh hưởng tiền sử bệnh**: Thành phần KHÔNG TỐT cho tình trạng bệnh lý
   - Gan nhiễm mỡ → hạn chế đường, chất béo bão hòa, rượu, fructose
   - Tiểu đường → hạn chế đường, tinh bột tinh chế, carbohydrate đơn giản
   - Cao huyết áp → hạn chế muối (sodium), MSG, thực phẩm chế biến sẵn
   - Viêm họng → hạn chế đồ cay, đồ lạnh, đồ chiên rán, thực phẩm có tính axit
   - Gout → hạn chế purine (thịt đỏ, nội tạng, hải sản)
   - Bệnh thận → hạn chế protein, potassium, phosphorus

## OUTPUT FORMAT (JSON)
{{
  "warnings": [
    {{
      "ingredient": "Tên thành phần gốc từ danh sách",
      "risk_score": 0.95,
      "warning_type": "allergy/cross_reactivity/medical_condition",
      "summary": "Tóm tắt ngắn gọn lý do cảnh báo",
      "scientific_explanation": "Giải thích CHI TIẾT về mặt y khoa/sinh học: tên khoa học của thành phần, cơ chế sinh học tại sao gây hại, các protein/hợp chất cụ thể liên quan, quá trình phản ứng trong cơ thể",
      "potential_effects": ["Tác động 1", "Tác động 2", "Tác động 3"],
      "recommendation": "Lời khuyên cụ thể và thực tế cho bệnh nhân"
    }}
  ],
  "safe_ingredients": ["Danh sách các thành phần AN TOÀN không có vấn đề"],
  "overall_recommendation": "Đánh giá tổng thể: sản phẩm này có AN TOÀN hay KHÔNG AN TOÀN cho bệnh nhân, kèm lời khuyên cuối cùng"
}}

## QUY TẮC BẮT BUỘC
- Chỉ trả về JSON thuần túy, không có text giải thích bên ngoài
- TOÀN BỘ nội dung PHẢI viết bằng TIẾNG VIỆT CÓ DẤU đầy đủ
- risk_score: Điểm số đánh giá mức độ nguy hiểm trong khoảng [0, 1], trong đó:
  * 0.8 - 1.0 = Cực kỳ nguy hiểm (dị ứng trực tiếp, có thể gây sốc phản vệ)
  * 0.6 - 0.79 = Nguy hiểm cao (phản ứng chéo mạnh, ảnh hưởng nghiêm trọng đến bệnh lý)
  * 0.4 - 0.59 = Nguy hiểm trung bình (ảnh hưởng tiền sử bệnh, cần hạn chế)
  * 0.2 - 0.39 = Nguy hiểm thấp (cần thận trọng, theo dõi)
  * 0.0 - 0.19 = Rất thấp (ảnh hưởng nhẹ, có thể sử dụng với lượng nhỏ)
- Giải thích khoa học phải chuyên sâu nhưng vẫn dễ hiểu cho người không có chuyên môn y khoa
- Nếu KHÔNG có thành phần nào có vấn đề, trả về warnings = [] và overall_recommendation tích cực
- Chỉ cảnh báo những thành phần THỰC SỰ có trong danh sách, không tự thêm thành phần mới
"""

    try:
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0
        )
        data = json.loads(response.choices[0].message.content)
        return {
            "warnings": data.get("warnings", []),
            "safe_ingredients": data.get("safe_ingredients", []),
            "overall_recommendation": data.get("overall_recommendation", "")
        }
    except Exception as e:
        logging.error(f"Lỗi phân tích health risks: {e}")
        return {
            "warnings": [],
            "safe_ingredients": ingredients,
            "overall_recommendation": f"Không thể phân tích rủi ro sức khỏe: {str(e)}"
        }


# ---------------------------------------------------------
# BƯỚC 3: SEMANTIC MAPPING RAG (Core Logic)
# ---------------------------------------------------------
def find_coordinates_semantic(target_phrases: list, ocr_word_list: list, threshold: float = 0.55) -> list:
    """
    Sử dụng OpenAI Embeddings API để tìm vị trí của từng nguyên liệu trong ảnh
    """
    import numpy as np
    from numpy.linalg import norm
    
    results = []
    
    # Tạo Corpus từ OCR data
    corpus_texts = []
    corpus_indices = []
    
    clean_indices = [i for i, w in enumerate(ocr_word_list) if not w['is_noise']]
    max_window_size = 3  # Reduced from 5 for better performance
    
    for window in range(1, max_window_size + 1):
        for i in range(len(clean_indices) - window + 1):
            current_indices = clean_indices[i : i + window]
            text_segment = " ".join([ocr_word_list[idx]['text'] for idx in current_indices])
            corpus_texts.append(text_segment)
            corpus_indices.append(current_indices)
    
    if not corpus_texts:
        return []
    
    # Batch encode corpus và queries với OpenAI
    all_texts = corpus_texts + target_phrases
    all_embeddings = get_openai_embeddings(all_texts)
    
    corpus_embeddings = np.array(all_embeddings[:len(corpus_texts)])
    query_embeddings = np.array(all_embeddings[len(corpus_texts):])
    
    # Batch cosine similarity calculation
    # Normalize embeddings
    corpus_norms = norm(corpus_embeddings, axis=1, keepdims=True)
    query_norms = norm(query_embeddings, axis=1, keepdims=True)
    
    normalized_corpus = corpus_embeddings / (corpus_norms + 1e-8)
    normalized_queries = query_embeddings / (query_norms + 1e-8)
    
    # Compute all similarities at once
    all_similarities = np.dot(normalized_queries, normalized_corpus.T)
    
    # Process each query
    for i, phrase in enumerate(target_phrases):
        similarities = all_similarities[i]
        best_idx = np.argmax(similarities)
        best_score = float(similarities[best_idx])
        
        if best_score >= threshold:
            matched_text = corpus_texts[best_idx]
            matched_raw_indices = corpus_indices[best_idx]
            
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
    memory=options.MemoryOption.GB_1,  # Reduced from GB_2 since no local model
    timeout_sec=300,  # 5 phút timeout
    region="asia-southeast1",  # Region Singapore
    min_instances=1  # Keep 1 instance warm to eliminate cold start
)
def smart_ocr_rag(req: https_fn.Request) -> https_fn.Response:
    """
    Firebase HTTP Function để xử lý OCR + RAG + Health Analysis
    
    Request Body (JSON):
    {
        "image_base64": "base64_encoded_image_string",
        "threshold": 0.6  (optional, default 0.6),
        "health_profile": {
            "medical_history": ["bệnh 1", "bệnh 2"],
            "allergy": ["dị ứng 1", "dị ứng 2"]
        }
    }
    
    Hoặc gửi qua multipart/form-data:
    - image: file ảnh
    - health_profile: JSON string của health profile
    - threshold: optional
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
        health_profile = None
        
        # Xử lý multipart/form-data (upload file trực tiếp)
        if req.files and 'image' in req.files:
            file = req.files['image']
            image_content = file.read()
            threshold = float(req.form.get('threshold', 0.6))
            
            # Parse health_profile từ form data
            health_profile_str = req.form.get('health_profile')
            if health_profile_str:
                try:
                    health_profile = json.loads(health_profile_str)
                except json.JSONDecodeError:
                    return https_fn.Response(
                        json.dumps({"error": "Invalid health_profile JSON format"}),
                        status=400,
                        headers={"Content-Type": "application/json"}
                    )
        
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
            health_profile = data.get('health_profile')
        
        else:
            return https_fn.Response(
                json.dumps({"error": "Invalid request format. Use JSON or multipart/form-data"}),
                status=400,
                headers={"Content-Type": "application/json"}
            )
        
        # Validate health_profile (bắt buộc)
        if not health_profile:
            return https_fn.Response(
                json.dumps({
                    "error": "Missing 'health_profile' field",
                    "required_format": {
                        "medical_history": ["bệnh 1", "bệnh 2"],
                        "allergy": ["dị ứng 1", "dị ứng 2"]
                    }
                }),
                status=400,
                headers={"Content-Type": "application/json"}
            )
        
        # Validate health_profile structure
        if not isinstance(health_profile.get('medical_history'), list):
            health_profile['medical_history'] = []
        if not isinstance(health_profile.get('allergy'), list):
            health_profile['allergy'] = []
        
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
        
        # 2. Phân tích với OpenAI để trích xuất nguyên liệu
        logging.info("🤖 Đang phân tích với AI...")
        ingredients = analyze_with_openai_strict(ocr_data)
        
        if not ingredients:
            # Trả về raw OCR nếu không phân tích được
            raw_text = " ".join([w['text'] for w in ocr_data if not w['is_noise']])
            return https_fn.Response(
                json.dumps({
                    "success": True,
                    "ingredients": [],
                    "health_warnings": [],
                    "safe_ingredients": [],
                    "risk_summary": {
                        "max_risk_score": 0,
                        "avg_risk_score": 0,
                        "critical_risk_count": 0,
                        "high_risk_count": 0,
                        "medium_risk_count": 0,
                        "low_risk_count": 0,
                        "very_low_risk_count": 0,
                        "total_warnings": 0,
                        "overall_recommendation": "Không tìm thấy nguyên liệu để phân tích."
                    },
                    "mappings": [],
                    "raw_text": raw_text,
                    "message": "Không tìm thấy nguyên liệu. Trả về raw OCR text.",
                    "user_profile": health_profile
                }, ensure_ascii=False),
                status=200,
                headers={"Content-Type": "application/json; charset=utf-8"}
            )
        
        # 3. Phân tích rủi ro sức khỏe
        logging.info("🏥 Đang phân tích rủi ro sức khỏe...")
        health_analysis = analyze_health_risks(ingredients, health_profile)
        
        # 4. Semantic Mapping
        logging.info("🔗 Đang mapping vị trí...")
        mappings = find_coordinates_semantic(ingredients, ocr_data, threshold)
        
        # 5. Tính toán risk summary dựa trên risk_score
        warnings = health_analysis.get("warnings", [])
        
        # Phân loại theo risk_score
        critical_risk_count = len([w for w in warnings if w.get("risk_score", 0) >= 0.8])  # 0.8-1.0
        high_risk_count = len([w for w in warnings if 0.6 <= w.get("risk_score", 0) < 0.8])  # 0.6-0.79
        medium_risk_count = len([w for w in warnings if 0.4 <= w.get("risk_score", 0) < 0.6])  # 0.4-0.59
        low_risk_count = len([w for w in warnings if 0.2 <= w.get("risk_score", 0) < 0.4])  # 0.2-0.39
        very_low_risk_count = len([w for w in warnings if w.get("risk_score", 0) < 0.2])  # 0-0.19
        
        # Tính max và avg risk score
        risk_scores = [w.get("risk_score", 0) for w in warnings]
        max_risk_score = max(risk_scores) if risk_scores else 0
        avg_risk_score = sum(risk_scores) / len(risk_scores) if risk_scores else 0
        
        # 6. Tạo response
        response_data = {
            "success": True,
            "ingredients": ingredients,
            "health_warnings": warnings,
            "safe_ingredients": health_analysis.get("safe_ingredients", []),
            "risk_summary": {
                "max_risk_score": round(max_risk_score, 2),
                "avg_risk_score": round(avg_risk_score, 2),
                "critical_risk_count": critical_risk_count,
                "high_risk_count": high_risk_count,
                "medium_risk_count": medium_risk_count,
                "low_risk_count": low_risk_count,
                "very_low_risk_count": very_low_risk_count,
                "total_warnings": len(warnings),
                "overall_recommendation": health_analysis.get("overall_recommendation", "")
            },
            "mappings": mappings,
            "total_ocr_words": len(ocr_data),
            "matched_count": len(mappings),
            "threshold_used": threshold,
            "user_profile": {
                "allergies_checked": health_profile.get("allergy", []),
                "conditions_checked": health_profile.get("medical_history", [])
            }
        }
        
        logging.info(f"✅ Hoàn thành! Tìm thấy {len(ingredients)} nguyên liệu, {len(warnings)} cảnh báo")
        
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


# ---------------------------------------------------------
# SAVE HISTORY ENDPOINT
# ---------------------------------------------------------
@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST"]
    ),
    memory=options.MemoryOption.MB_512,
    timeout_sec=60,
    region="asia-southeast1"
)
def save_history(req: https_fn.Request) -> https_fn.Response:
    """
    Lưu lịch sử scan vào Realtime Database + Upload ảnh lên Storage
    
    Hỗ trợ 2 cách gửi request:
    
    1. JSON Body:
    {
        "device_id": "unique_device_identifier",
        "image_base64": "base64_encoded_image",
        "scan_result": {...}
    }
    
    2. Multipart Form-Data:
    - device_id: string
    - image: file (ảnh)
    - scan_result: JSON string
    """
    
    if req.method != 'POST':
        return https_fn.Response(
            json.dumps({"error": "Method not allowed. Use POST."}),
            status=405,
            headers={"Content-Type": "application/json"}
        )
    
    try:
        device_id = None
        image_content = None
        scan_result = None
        
        # === CÁCH 1: Multipart Form-Data (upload file trực tiếp) ===
        if req.files and 'image' in req.files:
            file = req.files['image']
            image_content = file.read()
            
            device_id = req.form.get('device_id')
            
            # Parse scan_result từ form data (JSON string)
            scan_result_str = req.form.get('scan_result')
            if scan_result_str:
                try:
                    scan_result = json.loads(scan_result_str)
                except json.JSONDecodeError:
                    return https_fn.Response(
                        json.dumps({"error": "Invalid scan_result JSON format"}),
                        status=400,
                        headers={"Content-Type": "application/json"}
                    )
        
        # === CÁCH 2: JSON Body (base64 image) ===
        elif req.is_json:
            data = req.get_json()
            
            device_id = data.get('device_id')
            scan_result = data.get('scan_result')
            
            # Decode base64 image nếu có
            image_base64 = data.get('image_base64')
            if image_base64:
                # Xóa prefix nếu có (data:image/png;base64,...)
                if ',' in image_base64:
                    image_base64 = image_base64.split(',')[1]
                image_content = base64.b64decode(image_base64)
        
        else:
            return https_fn.Response(
                json.dumps({"error": "Invalid request format. Use JSON or multipart/form-data"}),
                status=400,
                headers={"Content-Type": "application/json"}
            )
        
        # Validate required fields
        if not device_id:
            return https_fn.Response(
                json.dumps({"error": "Missing 'device_id' field"}),
                status=400,
                headers={"Content-Type": "application/json"}
            )
        
        if not scan_result:
            return https_fn.Response(
                json.dumps({"error": "Missing 'scan_result' field"}),
                status=400,
                headers={"Content-Type": "application/json"}
            )
        
        # Generate unique filename và timestamp
        timestamp = int(datetime.now().timestamp() * 1000)
        unique_id = str(uuid.uuid4())[:8]
        
        image_url = None
        
        # Upload image to Storage nếu có
        if image_content:
            try:
                # Upload to Firebase Storage
                bucket = storage.bucket()
                blob_path = f"scan_images/{device_id}/{timestamp}_{unique_id}.jpg"
                blob = bucket.blob(blob_path)
                
                blob.upload_from_string(
                    image_content,
                    content_type='image/jpeg'
                )
                
                # Make the blob publicly accessible
                blob.make_public()
                image_url = blob.public_url
                
                logging.info(f"✅ Uploaded image to: {image_url}")
                
            except Exception as e:
                logging.error(f"❌ Error uploading image: {e}")
                # Continue without image URL
                image_url = None
        
        # Prepare data for Realtime Database
        history_data = {
            "created_at": timestamp,
            "image_url": image_url,
            
            # Ingredients data
            "ingredients": scan_result.get("ingredients", []),
            "safe_ingredients": scan_result.get("safe_ingredients", []),
            
            # Health warnings (full object)
            "health_warnings": scan_result.get("health_warnings", []),
            
            # Risk summary (full object)
            "risk_summary": scan_result.get("risk_summary", {}),
            
            # Mappings (bounding boxes)
            "mappings": scan_result.get("mappings", []),
            
            # OCR metadata
            "total_ocr_words": scan_result.get("total_ocr_words", 0),
            "matched_count": scan_result.get("matched_count", 0),
            "threshold_used": scan_result.get("threshold_used", 0.6),
            
            # User profile
            "user_profile": scan_result.get("user_profile", {})
        }
        
        # Save to Realtime Database
        ref = db.reference(f'scan_history/{device_id}')
        new_ref = ref.push(history_data)
        history_id = new_ref.key
        
        logging.info(f"✅ Saved history: {history_id} for device: {device_id}")
        
        return https_fn.Response(
            json.dumps({
                "success": True,
                "history_id": history_id,
                "image_url": image_url,
                "created_at": timestamp
            }, ensure_ascii=False),
            status=200,
            headers={"Content-Type": "application/json; charset=utf-8"}
        )
        
    except Exception as e:
        logging.error(f"❌ Error saving history: {str(e)}")
        return https_fn.Response(
            json.dumps({"success": False, "error": str(e)}),
            status=500,
            headers={"Content-Type": "application/json"}
        )


# ---------------------------------------------------------
# GET HISTORY ENDPOINT
# ---------------------------------------------------------
@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET"]
    ),
    memory=options.MemoryOption.MB_256,
    timeout_sec=30,
    region="asia-southeast1"
)
def get_history(req: https_fn.Request) -> https_fn.Response:
    """
    Lấy lịch sử scan từ Realtime Database
    
    Query Parameters:
    - device_id: (required) Device identifier
    - limit: (optional) Max items to return, default 20, max 100
    """
    
    if req.method != 'GET':
        return https_fn.Response(
            json.dumps({"error": "Method not allowed. Use GET."}),
            status=405,
            headers={"Content-Type": "application/json"}
        )
    
    try:
        # Get query parameters
        device_id = req.args.get('device_id')
        limit = min(int(req.args.get('limit', 20)), 100)  # Max 100 items
        
        if not device_id:
            return https_fn.Response(
                json.dumps({"error": "Missing 'device_id' query parameter"}),
                status=400,
                headers={"Content-Type": "application/json"}
            )
        
        # Query Realtime Database
        ref = db.reference(f'scan_history/{device_id}')
        
        # Get data ordered by created_at (descending - newest first)
        # Realtime DB orders ascending by default, so we get all and reverse
        snapshot = ref.order_by_child('created_at').limit_to_last(limit).get()
        
        if not snapshot:
            return https_fn.Response(
                json.dumps({
                    "success": True,
                    "history": [],
                    "count": 0
                }, ensure_ascii=False),
                status=200,
                headers={"Content-Type": "application/json; charset=utf-8"}
            )
        
        # Convert to list and add ID
        history_list = []
        for history_id, history_data in snapshot.items():
            history_item = {
                "id": history_id,
                **history_data
            }
            history_list.append(history_item)
        
        # Sort by created_at descending (newest first)
        history_list.sort(key=lambda x: x.get('created_at', 0), reverse=True)
        
        logging.info(f"✅ Retrieved {len(history_list)} history items for device: {device_id}")
        
        return https_fn.Response(
            json.dumps({
                "success": True,
                "history": history_list,
                "count": len(history_list)
            }, ensure_ascii=False),
            status=200,
            headers={"Content-Type": "application/json; charset=utf-8"}
        )
        
    except Exception as e:
        logging.error(f"❌ Error getting history: {str(e)}")
        return https_fn.Response(
            json.dumps({"success": False, "error": str(e)}),
            status=500,
            headers={"Content-Type": "application/json"}
        )
