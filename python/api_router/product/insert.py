# python/APIRouter/product/insert.py
# 제품 등록 API → POST /product/
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# product 테이블 형식에 맞춘 요청 바디 (pr_image는 별도 처리)
# BaseModel: 값이 빠졌거나 타입이 틀리면 함수 실행 전에 422 에러를 자동으로 돌려줌
class Product(BaseModel):
    SKU: str            # 사이즈별 고유 코드 (PK) 예: AD-JEN-W-220-BLK
    pr_code: str        # 모델 코드 예: AD-JEN-W
    pr_name: str        # 제품명
    pr_brand: str       # 브랜드명
    pr_price: int       # 제품가격
    category: str       # 데일리 / 클래식 / 아웃도어
    gender: str         # 성별 (남성 / 여성 / 키즈 등)
    size: int           # 사이즈
    color: str          # 색상


@router.post("/")
def insert_product(product: Product):
    conn = connect()  # DB 연결
    try:
        with conn.cursor() as curs:
            # %s 자리에 값이 순서대로 들어감 (SQL 인젝션 방지)
            sql = """
                INSERT INTO product
                    (SKU, pr_code, pr_name, pr_brand, pr_price,
                    category, gender, size, color)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            curs.execute(sql, (
                product.SKU,
                product.pr_code,
                product.pr_name,
                product.pr_brand,
                product.pr_price,
                product.category,
                product.gender,
                product.size,
                product.color,
            ))
        conn.commit()  # 실제 DB에 저장 확정
        # SKU는 자동 생성이 아니라 직접 넣은 값이라 그대로 돌려줌
        return {"result": "OK", "SKU": product.SKU}
    except Exception as e:
        conn.rollback()  # 에러 시 저장하지 않고 되돌림 (예: 이미 있는 SKU)
        raise HTTPException(status_code=500, detail=f"제품 등록 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
